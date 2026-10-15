# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Entity-index Lambda: build on ontology publish, sweep orphans daily.

Events:
  ``ontology.published`` (EventBridge)   rebuild that namespace's entity index
  ``Scheduled Event`` (EventBridge)      delete entity indexes of deleted namespaces
  ``{"action": "build", "namespace": …}`` manual rebuild
  ``{"action": "sweep"}``                 manual sweep

Build: the namespace's EntityConfig (SSM, see coa_entity.config) names the
tables. For each entity type the table is looked up in the namespace's native
Glue database sources (or the ``database`` the config pins), read through the
namespace's Athena workgroup, embedded and written to
``{collection}-entities-{namespace}``.

Fail-open: no config, a missing table/column, or an Athena/Lake Formation denial
is logged and skipped — serve then falls back to its LIKE filter rules.
"""

from __future__ import annotations

import json
import os
from typing import Any

import boto3
import structlog

from .config import EntityConfigError, EntityTypeSpec, load_config
from .index_builder import build_all_documents, index_name, read_rows, write_index

logger = structlog.get_logger(__name__)

_SOURCE_TYPE_DATABASE = "DATABASE"


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


def _region() -> str:
    return _env("AWS_REGION") or _env("AWS_DEFAULT_REGION") or "us-east-1"


def source_databases(dynamodb: Any, namespace: str) -> list[str]:
    """Native Glue database names registered to ``namespace``, in source order."""
    table = dynamodb.Table(_env("DATA_SOURCES_TABLE"))
    items: list[dict[str, Any]] = []
    kwargs: dict[str, Any] = {
        "KeyConditionExpression": "PK = :pk AND begins_with(SK, :prefix)",
        "ExpressionAttributeValues": {":pk": f"NS#{namespace}", ":prefix": "SRC#"},
    }
    while True:
        page = table.query(**kwargs)
        items.extend(page.get("Items", []))
        if not page.get("LastEvaluatedKey"):
            break
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]

    databases: list[str] = []
    for item in items:
        # Federated sources sit behind a connector; entity tables are native Glue tables.
        if item.get("sourceType") != _SOURCE_TYPE_DATABASE or item.get("athenaDataCatalogName"):
            continue
        raw = item.get("configuration") or "{}"
        try:
            config = json.loads(raw) if isinstance(raw, str) else dict(raw)
        except (json.JSONDecodeError, TypeError, ValueError):
            config = {}
        name = item.get("athenaDatabase") or item.get("glueDatabaseName") or config.get("databaseName") or ""
        if name and name not in databases:
            databases.append(str(name))
    return databases


def find_database(glue: Any, databases: list[str], spec: EntityTypeSpec) -> str | None:
    """First database whose ``spec.table`` has every column the spec reads."""
    required = {c.lower() for c in spec.columns}
    for database in [spec.database] if spec.database else databases:
        try:
            meta = glue.get_table(DatabaseName=database, Name=spec.table)["Table"]
        except glue.exceptions.EntityNotFoundException:
            continue
        except Exception as exc:  # AccessDenied (strict Lake Formation) and friends
            logger.warning("entity_table_lookup_failed", database=database, table=spec.table, error=str(exc)[:200])
            continue
        present = {c["Name"].lower() for c in meta.get("StorageDescriptor", {}).get("Columns", [])}
        present |= {c["Name"].lower() for c in meta.get("PartitionKeys", [])}
        if required <= present:
            return database
        logger.warning(
            "entity_table_columns_missing", database=database, table=spec.table, missing=sorted(required - present)
        )
    return None


def workgroup(dynamodb: Any, namespace: str) -> str:
    """The namespace's Athena workgroup (namespaces table), else the deployment's naming convention."""
    try:
        item = (
            dynamodb.Table(_env("NAMESPACES_TABLE"))
            .get_item(Key={"PK": f"NS#{namespace}", "SK": "METADATA"}, ProjectionExpression="athenaWorkgroupName")
            .get("Item", {})
        )
        if item.get("athenaWorkgroupName"):
            return str(item["athenaWorkgroupName"])
    except Exception as exc:
        logger.warning("entity_workgroup_lookup_failed", namespace=namespace, error=str(exc)[:200])
    return f"{_env('ATHENA_WORKGROUP_PREFIX')}{namespace}"


def _embed_model_id(ssm: Any) -> str:
    """Serve's embedding model — the index MUST use the same one as query embedding."""
    raw = ssm.get_parameter(Name=f"{_env('SSM_PREFIX')}/config")["Parameter"]["Value"]
    return json.loads(raw).get("bedrockEmbedModelId") or ""


