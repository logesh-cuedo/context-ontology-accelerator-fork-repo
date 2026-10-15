# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Build a namespace's entity index from the tables named in its EntityConfig.

For every configured entity type: read (id, name, describe/group columns) through
Athena, write one document per entity, plus one document per distinct value of
each group column. Documents are embedded with the SAME Bedrock model serve uses
for queries and written to ``{collection}-entities-{namespace}``.

Document fields (read back by :mod:`coa_entity.resolver`):
    entity_type   the configured type (e.g. ``company``, ``sector``)
    entity_uri    the entity's id (groups: the value itself)
    text          the embedded text
    context_text  JSON ``{"name": ..., "attrs": {column: value}}``
"""

from __future__ import annotations

import json
import re
import time
from collections.abc import Callable
from typing import Any

from .config import EntityConfig, EntityTypeSpec

BULK_CHUNK = 200
_ATHENA_POLL_S = 1.0
# AOSS deletes an index asynchronously: a same-name index created right after
# can still route writes to the old one ("index_not_found ... no such index
# [<internal id>]"). Wait for the delete to land, then let routing settle.
_DELETE_WAIT_S = 90.0
_DELETE_POLL_S = 3.0
_ROUTING_SETTLE_S = 10.0

# Words that carry no identity in an acronym ("Tata Consultancy Services Ltd." → TCS).
_ACRONYM_SKIP = {
    "the",
    "of",
    "and",
    "&",
    "-",
    "ltd",
    "ltd.",
    "limited",
    "pvt",
    "pvt.",
    "private",
    "inc",
    "inc.",
    "co",
    "co.",
    "corp",
    "corp.",
    "corporation",
}


def index_name(collection: str, namespace: str) -> str:
    """``{collection}-entities-{namespace}`` — one entity index per namespace."""
    return f"{collection}-entities-{namespace}"


def acronyms(name: str) -> list[str]:
    """Initials of a name's significant words: 'Tata Consultancy Services Ltd.' → ['TCS']."""
    words = [w for w in re.split(r"[\s/]+", name) if w and w.lower().strip(".,()") not in _ACRONYM_SKIP]
    if len(words) < 2:
        return []
    initials = "".join(w[0] for w in words if w[0].isalnum()).upper()
    return [initials] if len(initials) >= 2 else []


def read_rows(athena: Any, *, database: str, spec: EntityTypeSpec, workgroup: str) -> list[dict[str, str]]:
    """SELECT the spec's columns through Athena; one dict per distinct id (first row wins)."""
    selected = ", ".join(f'CAST("{c}" AS VARCHAR) AS "{c}"' for c in spec.columns)
    sql = f'SELECT DISTINCT {selected} FROM "{database}"."{spec.table}" WHERE "{spec.name_column}" IS NOT NULL'
    qid = athena.start_query_execution(QueryString=sql, WorkGroup=workgroup)["QueryExecutionId"]
    while True:
        state = athena.get_query_execution(QueryExecutionId=qid)["QueryExecution"]["Status"]
        if state["State"] in ("SUCCEEDED", "FAILED", "CANCELLED"):
            break
        time.sleep(_ATHENA_POLL_S)
    if state["State"] != "SUCCEEDED":
        raise RuntimeError(f"Athena query {state['State']}: {state.get('StateChangeReason', '')}")

    rows: list[dict[str, str]] = []
    header: list[str] | None = None
    for page in athena.get_paginator("get_query_results").paginate(QueryExecutionId=qid):
        for raw in page["ResultSet"]["Rows"]:
            values = [cell.get("VarCharValue", "") or "" for cell in raw["Data"]]
            if header is None:
                header = values
                continue
            rows.append(dict(zip(header, (v.strip() for v in values), strict=False)))
    by_id: dict[str, dict[str, str]] = {}
    for row in rows:
        if row.get(spec.id_column) and row.get(spec.name_column):
            by_id.setdefault(row[spec.id_column], row)
    return list(by_id.values())


def _doc(kind: str, uri: str, text: str, name: str, attrs: dict[str, str]) -> tuple[str, dict]:
    return (
        text,
        {
            "entity_type": kind,
            "entity_uri": uri,
            "text": text,
            "context_text": json.dumps({"name": name, "attrs": attrs}),
        },
    )


