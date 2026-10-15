# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Entity-index Lambda: source discovery, table lookup, build, sweep, dispatch."""

from __future__ import annotations

import json
from unittest.mock import MagicMock, patch

import pytest

from coa_entity import lambda_handler as h

from .helpers import sample_config, sample_document

NS = "824116c4-a93e-4733-9919-17e09bdbc765"
GLUE_SOURCE = {
    "sourceType": "DATABASE",
    "athenaDatabase": "shravas_db_silver",
    "configuration": json.dumps({"databaseName": "shravas_db_silver"}),
}
SECTOR_COLUMNS = ["company_id", "company_name", "cd_sector", "cd_subsector"]


@pytest.fixture(autouse=True)
def _env(monkeypatch):
    for k, v in {
        "DATA_SOURCES_TABLE": "sources",
        "NAMESPACES_TABLE": "namespaces",
        "OSS_COLLECTION_NAME": "coll",
        "OSS_ENDPOINT": "https://x.aoss.amazonaws.com",
        "ATHENA_WORKGROUP_PREFIX": "cuedo-dev-",
        "ENTITY_BUCKET": "bkt",
        "SSM_PREFIX": "/cuedo",
        "AWS_REGION": "us-east-1",
    }.items():
        monkeypatch.setenv(k, v)


def _dynamodb(items, workgroup="cuedo-dev-wg", existing_namespaces=(NS,)):
    ddb = MagicMock()
    sources, namespaces = MagicMock(), MagicMock()
    sources.query.return_value = {"Items": items}

    def get_item(Key, ProjectionExpression=None):  # noqa: N803
        ns = Key["PK"][3:]
        if ns not in existing_namespaces:
            return {}
        return {"Item": {"athenaWorkgroupName": workgroup} if workgroup else {"PK": Key["PK"]}}

    namespaces.get_item.side_effect = get_item
    ddb.Table.side_effect = lambda name: {"sources": sources, "namespaces": namespaces}[name]
    return ddb


def _glue(tables):
    glue = MagicMock()
    glue.exceptions.EntityNotFoundException = type("EntityNotFoundException", (Exception,), {})

    def get_table(DatabaseName, Name):  # noqa: N803
        cols = tables.get((DatabaseName, Name))
        if cols is None:
            raise glue.exceptions.EntityNotFoundException()
        return {"Table": {"StorageDescriptor": {"Columns": [{"Name": c} for c in cols]}}}

    glue.get_table.side_effect = get_table
    return glue


def _ssm(config=None, pointer=None):
    ssm = MagicMock()
    ssm.exceptions.ParameterNotFound = type("ParameterNotFound", (Exception,), {})

    def get_parameter(Name):  # noqa: N803
        if "/entities/_active/" in Name and pointer is not None and Name.endswith(NS):
            return {"Parameter": {"Value": json.dumps(pointer)}}
        if Name == "/cuedo/config":
            return {"Parameter": {"Value": json.dumps({"bedrockEmbedModelId": "titan"})}}
        if Name == "/cuedo/entities/default" and config is not None:
            return {"Parameter": {"Value": json.dumps(config)}}
        raise ssm.exceptions.ParameterNotFound()

    ssm.get_parameter.side_effect = get_parameter
    return ssm


@pytest.mark.unit
class TestDiscovery:
    def test_native_glue_sources_only(self):
        ddb = _dynamodb(
            [
                GLUE_SOURCE,
                {"sourceType": "DATABASE", "athenaDataCatalogName": "fed", "athenaDatabase": "x"},
                {"sourceType": "DOCUMENT"},
                {"sourceType": "DATABASE", "configuration": json.dumps({"databaseName": "other_db"})},
            ]
        )
        assert h.source_databases(ddb, NS) == ["shravas_db_silver", "other_db"]

    def test_table_needs_every_configured_column(self):
        spec = sample_config().entity_types[0]
        glue = _glue({("a", "sectors"): ["company_id", "company_name"], ("b", "sectors"): SECTOR_COLUMNS})
        assert h.find_database(glue, ["a", "missing", "b"], spec) == "b"

    def test_workgroup_falls_back_to_prefix(self):
        assert h.workgroup(_dynamodb([], workgroup=None), NS) == f"cuedo-dev-{NS}"


