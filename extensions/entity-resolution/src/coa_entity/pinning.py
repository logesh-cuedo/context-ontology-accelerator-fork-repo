# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Make sure a governed metric's own table is in the tables Tier 2 sees.

When Tier 1 finds a governed metric but does not answer (the question adds a
filter such as a sector or a fiscal year), serve passes the metric's SQL on to
Tier 2. Tier 2 picks its tables only by similarity, so when many tables look
alike, the metric's own table can be left out, and the SQL then uses a different
table. pin_tables() adds the metric's table(s) when the similarity search
missed them.

Called from serve's sql_generator through a ``cuedo-ext`` hook.
"""

from __future__ import annotations

import re
from collections.abc import Callable
from typing import Any

import structlog

logger = structlog.get_logger(__name__)

_TABLE_REF = re.compile(
    r'\b(?:from|join)\s+((?:"[^"]+"|[A-Za-z_][\w$]*)(?:\s*\.\s*(?:"[^"]+"|[A-Za-z_][\w$]*))*)', re.I
)


def metric_tables(sql: str) -> list[str]:
    """Table names a metric's SQL reads (after ``FROM`` / ``JOIN``), without database prefix or quotes."""
    out: list[str] = []
    for ref in _TABLE_REF.findall(sql or ""):
        name = ref.split(".")[-1].strip().strip('"')
        if name and name.lower() not in {"select", "lateral", "unnest"} and name not in out:
            out.append(name)
    return out


async def pin_tables(
    hits: list[Any],
    tables: list[str],
    *,
    vector: Any,
    llm: Any,
    table_of: Callable[[str], str | None],
    namespace: str,
    index: str,
    require_mapped: bool,
) -> list[Any]:
    """``hits`` plus a hit for every table in ``tables`` (those first).

    Each missing table is found by a search on its own name, and kept only if
    the table name matches exactly, so nothing unrelated is added. If the search
    fails, ``hits`` is returned unchanged.
    """
    have = {(table_of(getattr(h, "text", "")) or "").lower() for h in hits}
    pinned: list[Any] = []
    for table in tables:
        if table.lower() in have:
            continue
        try:
            emb = await llm.embed(f"Table: {table}")
            found = await vector.search(
                emb, namespace=namespace, top_k=5, index=index, entity_type="class", require_mapped=require_mapped
            )
        except Exception as exc:
            logger.warning("metric_table_pin_failed", table=table, error=str(exc)[:200])
            continue
        match = next((h for h in found if (table_of(getattr(h, "text", "")) or "").lower() == table.lower()), None)
        if match is not None:
            pinned.append(match)
            have.add(table.lower())
    if pinned:
        logger.info("metric_table_pinned", namespace=namespace, tables=[table_of(h.text) for h in pinned])
    return [*pinned, *hits]