def build_documents(spec: EntityTypeSpec, rows: list[dict[str, str]]) -> list[tuple[str, dict]]:
    """(embedding text, AOSS document without vector) for each entity and group value."""
    docs: list[tuple[str, dict]] = []
    attr_columns = [c for c in spec.columns if c not in (spec.id_column, spec.name_column)]
    children: dict[str, dict[str, set[str]]] = {g.type: {} for g in spec.groups}
    for row in rows:
        name = row[spec.name_column]
        attrs = {c: row[c] for c in attr_columns if row.get(c)}
        parts = [name]
        short = acronyms(name) if spec.acronyms else []
        if short:
            parts.append(f"({', '.join(short)})")
        if attrs:
            parts.append("— " + "; ".join(f"{c}: {v}" for c, v in attrs.items()))
        docs.append(_doc(spec.type, row[spec.id_column], " ".join(parts), name, attrs))
        for g in spec.groups:
            value = row.get(g.column, "")
            if value:
                bucket = children[g.type].setdefault(value, set())
                if g.child_column and row.get(g.child_column):
                    bucket.add(row[g.child_column])
    for g in spec.groups:
        for value, subs in sorted(children[g.type].items()):
            text = f"{value} ({g.type})"
            if subs:
                text += f" — {g.child_column}: {', '.join(sorted(subs))}"
            docs.append(_doc(g.type, value, text, value, {}))
    return docs


def _wait_until_deleted(aoss: Any, index: str) -> None:
    """Block until ``index`` no longer exists (bounded), then let AOSS routing settle."""
    deadline = time.monotonic() + _DELETE_WAIT_S
    while time.monotonic() < deadline:
        try:
            if not aoss.raw_client().indices.exists(index=index):
                break
        except Exception:  # a transient probe error is not worth failing the build
            break
        time.sleep(_DELETE_POLL_S)
    time.sleep(_ROUTING_SETTLE_S)


def _bulk(aoss: Any, index: str, docs: list[dict]) -> None:
    """Bulk-write, retrying once if AOSS still routes to a just-deleted index."""
    try:
        aoss.bulk_index(index, docs)
    except Exception as exc:
        if "index_not_found" not in str(exc):
            raise
        time.sleep(_ROUTING_SETTLE_S * 3)
        aoss.ensure_index(index)
        aoss.bulk_index(index, docs)


def write_index(
    docs: list[tuple[str, dict]],
    *,
    embedder: Any,
    aoss: Any,
    index: str,
    namespace: str,
    embed_model_id: str,
    recreate: bool = True,
    progress: Callable[[str], None] | None = None,
) -> int:
    """Embed ``docs`` and (re)build ``index``. Returns the number of documents written.

    ``recreate`` drops the index first so renamed or removed entities disappear.
    """
    say = progress or (lambda _msg: None)
    if recreate and aoss.delete_index(index):
        say(f"dropped existing {index}")
        _wait_until_deleted(aoss, index)
    aoss.ensure_index(index)

    written = 0
    for start in range(0, len(docs), BULK_CHUNK):
        chunk = docs[start : start + BULK_CHUNK]
        vectors = embedder.embed_documents([text for text, _ in chunk])
        _bulk(
            aoss,
            index,
            [
                {
                    **doc,
                    "embedding": vec,
                    "namespace": namespace,
                    "model_id": embed_model_id,
                    "embedding_type": "entity",
                }
                for (_, doc), vec in zip(chunk, vectors, strict=True)
            ],
        )
        written += len(chunk)
        say(f"indexed {written}/{len(docs)}")
    return written


def build_all_documents(
    config: EntityConfig, read: Callable[[EntityTypeSpec], list[dict[str, str]]]
) -> tuple[list[tuple[str, dict]], dict[str, int]]:
    """Documents for every configured entity type; ``read`` supplies each type's rows.

    Returns (documents, {entity_type: document count}).
    """
    docs: list[tuple[str, dict]] = []
    counts: dict[str, int] = {}
    for spec in config.entity_types:
        spec_docs = build_documents(spec, read(spec))
        docs += spec_docs
        for _, d in spec_docs:
            counts[d["entity_type"]] = counts.get(d["entity_type"], 0) + 1
    return docs, counts
