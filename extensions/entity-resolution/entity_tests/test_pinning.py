# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Pinning a governed metric's table into the NL→SQL schema context."""

from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from coa_entity.pinning import add_pinned, metric_tables, pin_tables


def _hit(table: str) -> SimpleNamespace:
    return SimpleNamespace(text=f"Table: {table} | Description: x")


def _table_of(text: str) -> str | None:
    return text.split("Table: ")[1].split(" |")[0] if text.startswith("Table: ") else None


@pytest.mark.unit
class TestMetricTables:
    @pytest.mark.parametrize(
        "sql, tables",
        [
            ("SELECT SUM(net_sales) FROM combined_profit_and_loss_income_yearly WHERE flag = 'Standalone'",
             ["combined_profit_and_loss_income_yearly"]),
            ('SELECT x FROM "db"."orders" o JOIN customers c ON o.c = c.id', ["orders", "customers"]),
            ("SELECT COUNT(*) FROM awsdatacatalog.sales.orders", ["orders"]),
        ],
    )  # fmt: skip
    def test_extracts_bare_names(self, sql, tables):
        assert metric_tables(sql) == tables


@pytest.mark.unit
class TestAddPinned:
    def _pin(self, hits, found, tables=("combined_profit_and_loss_income_yearly",)):
        clients = MagicMock()  # Clients: embed / search, plain calls
        clients.search.return_value = found
        return add_pinned(hits, list(tables), clients, _table_of, "ns", "ix", True), clients

    def test_missing_table_is_added_first(self):
        out, _ = self._pin(
            [_hit("analysis_income_ttm")], [_hit("x_backup"), _hit("combined_profit_and_loss_income_yearly")]
        )
        assert [_table_of(h.text) for h in out] == ["combined_profit_and_loss_income_yearly", "analysis_income_ttm"]

    def test_present_table_is_not_searched(self):
        out, clients = self._pin([_hit("combined_profit_and_loss_income_yearly")], [])
        clients.search.assert_not_called()
        assert len(out) == 1

    def test_only_an_exact_name_is_pinned(self):
        out, _ = self._pin([_hit("a")], [_hit("combined_profit_and_loss_income_yearly_backup")])
        assert [_table_of(h.text) for h in out] == ["a"]

    def test_lookup_failure_leaves_hits_unchanged(self):
        clients = MagicMock()
        clients.search.side_effect = RuntimeError("down")
        hits = [_hit("a")]
        assert add_pinned(hits, ["b"], clients, _table_of, "n", "i", False) == hits

    async def test_serve_entry_point_runs_the_plain_function(self, monkeypatch):
        seen = {}

        def fake(hits, tables, clients, *rest):
            seen["clients"] = clients
            return ["pinned", *hits]

        monkeypatch.setattr("coa_entity.pinning.add_pinned", fake)
        out = await pin_tables(["h"], ["t"], vector="v", llm="l", table_of=_table_of, namespace="n", index="i",
                               require_mapped=False)  # fmt: skip
        assert out == ["pinned", "h"] and seen["clients"]._vector == "v"
