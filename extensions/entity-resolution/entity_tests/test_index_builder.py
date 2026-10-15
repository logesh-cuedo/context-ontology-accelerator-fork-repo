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
        aoss.raw_client.return_value.indices.exists.side_effect = [False, True, True, True]
        aoss.bulk_index.side_effect = [Exception("NotFoundError(404, 'index_not_found_exception')"), None]
        embedder = MagicMock()
        embedder.embed_documents.return_value = [[0.1]]
        write_index([("t", {})], embedder=embedder, aoss=aoss, index="ix", namespace="ns", embed_model_id="m")
        assert aoss.bulk_index.call_count == 2
        assert aoss.ensure_index.call_count == 2

    def test_resends_only_the_rejected_docs(self):
        class PartialIndexError(Exception):
            def __init__(self, errors):
                super().__init__("partial")
                self.errors = errors

        aoss = MagicMock()
        aoss.raw_client.return_value.indices.exists.return_value = True
        rejected = {"text": "t1", "_op_type": "index", "_index": "ix"}
        aoss.bulk_index.side_effect = [PartialIndexError([{"index": {"status": 404, "data": rejected}}]), None]
        embedder = MagicMock()
        embedder.embed_documents.return_value = [[0.1], [0.2]]
        write_index(
            [("t0", {}), ("t1", {})],
            embedder=embedder,
            aoss=aoss,
            index="ix",
            namespace="ns",
            embed_model_id="m",
            recreate=False,
        )
        assert len(aoss.bulk_index.call_args_list[0].args[1]) == 2
        assert aoss.bulk_index.call_args_list[1].args[1] == [{"text": "t1"}]

    def test_gives_up_after_repeated_rejection(self):
        class PartialIndexError(Exception):
            errors = [{"index": {"status": 400, "data": {"text": "x"}}}]

        aoss = MagicMock()
        aoss.raw_client.return_value.indices.exists.return_value = True
        aoss.bulk_index.side_effect = PartialIndexError("still failing")
        embedder = MagicMock()
        embedder.embed_documents.return_value = [[0.1]]
        with pytest.raises(PartialIndexError):
            write_index(
                [("x", {})],
                embedder=embedder,
                aoss=aoss,
                index="ix",
                namespace="ns",
                embed_model_id="m",
                recreate=False,
            )
        assert aoss.bulk_index.call_count == 4

    def test_waits_for_the_delete_before_recreating(self):
        aoss = MagicMock()
        aoss.raw_client.return_value.indices.exists.side_effect = [True, True, False, True]
        embedder = MagicMock()
        embedder.embed_documents.return_value = [[0.1]]
        write_index([("t", {})], embedder=embedder, aoss=aoss, index="ix", namespace="ns", embed_model_id="m")
        # three polls until the delete lands, one until the new index is ready
        assert aoss.raw_client.return_value.indices.exists.call_count == 4

    def test_recreates_then_writes_in_chunks(self):
        docs = [(f"t{i}", {"entity_type": "company", "entity_uri": str(i)}) for i in range(450)]
        embedder = MagicMock()
        embedder.embed_documents.side_effect = lambda texts: [[0.1] for _ in texts]
        aoss = MagicMock()
        aoss.raw_client.return_value.indices.exists.side_effect = [False, True, True, True]

        assert write_index(docs, embedder=embedder, aoss=aoss, index="ix", namespace="ns", embed_model_id="m") == 450
        aoss.delete_index.assert_called_once_with("ix")
        assert [len(c.args[1]) for c in aoss.bulk_index.call_args_list] == [200, 200, 50]
        assert aoss.bulk_index.call_args_list[0].args[1][0]["embedding_type"] == "entity"


@pytest.mark.unit
class TestIndexNames:
    def test_versioned_names_round_trip(self):
        from coa_entity.index_builder import parse_index_name, versioned_index_name

        ns = "824116c4-a93e-4733-9919-17e09bdbc765"
        assert parse_index_name("coll", versioned_index_name("coll", ns, 1791990000)) == (ns, 1791990000)
        assert parse_index_name("coll", f"coll-entities-{ns}") == (ns, None)
        assert parse_index_name("coll", "coll-chunk_x") is None

    def test_name_catalog_lists_every_entity(self):
        from coa_entity.index_builder import name_catalog

        docs = build_documents(sample_config().entity_types[0], ROWS)
        cat = name_catalog(docs)
        assert ["company", "1", "Bajaj Auto Ltd.", {"cd_sector": "Automobile", "cd_subsector": "2W"}] in cat["entities"]
        assert ["sector", "Automobile", "Automobile", {}] in cat["entities"]
