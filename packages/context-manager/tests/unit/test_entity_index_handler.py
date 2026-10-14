# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Unit tests for the entity-index Lambda (rebuild on ontology.published)."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Loaded by path under a unique module name: the AOSS proxy Lambda's tests put
# their own Lambda directory on sys.path and import a module called `index`.
_SPEC = importlib.util.spec_from_file_location(
    "entity_index_lambda_handler",
    Path(__file__).parents[2] / "lambda" / "entity-index" / "handler.py",
)
assert _SPEC is not None and _SPEC.loader is not None
handler_mod = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(handler_mod)

NS = "824116c4-a93e-4733-9919-17e09bdbc765"


@pytest.fixture(autouse=True)
def _env(monkeypatch):
    monkeypatch.setenv("DATA_SOURCES_TABLE", "sources")
    monkeypatch.setenv("NAMESPACES_TABLE", "namespaces")
    monkeypatch.setenv("OSS_COLLECTION_NAME", "coll")
    monkeypatch.setenv("OSS_ENDPOINT", "https://x.aoss.amazonaws.com")
    monkeypatch.setenv("ATHENA_WORKGROUP_PREFIX", "cuedo-dev-")
    monkeypatch.setenv("SSM_PREFIX", "/cuedo")
    monkeypatch.setenv("AWS_REGION", "us-east-1")


def _dynamodb(source_items, workgroup="cuedo-dev-wg"):
    ddb = MagicMock()
    sources, namespaces = MagicMock(), MagicMock()
    sources.query.return_value = {"Items": source_items}
    namespaces.get_item.return_value = {"Item": {"athenaWorkgroupName": workgroup}} if workgroup else {}
    ddb.Table.side_effect = lambda name: {"sources": sources, "namespaces": namespaces}[name]
    return ddb


def _glue(tables):
    """tables: {(database, table): [column names]}"""
    glue = MagicMock()
    glue.exceptions.EntityNotFoundException = type("EntityNotFoundException", (Exception,), {})

    def get_table(DatabaseName, Name):  # noqa: N803 — boto3 kwarg names
        cols = tables.get((DatabaseName, Name))
        if cols is None:
            raise glue.exceptions.EntityNotFoundException()
        return {"Table": {"StorageDescriptor": {"Columns": [{"Name": c} for c in cols]}}}

    glue.get_table.side_effect = get_table
    return glue


def _ssm(embed_model_id):
    ssm = MagicMock()
    ssm.get_parameter.return_value = {"Parameter": {"Value": json.dumps({"bedrockEmbedModelId": embed_model_id})}}
    return ssm


GLUE_SOURCE = {
    "sourceType": "DATABASE",
    "athenaDatabase": "shravas_db_silver",
    "configuration": json.dumps({"databaseName": "shravas_db_silver"}),
}


@pytest.mark.unit
class TestSourceDatabases:
    def test_native_glue_sources_only(self):
        ddb = _dynamodb(
            [
                GLUE_SOURCE,
                {"sourceType": "DATABASE", "athenaDataCatalogName": "fed_cat", "athenaDatabase": "x"},
                {"sourceType": "DOCUMENT"},
                {"sourceType": "DATABASE", "configuration": json.dumps({"databaseName": "other_db"})},
            ]
        )
        assert handler_mod._source_databases(ddb, NS) == ["shravas_db_silver", "other_db"]

    def test_follows_pagination(self):
        ddb = _dynamodb([])
        sources = ddb.Table("sources")
        sources.query.side_effect = [
            {"Items": [GLUE_SOURCE], "LastEvaluatedKey": {"k": 1}},
            {"Items": [{"sourceType": "DATABASE", "glueDatabaseName": "db2"}]},
        ]
        assert handler_mod._source_databases(ddb, NS) == ["shravas_db_silver", "db2"]


@pytest.mark.unit
class TestFindEntityTable:
    def test_first_database_with_required_columns(self):
        glue = _glue(
            {
                ("a", "sectors"): ["company_id"],  # no company_name
                ("b", "sectors"): ["company_id", "company_name", "cd_sector"],
            }
        )
        found = handler_mod._find_entity_table(glue, ["a", "missing", "b"], "sectors", handler_mod.DEFAULT_COLUMNS)
        assert found == "b"

    def test_none_when_absent(self):
        assert handler_mod._find_entity_table(_glue({}), ["a"], "sectors", handler_mod.DEFAULT_COLUMNS) is None


@pytest.mark.unit
class TestHandler:
    def _run(self, ddb, glue, **patches):
        ssm = patches.get("ssm") or _ssm("titan")

        def client(service, **_kw):
            return {"glue": glue, "athena": MagicMock(), "ssm": ssm}[service]

        with (
            patch.object(handler_mod.boto3, "resource", return_value=ddb),
            patch.object(handler_mod.boto3, "client", side_effect=client),
            patch.object(handler_mod, "read_sectors_table", patches.get("read", MagicMock(return_value=[]))) as read,
            patch.object(handler_mod, "BedrockEmbedder") as embedder,
            patch.object(handler_mod, "AossVectorClient") as aoss,
            patch.object(handler_mod, "write_entity_index", return_value=3) as write,
        ):
            embedder.return_value.dimensions = 1024
            result = handler_mod.handler({"detail-type": "ontology.published", "detail": {"namespace": NS}}, None)
        return result, read, write, aoss

    def test_builds_index_from_sectors_table(self):
        ssm = _ssm("titan")
        glue = _glue({("shravas_db_silver", "sectors"): ["company_id", "company_name", "cd_sector", "cd_subsector"]})
        result, read, write, _ = self._run(_dynamodb([GLUE_SOURCE]), glue, ssm=ssm)

        assert result == {"status": "built", "index": f"coll-entities-{NS}", "documents": 3}
        assert read.call_args.kwargs["database"] == "shravas_db_silver"
        assert read.call_args.kwargs["workgroup"] == "cuedo-dev-wg"
        assert write.call_args.kwargs["embed_model_id"] == "titan"
        ssm.get_parameter.assert_called_once_with(Name="/cuedo/config")

    def test_workgroup_falls_back_to_prefix(self):
        glue = _glue({("shravas_db_silver", "sectors"): ["company_id", "company_name"]})
        _, read, _, _ = self._run(_dynamodb([GLUE_SOURCE], workgroup=None), glue)
        assert read.call_args.kwargs["workgroup"] == f"cuedo-dev-{NS}"

    def test_skips_namespace_without_sectors_table(self):
        result, read, write, _ = self._run(_dynamodb([GLUE_SOURCE]), _glue({}))
        assert result["status"] == "skipped"
        read.assert_not_called()
        write.assert_not_called()

    def test_skips_when_athena_read_fails(self):
        glue = _glue({("shravas_db_silver", "sectors"): ["company_id", "company_name"]})
        result, _, write, _ = self._run(
            _dynamodb([GLUE_SOURCE]), glue, read=MagicMock(side_effect=RuntimeError("Athena query FAILED"))
        )
        assert result == {"status": "skipped", "reason": "could not read the sectors table"}
        write.assert_not_called()

    def test_event_without_namespace(self):
        assert handler_mod.handler({"detail": {}}, None)["status"] == "skipped"