def build(namespace: str) -> dict[str, Any]:
    """Rebuild one namespace's entity index from its configured tables."""
    region = _region()
    ssm = boto3.client("ssm", region_name=region)
    try:
        config = load_config(ssm, _env("SSM_PREFIX"), namespace)
    except EntityConfigError as exc:
        logger.warning("entity_config_invalid", namespace=namespace, error=str(exc)[:300])
        return {"status": "skipped", "reason": f"invalid entity config: {exc}"}
    if config is None:
        logger.info("entity_index_skipped_no_config", namespace=namespace)
        return {"status": "skipped", "reason": "no entity config"}

    dynamodb = boto3.resource("dynamodb", region_name=region)
    glue = boto3.client("glue", region_name=region)
    athena = boto3.client("athena", region_name=region)
    databases = source_databases(dynamodb, namespace)
    wg = workgroup(dynamodb, namespace)

    located = {spec.type: find_database(glue, databases, spec) for spec in config.entity_types}
    missing = [t for t, db in located.items() if not db]
    if len(missing) == len(located):
        logger.info("entity_index_skipped_no_table", namespace=namespace, databases=databases)
        return {"status": "skipped", "reason": "no configured entity table in the namespace's sources"}

    def read(spec: EntityTypeSpec) -> list[dict[str, str]]:
        database = located.get(spec.type)
        return read_rows(athena, database=database, spec=spec, workgroup=wg) if database else []

    try:
        docs, counts = build_all_documents(config, read)
    except Exception as exc:
        # Typically a Lake Formation denial in strict-LF accounts: this role needs
        # SELECT on the entity tables, granted outside COA. Skip, don't retry.
        logger.warning("entity_index_read_failed", namespace=namespace, error=str(exc)[:300])
        return {"status": "skipped", "reason": "could not read the entity tables"}
    if not docs:
        return {"status": "skipped", "reason": "entity tables are empty"}

    from coa_common.embeddings import BedrockEmbedder
    from coa_common.opensearch.client import AossVectorClient

    model_id = _embed_model_id(ssm)
    embedder = BedrockEmbedder(
        model_id=model_id or None, region=region, max_workers=int(_env("EMBED_MAX_WORKERS", "16"))
    )
    aoss = AossVectorClient(endpoint=_env("OSS_ENDPOINT"), region=region, dimensions=embedder.dimensions)
    index = index_name(_env("OSS_COLLECTION_NAME"), namespace)
    written = write_index(docs, embedder=embedder, aoss=aoss, index=index, namespace=namespace, embed_model_id=model_id)
    logger.info(
        "entity_index_built", namespace=namespace, index=index, documents=written, by_type=counts, missing=missing
    )
    return {"status": "built", "index": index, "documents": written, "by_type": counts, "missing_types": missing}


def sweep() -> dict[str, Any]:
    """Delete entity indexes whose namespace no longer exists."""
    from coa_common.opensearch.client import AossVectorClient

    region = _region()
    collection = _env("OSS_COLLECTION_NAME")
    prefix = index_name(collection, "")
    aoss = AossVectorClient(endpoint=_env("OSS_ENDPOINT"), region=region)
    try:
        rows = aoss.raw_client().cat.indices(index=f"{prefix}*", format="json")
    except Exception as exc:
        if "index_not_found" in str(exc) or "404" in str(exc):
            rows = []
        else:
            raise
    namespaces = boto3.resource("dynamodb", region_name=region).Table(_env("NAMESPACES_TABLE"))
    deleted: list[str] = []
    for row in rows or []:
        index = str(row.get("index") or "")
        namespace = index[len(prefix) :]
        if not index.startswith(prefix) or not namespace:
            continue
        exists = namespaces.get_item(Key={"PK": f"NS#{namespace}", "SK": "METADATA"}).get("Item")
        if not exists and aoss.delete_index(index):
            deleted.append(index)
    logger.info("entity_index_sweep", checked=len(rows or []), deleted=deleted)
    return {"status": "swept", "deleted": deleted}


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """Dispatch an EventBridge event or a manual ``{"action": ...}`` invoke."""
    action = event.get("action")
    detail_type = event.get("detail-type")
    if action == "sweep" or detail_type == "Scheduled Event":
        return sweep()
    namespace = str(event.get("namespace") or (event.get("detail") or {}).get("namespace") or "")
    if action == "build" or detail_type == "ontology.published":
        if not namespace:
            logger.warning("entity_index_no_namespace", detail_type=detail_type)
            return {"status": "skipped", "reason": "no namespace in event"}
        return build(namespace)
    return {"status": "ignored", "reason": f"unhandled event {detail_type or action!r}"}
