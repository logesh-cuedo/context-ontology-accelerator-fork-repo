# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Tests for the shared company/sector entity-index builder."""

from __future__ import annotations

import json
from unittest.mock import MagicMock

import pytest
from coa_common.entity_index import (
    DEFAULT_COLUMNS,
    acronyms,
    build_documents,
    read_sectors_table,
    write_entity_index,
)


@pytest.mark.unit
class TestAcronyms:
    def test_skips_legal_suffixes(self):
        assert acronyms("Tata Consultancy Services Ltd.") == ["TCS"]

    def test_single_word_has_none(self):
        assert acronyms("Infosys Ltd.") == []


@pytest.mark.unit
class TestBuildDocuments:
    def test_one_document_per_company_and_sector(self):
        bajaj = {"company_id": "1", "company_name": "Bajaj Auto Ltd.", "cd_sector": "Automobiles", "cd_subsector": "2W"}
        hero = {"company_id": "2", "company_name": "Hero MotoCorp Ltd.", "cd_sector": "Automobiles", "cd_subsector": ""}
        docs = build_documents([bajaj, hero])
        kinds = [d["entity_type"] for _, d in docs]
        assert kinds == ["company", "company", "sector"]
        sector_text, sector_doc = docs[-1]
        assert sector_text == "Automobiles sector — subsectors: 2W"
        assert json.loads(sector_doc["context_text"]) == {"cd_sector": "Automobiles", "subsectors": ["2W"]}
        assert docs[0][0] == "Bajaj Auto Ltd. (BA) — sector: Automobiles ; subsector: 2W"


@pytest.mark.unit
class TestReadSectorsTable:
    def test_dedupes_by_company_id(self):
        athena = MagicMock()
        athena.start_query_execution.return_value = {"QueryExecutionId": "q1"}
        athena.get_query_execution.return_value = {"QueryExecution": {"Status": {"State": "SUCCEEDED"}}}

        def row(*values):
            return {"Data": [{"VarCharValue": v} for v in values]}

        athena.get_paginator.return_value.paginate.return_value = [
            {
                "ResultSet": {
                    "Rows": [
                        row("company_id", "company_name", "cd_sector", "cd_subsector"),
                        row("1", "TCS Ltd.", "IT", "Services"),
                        row("1", "TCS Ltd.", "IT", "Other"),
                        row("2", " Infosys Ltd. ", "IT", "Services"),
                    ]
                }
            }
        ]
        rows = read_sectors_table(athena, database="db", table="sectors", workgroup="wg", columns=DEFAULT_COLUMNS)
        assert [r["company_name"] for r in rows] == ["TCS Ltd.", "Infosys Ltd."]
        assert athena.start_query_execution.call_args.kwargs["WorkGroup"] == "wg"

    def test_failed_query_raises(self):
        athena = MagicMock()
        athena.start_query_execution.return_value = {"QueryExecutionId": "q1"}
        athena.get_query_execution.return_value = {
            "QueryExecution": {"Status": {"State": "FAILED", "StateChangeReason": "denied"}}
        }
        with pytest.raises(RuntimeError, match="denied"):
            read_sectors_table(athena, database="db", table="sectors", workgroup="wg", columns=DEFAULT_COLUMNS)


@pytest.mark.unit
class TestWriteEntityIndex:
    def test_recreates_then_writes_in_chunks(self):
        docs = [(f"text {i}", {"entity_type": "company", "entity_uri": str(i)}) for i in range(450)]
        embedder = MagicMock()
        embedder.embed_documents.side_effect = lambda texts: [[0.1] for _ in texts]
        aoss = MagicMock()

        written = write_entity_index(
            docs, embedder=embedder, aoss=aoss, index="ix", namespace="ns", embed_model_id="titan"
        )

        assert written == 450
        aoss.delete_index.assert_called_once_with("ix")
        aoss.ensure_index.assert_called_once_with("ix")
        assert [len(c.args[1]) for c in aoss.bulk_index.call_args_list] == [200, 200, 50]
        first = aoss.bulk_index.call_args_list[0].args[1][0]
        assert first["namespace"] == "ns"
        assert first["embedding_type"] == "entity"

    def test_append_mode_keeps_index(self):
        aoss = MagicMock()
        embedder = MagicMock()
        embedder.embed_documents.return_value = [[0.1]]
        write_entity_index(
            [("t", {})], embedder=embedder, aoss=aoss, index="ix", namespace="ns", embed_model_id="m", recreate=False
        )
        aoss.delete_index.assert_not_called()