@pytest.mark.unit
class TestBuild:
    def _run(self, *, config=None, tables=None, read=None, previous=None):
        ddb = _dynamodb([GLUE_SOURCE])
        glue = _glue(tables if tables is not None else {("shravas_db_silver", "sectors"): SECTOR_COLUMNS})
        ssm = _ssm(sample_document() if config is None else config, pointer=previous)
        self.ssm, self.s3, self.aoss = ssm, MagicMock(), MagicMock()

        def client(service, **_kw):
            return {"glue": glue, "athena": MagicMock(), "ssm": ssm, "s3": self.s3}[service]

        rows = [{"company_id": "1", "company_name": "TCS Ltd.", "cd_sector": "IT", "cd_subsector": ""}]
        with (
            patch.object(h.boto3, "resource", return_value=ddb),
            patch.object(h.boto3, "client", side_effect=client),
            patch.object(h, "read_rows", read or MagicMock(return_value=rows)) as read_rows,
            patch("coa_common.embeddings.BedrockEmbedder") as embedder,
            patch("coa_common.opensearch.client.AossVectorClient", return_value=self.aoss),
            patch.object(h, "write_index", side_effect=lambda docs, **kw: len(docs)) as write,
        ):
            embedder.return_value.dimensions = 1024
            result = h.handler({"detail-type": "ontology.published", "detail": {"namespace": NS}}, None)
        return result, read_rows, write

    def test_builds_from_configured_table(self):
        result, read_rows, write = self._run()
        assert result["status"] == "built"
        assert result["by_type"] == {"company": 1, "sector": 1}
        assert read_rows.call_args.kwargs["database"] == "shravas_db_silver"
        assert read_rows.call_args.kwargs["workgroup"] == "cuedo-dev-wg"
        index = write.call_args.kwargs["index"]
        assert index.startswith(f"coll-entities-{NS}-v") and write.call_args.kwargs["recreate"] is False
        assert write.call_args.kwargs["embed_model_id"] == "titan"

    def test_publishes_name_list_then_pointer_and_retires_old_versions(self):
        previous = {"index": f"coll-entities-{NS}-v1", "names": f"s3://bkt/entities/{NS}/v1.json", "version": 1}
        result, _, _ = self._run(previous=previous)
        put = self.s3.put_object.call_args.kwargs
        assert put["Bucket"] == "bkt" and put["Key"].startswith(f"entities/{NS}/v")
        catalog = json.loads(put["Body"])
        assert ["company", "1", "TCS Ltd.", {"cd_sector": "IT"}] in catalog["entities"]
        pointer = json.loads(self.ssm.put_parameter.call_args.kwargs["Value"])
        assert pointer["index"] == result["index"] and pointer["names"] == f"s3://bkt/{put['Key']}"
        deleted = [c.args[0] for c in self.aoss.delete_index.call_args_list]
        assert deleted == [f"coll-entities-{NS}", f"coll-entities-{NS}-v1"]
        self.s3.delete_object.assert_called_once_with(Bucket="bkt", Key=f"entities/{NS}/v1.json")

    def test_skips_without_config(self):
        result, read_rows, _ = self._run(config={})
        assert result["status"] == "skipped"

    def test_skips_without_table(self):
        result, read_rows, write = self._run(tables={})
        assert result["status"] == "skipped"
        read_rows.assert_not_called()
        write.assert_not_called()

    def test_skips_when_read_fails(self):
        result, _, write = self._run(read=MagicMock(side_effect=RuntimeError("Athena query FAILED")))
        assert result == {"status": "skipped", "reason": "could not read the entity tables"}
        write.assert_not_called()


@pytest.mark.unit
class TestSweepAndDispatch:
    def _sweep(self, indexes, pointer=None):
        aoss = MagicMock()
        aoss.raw_client.return_value.cat.indices.return_value = [{"index": i} for i in indexes]
        aoss.delete_index.return_value = True
        ssm, s3 = _ssm(None, pointer=pointer), MagicMock()
        s3.list_objects_v2.return_value = {"Contents": [{"Key": "entities/gone/v5.json"}]}
        with (
            patch("coa_common.opensearch.client.AossVectorClient", return_value=aoss),
            patch.object(h.boto3, "resource", return_value=_dynamodb([])),
            patch.object(h.boto3, "client", side_effect=lambda svc, **_k: {"ssm": ssm, "s3": s3}[svc]),
        ):
            return h.handler({"detail-type": "Scheduled Event"}, None), ssm, s3

    def test_sweep_deletes_deleted_namespaces_with_their_pointer_and_names(self):
        result, ssm, s3 = self._sweep([f"coll-entities-{NS}", "coll-entities-gone-v5"])
        assert result == {"status": "swept", "deleted": ["coll-entities-gone-v5"]}
        ssm.delete_parameter.assert_called_once_with(Name="/cuedo/entities/_active/gone")
        s3.delete_object.assert_called_once_with(Bucket="bkt", Key="entities/gone/v5.json")

    def test_sweep_keeps_the_active_version_and_drops_old_ones(self):
        active = {"index": f"coll-entities-{NS}-v2000000000", "names": "", "version": 2000000000}
        result, _, _ = self._sweep(
            [f"coll-entities-{NS}-v2000000000", f"coll-entities-{NS}-v100", f"coll-entities-{NS}"], pointer=active
        )
        assert result["deleted"] == [f"coll-entities-{NS}-v100", f"coll-entities-{NS}"]

    def test_unknown_event_is_ignored(self):
        assert h.handler({"detail-type": "something.else"}, None)["status"] == "ignored"

    def test_publish_without_namespace(self):
        assert h.handler({"detail-type": "ontology.published", "detail": {}}, None)["status"] == "skipped"
