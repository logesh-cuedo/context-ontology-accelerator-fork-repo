# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Build a namespace's entity index from the tables named in its EntityConfig.

For every configured entity type: read the id, name and extra columns through
Athena, and make one document per entity plus one per distinct group value
(e.g. per sector). Each document gets a vector from the SAME Bedrock embedding
model serve uses for questions, and is saved to ``{collection}-entities-{namespace}``.

Document fields (read back by resolver.py):
    entity_type   the configured type (e.g. ``company``, ``sector``)
    entity_uri    the entity's id (groups: the value itself)
    text          the text the vector is made from
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
# OpenSearch deletes an index in the background: a new index with the same name,
# created right after, can still send writes to the old one ("index_not_found ...
# no such index [<internal id>]"). So wait for the delete, then wait a little more.
_DELETE_WAIT_S = 90.0
_DELETE_POLL_S = 3.0
_ROUTING_SETTLE_S = 10.0

# Words left out of a short form ("Tata Consultancy Services Ltd." is TCS, not TCSL).
_ACRONYM_SKIP = {
    "the", "of", "and", "&", "-", "ltd", "ltd.", "limited", "pvt", "pvt.", "private",
    "inc", "inc.", "co", "co.", "corp", "corp.", "corporation",
}  # fmt: skip
_BULK_ATTEMPTS = 4


def index_name(collection: str, namespace: str) -> str:
    """``{collection}-entities-{namespace}``: the old index name, without a version."""
    return f"{collection}-entities-{namespace}"


def versioned_index_name(collection: str, namespace: str, version: int) -> str:
    """``{collection}-entities-{namespace}-v{version}``: one build of the index.

    Each build writes a NEW version, and the pointer moves to it only when it is
    complete, so serve never searches a half-built index.
    """
    return f"{index_name(collection, namespace)}-v{version}"


_VERSION = re.compile(r"^(?P<ns>.+?)(?:-v(?P<v>\d+))?$")


def parse_index_name(collection: str, index: str) -> tuple[str, int | None] | None:
    """(namespace, version or None) for an entity index name, or None if it is not one."""
    prefix = index_name(collection, "")
    if not index.startswith(prefix):
        return None
    m = _VERSION.match(index[len(prefix) :])
    if not m or not m.group("ns"):
        return None
    return m.group("ns"), int(m.group("v")) if m.group("v") else None


def name_catalog(docs: list[tuple[str, dict]]) -> dict:
    """The short name list serve loads for name matching: [kind, key, name, attrs] per entity."""
    entities = []
    for _, d in docs:
        ctx = json.loads(d.get("context_text") or "{}")
        entities.append([d["entity_type"], d["entity_uri"], ctx.get("name") or d["entity_uri"], ctx.get("attrs") or {}])
    return {"version": 1, "entities": entities}


def acronyms(name: str) -> list[str]:
    """Short form from the first letters: 'Tata Consultancy Services Ltd.' gives ['TCS']."""
    words = [w for w in re.split(r"[\s/]+", name) if w and w.lower().strip(".,()") not in _ACRONYM_SKIP]
    if len(words) < 2:
        return []
    initials = "".join(w[0] for w in words if w[0].isalnum()).upper()
    return [initials] if len(initials) >= 2 else []


def read_rows(athena: Any, *, database: str, spec: EntityTypeSpec, workgroup: str) -> list[dict[str, str]]:
    """Read the spec's columns through Athena. One dict per id (the first row is kept)."""
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

    header: list[str] | None = None
    by_id: dict[str, dict[str, str]] = {}
    for page in athena.get_paginator("get_query_results").paginate(QueryExecutionId=qid):
        for raw in page["ResultSet"]["Rows"]:
            values = [(cell.get("VarCharValue", "") or "").strip() for cell in raw["Data"]]
            if header is None:  # the first row is the column names
                header = values
                continue
            row = dict(zip(header, values, strict=False))
            if row.get(spec.id_column) and row.get(spec.name_column):
                by_id.setdefault(row[spec.id_column], row)  # first row per id wins
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
    """(text for the vector, OpenSearch document without the vector) for each entity and group value."""
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


def _wait_until(aoss: Any, index: str, *, exists: bool) -> None:
    """Wait (up to a limit) until ``index`` exists or is gone, then wait a little more.

    OpenSearch creates and deletes indexes in the background: a write sent right
    after an index is created can be rejected.
    """
    deadline = time.monotonic() + _DELETE_WAIT_S
    while time.monotonic() < deadline:
        try:
            if aoss.raw_client().indices.exists(index=index) == exists:
                break
        except Exception:  # if the check itself fails, carry on with the build
            break
        time.sleep(_DELETE_POLL_S)
    time.sleep(_ROUTING_SETTLE_S)


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
    """Make vectors for ``docs`` and save them to ``index``. Returns how many were written.

    ``recreate`` deletes the index first, so renamed or removed entities disappear.
    """
    say = progress or (lambda _msg: None)
    if recreate and aoss.delete_index(index):
        say(f"dropped existing {index}")
        _wait_until(aoss, index, exists=False)
    aoss.ensure_index(index)
    _wait_until(aoss, index, exists=True)

    written = 0
    for start in range(0, len(docs), BULK_CHUNK):
        chunk = docs[start : start + BULK_CHUNK]
        vectors = embedder.embed_documents([text for text, _ in chunk])
        pending = [
            {**doc, "embedding": vec, "namespace": namespace, "model_id": embed_model_id, "embedding_type": "entity"}
            for (_, doc), vec in zip(chunk, vectors, strict=True)
        ]
        # Write in bulk. If some are rejected, wait and send only those again.
        # OpenSearch makes its own ids, so sending the whole chunk again would
        # save the accepted documents twice.
        for attempt in range(_BULK_ATTEMPTS):
            try:
                aoss.bulk_index(index, pending)
                break
            except Exception as exc:
                rejected = [
                    {k: v for k, v in result["data"].items() if k not in ("_op_type", "_index")}
                    for item in getattr(exc, "errors", None) or []
                    for result in item.values()
                    if isinstance(result.get("data"), dict)
                ]
                index_missing = "index_not_found" in str(exc)
                partly_written = type(exc).__name__ == "PartialIndexError" and bool(rejected)
                if attempt == _BULK_ATTEMPTS - 1 or not (index_missing or partly_written):
                    raise
                time.sleep(_ROUTING_SETTLE_S * (attempt + 1))
                aoss.ensure_index(index)
                pending = rejected or pending
        written += len(chunk)
        say(f"indexed {written}/{len(docs)}")
    return written


def build_all_documents(
    config: EntityConfig, read: Callable[[EntityTypeSpec], list[dict[str, str]]]
) -> tuple[list[tuple[str, dict]], dict[str, int]]:
    """Documents for every configured entity type. ``read`` gives the rows of each type.

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
