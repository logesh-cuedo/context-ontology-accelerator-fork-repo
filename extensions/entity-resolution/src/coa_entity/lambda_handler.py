# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Entity-index Lambda: rebuild when an ontology is published, clean up old indexes daily.

Events:
  ``ontology.published`` (EventBridge)   rebuild that namespace's entity index
  ``Scheduled Event`` (EventBridge)      delete indexes of deleted namespaces
  ``{"action": "build", "namespace": …}`` manual rebuild
  ``{"action": "sweep"}``                 manual clean-up

Build: the namespace's entity config (in SSM, see config.py) names the tables.
Each table is looked up in the namespace's Glue databases (or the ``database``
set in the config), read through the namespace's Athena workgroup, turned into
vectors and saved to ``{collection}-entities-{namespace}``.

If there is no config, a table or column is missing, or Athena / Lake Formation
says no, it is logged and skipped. Serve then uses its general LIKE filter rules.
"""

from __future__ import annotations

import json
import os
import time
from typing import Any

import boto3
import structlog

from .active import ActivePointer, delete_pointer, read_pointer, write_pointer
from .config import EntityConfigError, EntityTypeSpec, load_config
from .index_builder import (
    build_all_documents,
    index_name,
    name_catalog,
    parse_index_name,
    read_rows,
    versioned_index_name,
    write_index,
)

logger = structlog.get_logger(__name__)

_SOURCE_TYPE_DATABASE = "DATABASE"


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


def _region() -> str:
    return _env("AWS_REGION") or _env("AWS_DEFAULT_REGION") or "us-east-1"


def source_databases(dynamodb: Any, namespace: str) -> list[str]:
    """The Glue database names added as sources to ``namespace``, in order."""
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
        # Skip sources behind a connector; entity tables must be plain Glue tables.
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
        except Exception as exc:  # e.g. AccessDenied from Lake Formation
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
    """The namespace's Athena workgroup (from the namespaces table), else the default name."""
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
        # Usually Lake Formation saying no: this role needs SELECT on the entity
        # tables, which is granted outside COA. Skip, don't retry.
        logger.warning("entity_index_read_failed", namespace=namespace, error=str(exc)[:300])
        return {"status": "skipped", "reason": "could not read the entity tables"}
    if not docs:
        return {"status": "skipped", "reason": "entity tables are empty"}

    from coa_common.embeddings import BedrockEmbedder
    from coa_common.opensearch.client import AossVectorClient

    # Serve's embedding model. The index MUST use the same one serve uses for questions.
    serve_config = json.loads(ssm.get_parameter(Name=f"{_env('SSM_PREFIX')}/config")["Parameter"]["Value"])
    model_id = serve_config.get("bedrockEmbedModelId") or ""
    embedder = BedrockEmbedder(
        model_id=model_id or None, region=region, max_workers=int(_env("EMBED_MAX_WORKERS", "16"))
    )
    aoss = AossVectorClient(endpoint=_env("OSS_ENDPOINT"), region=region, dimensions=embedder.dimensions)
    collection = _env("OSS_COLLECTION_NAME")
    version = int(time.time())
    index = versioned_index_name(collection, namespace, version)
    # Write a NEW version, then its name list, then move the pointer. Serve keeps
    # searching the previous version until the new one is complete.
    written = write_index(
        docs, embedder=embedder, aoss=aoss, index=index, namespace=namespace, embed_model_id=model_id, recreate=False
    )
    s3 = boto3.client("s3", region_name=region)
    bucket = _env("ENTITY_BUCKET")
    key = f"entities/{namespace}/v{version}.json"
    s3.put_object(Bucket=bucket, Key=key, Body=json.dumps(name_catalog(docs)).encode(), ContentType="application/json")
    previous = read_pointer(ssm, _env("SSM_PREFIX"), namespace)
    write_pointer(
        ssm,
        _env("SSM_PREFIX"),
        namespace,
        ActivePointer(index=index, names_uri=f"s3://{bucket}/{key}", version=version),
    )

    # Delete the previous version and the old unversioned index. Errors are only logged.
    stale = [index_name(collection, namespace)] + ([previous.index] if previous is not None else [])
    for idx in stale:
        try:
            aoss.delete_index(idx)
        except Exception as exc:
            logger.warning("entity_index_retire_failed", index=idx, error=str(exc)[:200])
    if previous is not None and previous.names_uri.startswith(f"s3://{bucket}/"):
        try:
            s3.delete_object(Bucket=bucket, Key=previous.names_uri.removeprefix(f"s3://{bucket}/"))
        except Exception as exc:
            logger.warning("entity_names_retire_failed", uri=previous.names_uri, error=str(exc)[:200])

    logger.info(
        "entity_index_built", namespace=namespace, index=index, documents=written, by_type=counts, missing=missing
    )
    return {"status": "built", "index": index, "documents": written, "by_type": counts, "missing_types": missing}


_STALE_AFTER_S = 2 * 3600  # a version not in use and younger than this may still be building


def sweep() -> dict[str, Any]:
    """Delete entity indexes (and pointers / name lists) that are no longer used.

    Removes every index of a deleted namespace, and any old version of a live
    namespace that is not the one in use and is more than two hours old (a
    failed or replaced build).
    """
    from coa_common.opensearch.client import AossVectorClient

    region = _region()
    collection = _env("OSS_COLLECTION_NAME")
    prefix = index_name(collection, "")
    aoss = AossVectorClient(endpoint=_env("OSS_ENDPOINT"), region=region)
    ssm = boto3.client("ssm", region_name=region)
    s3 = boto3.client("s3", region_name=region)
    bucket = _env("ENTITY_BUCKET")
    try:
        rows = aoss.raw_client().cat.indices(index=f"{prefix}*", format="json")
    except Exception as exc:
        if "index_not_found" in str(exc) or "404" in str(exc):
            rows = []
        else:
            raise
    namespaces = boto3.resource("dynamodb", region_name=region).Table(_env("NAMESPACES_TABLE"))
    exists: dict[str, bool] = {}
    active: dict[str, ActivePointer | None] = {}
    deleted: list[str] = []
    now = int(time.time())
    for row in rows or []:
        index = str(row.get("index") or "")
        parsed = parse_index_name(collection, index)
        if parsed is None:
            continue
        namespace, version = parsed
        if namespace not in exists:
            exists[namespace] = bool(namespaces.get_item(Key={"PK": f"NS#{namespace}", "SK": "METADATA"}).get("Item"))
            active[namespace] = read_pointer(ssm, _env("SSM_PREFIX"), namespace) if exists[namespace] else None
        pointer = active[namespace]
        if not exists[namespace]:
            stale = True  # its namespace was deleted
        elif pointer is not None and index == pointer.index:
            stale = False  # the version in use
        elif version is None:
            stale = pointer is not None  # old unversioned index, replaced by a versioned one
        else:
            stale = now - version > _STALE_AFTER_S and (pointer is None or version < pointer.version)
        if stale and aoss.delete_index(index):
            deleted.append(index)
    for namespace, alive in exists.items():
        if not alive:  # a deleted namespace: drop its pointer and name lists too
            delete_pointer(ssm, _env("SSM_PREFIX"), namespace)
            if bucket:
                for obj in s3.list_objects_v2(Bucket=bucket, Prefix=f"entities/{namespace}/").get("Contents", []):
                    s3.delete_object(Bucket=bucket, Key=obj["Key"])
    logger.info("entity_index_sweep", checked=len(rows or []), deleted=deleted)
    return {"status": "swept", "deleted": deleted}


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """Handle an EventBridge event or a manual ``{"action": ...}`` call."""
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
