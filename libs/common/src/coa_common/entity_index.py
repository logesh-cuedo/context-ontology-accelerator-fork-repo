# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Build a namespace's company/sector entity index for Tier-2 entity resolution.

Reads every company (id, name, sector, subsector) from a sectors table through
Athena, embeds one document per company and one per sector with the SAME Bedrock
embedding model serve uses for queries, and writes them to the namespace's entity
index (``{collection}-entities-{namespace}``). Serve's EntityResolver runs a
similarity search over that index for every Tier-2 question.

Shared by two callers:
  - ``packages/context-manager/scripts/index_entities.py`` (manual CLI run)
  - the entity-index Lambda (``packages/context-manager/lambda/entity-index``),
    which rebuilds the index on every ``ontology.published`` event.
"""

from __future__ import annotations

import json
import re
import time
from collections.abc import Callable
from typing import Any

BULK_CHUNK = 200
_ATHENA_POLL_S = 1.0

DEFAULT_COLUMNS = {
    "id": "company_id",
    "name": "company_name",
    "sector": "cd_sector",
    "subsector": "cd_subsector",
}

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


def acronyms(name: str) -> list[str]:
    """Initials of a company name's significant words: 'Tata Consultancy Services Ltd.' → ['TCS']."""
    words = [w for w in re.split(r"[\s/]+", name) if w and w.lower().strip(".,()") not in _ACRONYM_SKIP]
    if len(words) < 2:
        return []
    initials = "".join(w[0] for w in words if w[0].isalnum()).upper()
    return [initials] if len(initials) >= 2 else []


def company_document(row: dict[str, str]) -> str:
    """Text embedded for one company — name, acronym, and where it sits in the market."""
    parts = [row["company_name"]]
    short = acronyms(row["company_name"])
    if short:
        parts.append(f"({', '.join(short)})")
    if row.get("cd_sector"):
        parts.append(f"— sector: {row['cd_sector']}")
    if row.get("cd_subsector"):
        parts.append(f"; subsector: {row['cd_subsector']}")
    return " ".join(parts)


def sector_document(sector: str, subsectors: list[str]) -> str:
    """Text embedded for one sector — its name plus the subsectors it groups."""
    if subsectors:
        return f"{sector} sector — subsectors: {', '.join(subsectors)}"
    return f"{sector} sector"


def read_sectors_table(
    athena: Any, *, database: str, table: str, workgroup: str, columns: dict[str, str]
) -> list[dict[str, str]]:
    """SELECT the company/sector columns through Athena and return one dict per company."""
    sql = (
        f'SELECT DISTINCT CAST("{columns["id"]}" AS VARCHAR) AS company_id, "{columns["name"]}" AS company_name, '
        f'"{columns["sector"]}" AS cd_sector, "{columns["subsector"]}" AS cd_subsector '
        f'FROM "{database}"."{table}" WHERE "{columns["name"]}" IS NOT NULL'
    )
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
    # One row per company_id (a company listed twice keeps its first sector).
    by_id: dict[str, dict[str, str]] = {}
    for row in rows:
        if row.get("company_id") and row.get("company_name"):
            by_id.setdefault(row["company_id"], row)
    return list(by_id.values())


def build_documents(companies: list[dict[str, str]]) -> list[tuple[str, dict]]:
    """(embedding text, AOSS document without the vector) for every company and sector."""
    docs: list[tuple[str, dict]] = []
    subsectors: dict[str, set[str]] = {}
    for c in companies:
        text = company_document(c)
        docs.append(
            (
                text,
                {
                    "entity_type": "company",
                    "entity_uri": c["company_id"],
                    "text": text,
                    "context_text": json.dumps(
                        {
                            "company_name": c["company_name"],
                            "cd_sector": c.get("cd_sector", ""),
                            "cd_subsector": c.get("cd_subsector", ""),
                        }
                    ),
                },
            )
        )
        if c.get("cd_sector"):
            bucket = subsectors.setdefault(c["cd_sector"], set())
            if c.get("cd_subsector"):
                bucket.add(c["cd_subsector"])
    for sector, subs in sorted(subsectors.items()):
        text = sector_document(sector, sorted(subs))
        docs.append(
            (
                text,
                {
                    "entity_type": "sector",
                    "entity_uri": sector,
                    "text": text,
                    "context_text": json.dumps({"cd_sector": sector, "subsectors": sorted(subs)}),
                },
            )
        )
    return docs


def write_entity_index(
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
    """Embed ``docs`` and (re)build ``index`` from them. Returns the documents written.

    ``recreate`` drops the index first so renamed or removed companies disappear.
    """
    say = progress or (lambda _msg: None)
    if recreate and aoss.delete_index(index):
        say(f"dropped existing {index}")
    aoss.ensure_index(index)

    written = 0
    for start in range(0, len(docs), BULK_CHUNK):
        chunk = docs[start : start + BULK_CHUNK]
        vectors = embedder.embed_documents([text for text, _ in chunk])
        aoss.bulk_index(
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
