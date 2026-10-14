# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Entity-index Lambda: rebuild a namespace's company/sector index on publish.

Triggered by the ``ontology.published`` EventBridge event (the same event that
reloads VKG). For the published namespace it:

  1. lists the namespace's native Glue database sources (sources table),
  2. picks the first database holding a table named ``ENTITY_TABLE_NAME``
     (default ``sectors``) that has the expected company/sector columns,
  3. rebuilds ``{collection}-entities-{namespace}`` from it — see
     ``coa_common.entity_index``.

Fail-open by design: a namespace with no such table, a missing column, or an
Athena/Lake Formation denial is logged and skipped. Serve then resolves the
step to "skipped (entity index empty)" and Tier 2 runs unchanged.

Federated (``athenaDataCatalogName``) sources are not scanned: their tables
live behind a connector, and the sectors table this feature targets is a
native Glue table.
"""

from __future__ import annotations

import json
import os
from typing import Any

import boto3
import structlog
from coa_common import entity_vector_index_name, resolve_region
from coa_common.embeddings import BedrockEmbedder
from coa_common.entity_index import DEFAULT_COLUMNS, build_documents, read_sectors_table, write_entity_index
from coa_common.opensearch.client import AossVectorClient

logger = structlog.get_logger(__name__)

_SOURCE_TYPE_DATABASE = "DATABASE"


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


def _source_databases(dynamodb: Any, namespace: str) -> list[str]:
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


def _find_entity_table(glue: Any, databases: list[str], table: str, columns: dict[str, str]) -> str | None:
    """First database whose ``table`` carries the id and name columns (sector columns optional)."""
    required = {columns["id"].lower(), columns["name"].lower()}
    for database in databases:
        try:
            meta = glue.get_table(DatabaseName=database, Name=table)["Table"]
        except glue.exceptions.EntityNotFoundException:
            continue
        except Exception as exc:  # AccessDenied (strict Lake Formation) and friends
            logger.warning("entity_index_table_lookup_failed", database=database, table=table, error=str(exc)[:200])
            continue
        present = {c["Name"].lower() for c in meta.get("StorageDescriptor", {}).get("Columns", [])}
        present |= {c["Name"].lower() for c in meta.get("PartitionKeys", [])}
        if required <= present:
            return database
        logger.info(
            "entity_index_table_columns_missing", database=database, table=table, missing=sorted(required - present)
        )
    return None


def _workgroup(dynamodb: Any, namespace: str) -> str:
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
        logger.warning("entity_index_workgroup_lookup_failed", namespace=namespace, error=str(exc)[:200])
    return f"{_env('ATHENA_WORKGROUP_PREFIX')}{namespace}"


def _embed_model_id(ssm: Any) -> str:
    """Serve's embedding model — the index MUST use the same one as query embedding."""
    raw = ssm.get_parameter(Name=f"{_env('SSM_PREFIX')}/config")["Parameter"]["Value"]
    return json.loads(raw).get("bedrockEmbedModelId") or _env("DEFAULT_EMBED_MODEL_ID")


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """Rebuild the entity index for the namespace in an ``ontology.published`` event."""
    namespace = str((event.get("detail") or {}).get("namespace") or "")
    if not namespace:
        logger.warning("entity_index_no_namespace", detail_type=event.get("detail-type"))
        return {"status": "skipped", "reason": "no namespace in event"}

    region = resolve_region()
    table = _env("ENTITY_TABLE_NAME", "sectors")
    dynamodb = boto3.resource("dynamodb", region_name=region)

    databases = _source_databases(dynamodb, namespace)
    database = _find_entity_table(boto3.client("glue", region_name=region), databases, table, DEFAULT_COLUMNS)
    if not database:
        logger.info("entity_index_skipped_no_table", namespace=namespace, table=table, databases=databases)
        return {"status": "skipped", "reason": f"no '{table}' table in the namespace's sources"}

    workgroup = _workgroup(dynamodb, namespace)
    index = entity_vector_index_name(_env("OSS_COLLECTION_NAME"), namespace)
    try:
        companies = read_sectors_table(
            boto3.client("athena", region_name=region),
            database=database,
            table=table,
            workgroup=workgroup,
            columns=DEFAULT_COLUMNS,
        )
    except Exception as exc:
        # Typically a Lake Formation denial in strict-LF accounts: this role needs
        # SELECT on the table, which is granted outside COA. Skip, don't retry.
        logger.warning(
            "entity_index_read_failed", namespace=namespace, database=database, table=table, error=str(exc)[:300]
        )
        return {"status": "skipped", "reason": "could not read the sectors table"}

    docs = build_documents(companies)
    model_id = _embed_model_id(boto3.client("ssm", region_name=region))
    embedder = BedrockEmbedder(model_id=model_id, region=region, max_workers=int(_env("EMBED_MAX_WORKERS", "16")))
    aoss = AossVectorClient(endpoint=_env("OSS_ENDPOINT"), region=region, dimensions=embedder.dimensions)
    written = write_entity_index(
        docs, embedder=embedder, aoss=aoss, index=index, namespace=namespace, embed_model_id=model_id
    )
    logger.info(
        "entity_index_built",
        namespace=namespace,
        database=database,
        table=table,
        companies=len(companies),
        documents=written,
        index=index,
    )
    return {"status": "built", "index": index, "documents": written}
