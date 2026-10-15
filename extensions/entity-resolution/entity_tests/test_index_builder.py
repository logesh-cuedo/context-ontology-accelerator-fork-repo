# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Generic entity documents and index writes."""

from __future__ import annotations

import json
from unittest.mock import MagicMock

import pytest

from coa_entity.config import parse_config
from coa_entity.index_builder import acronyms, build_all_documents, build_documents, read_rows, write_index

from .helpers import sample_config

ROWS = [
    {"company_id": "1", "company_name": "Bajaj Auto Ltd.", "cd_sector": "Automobile", "cd_subsector": "2W"},
    {"company_id": "2", "company_name": "Hero MotoCorp Ltd.", "cd_sector": "Automobile", "cd_subsector": ""},
]


@pytest.mark.unit
class TestDocuments:
    def test_acronyms_skip_legal_suffixes(self):
        assert acronyms("Tata Consultancy Services Ltd.") == ["TCS"]
        assert acronyms("Infosys Ltd.") == []

    def test_members_then_group_values(self):
        spec = sample_config().entity_types[0]
        docs = build_documents(spec, ROWS)
        assert [d["entity_type"] for _, d in docs] == ["company", "company", "sector"]
        text, doc = docs[0]
        assert text == "Bajaj Auto Ltd. (BA) — cd_sector: Automobile; cd_subsector: 2W"
        assert json.loads(doc["context_text"]) == {
            "name": "Bajaj Auto Ltd.",
            "attrs": {"cd_sector": "Automobile", "cd_subsector": "2W"},
        }
        assert docs[-1][0] == "Automobile (sector) — cd_subsector: 2W"
        assert docs[-1][1]["entity_uri"] == "Automobile"

    def test_any_entity_type_without_acronyms_or_groups(self):
        config = parse_config(
            {"entities": [{"type": "product", "table": "products", "idColumn": "sku", "nameColumn": "title"}]}
        )
        docs, counts = build_all_documents(config, lambda spec: [{"sku": "A1", "title": "Blue Widget"}])
        assert counts == {"product": 1}
        assert docs[0][0] == "Blue Widget"


@pytest.mark.unit
class TestReadRows:
    def _athena(self, rows, state="SUCCEEDED"):
        athena = MagicMock()
        athena.start_query_execution.return_value = {"QueryExecutionId": "q1"}
        athena.get_query_execution.return_value = {
            "QueryExecution": {"Status": {"State": state, "StateChangeReason": "denied"}}
        }
        athena.get_paginator.return_value.paginate.return_value = [
            {"ResultSet": {"Rows": [{"Data": [{"VarCharValue": v} for v in r]} for r in rows]}}
        ]
        return athena

    def test_selects_configured_columns_and_dedupes(self):
        spec = sample_config().entity_types[0]
        athena = self._athena(
            [
                ["company_id", "company_name", "cd_sector", "cd_subsector"],
                ["1", "TCS Ltd.", "IT", "Services"],
                ["1", "TCS Ltd.", "IT", "Other"],
                ["2", " Infosys Ltd. ", "IT", "Services"],
            ]
        )
        rows = read_rows(athena, database="db", spec=spec, workgroup="wg")
        assert [r["company_name"] for r in rows] == ["TCS Ltd.", "Infosys Ltd."]
        sql = athena.start_query_execution.call_args.kwargs["QueryString"]
        assert 'FROM "db"."sectors"' in sql and '"cd_subsector"' in sql

    def test_failed_query_raises(self):
        with pytest.raises(RuntimeError, match="denied"):
            read_rows(
                self._athena([], state="FAILED"), database="db", spec=sample_config().entity_types[0], workgroup="w"
            )


@pytest.fixture(autouse=True)
def _no_sleep(monkeypatch):
    from coa_entity import index_builder

    monkeypatch.setattr(index_builder.time, "sleep", lambda _s: None)


@pytest.mark.unit
class TestWriteIndex:
    def test_retries_once_when_aoss_still_routes_to_the_deleted_index(self):
        aoss = MagicMock()
        aoss.raw_client.return_value.indices.exists.return_value = False
        aoss.bulk_index.side_effect = [Exception("NotFoundError(404, 'index_not_found_exception')"), None]
        embedder = MagicMock()
        embedder.embed_documents.return_value = [[0.1]]
        write_index([("t", {})], embedder=embedder, aoss=aoss, index="ix", namespace="ns", embed_model_id="m")
        assert aoss.bulk_index.call_count == 2
        assert aoss.ensure_index.call_count == 2

    def test_waits_for_the_delete_before_recreating(self):
        aoss = MagicMock()
        aoss.raw_client.return_value.indices.exists.side_effect = [True, True, False]
        embedder = MagicMock()
        embedder.embed_documents.return_value = [[0.1]]
        write_index([("t", {})], embedder=embedder, aoss=aoss, index="ix", namespace="ns", embed_model_id="m")
        assert aoss.raw_client.return_value.indices.exists.call_count == 3

    def test_recreates_then_writes_in_chunks(self):
        docs = [(f"t{i}", {"entity_type": "company", "entity_uri": str(i)}) for i in range(450)]
        embedder = MagicMock()
        embedder.embed_documents.side_effect = lambda texts: [[0.1] for _ in texts]
        aoss = MagicMock()
        aoss.raw_client.return_value.indices.exists.return_value = False

        assert write_index(docs, embedder=embedder, aoss=aoss, index="ix", namespace="ns", embed_model_id="m") == 450
        aoss.delete_index.assert_called_once_with("ix")
        assert [len(c.args[1]) for c in aoss.bulk_index.call_args_list] == [200, 200, 50]
        assert aoss.bulk_index.call_args_list[0].args[1][0]["embedding_type"] == "entity"
