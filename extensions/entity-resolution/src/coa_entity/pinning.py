# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Pin a governed metric's table into the NL→SQL schema context.

When Tier 1 matches a governed metric but declines it (the question adds a
filter such as a sector or a fiscal year), serve forwards the metric's SQL to
Tier 2 as authoritative. But Tier 2 picks its schema context by similarity
alone, so in a namespace with many look-alike tables the metric's own table can
be missing from what the SQL writer sees — it then "extends" the definition on a
different table. :func:`pin_tables` adds the metric's table(s) to the retrieved
classes when similarity missed them.

Called from serve's sql_generator through a guarded ``cuedo-ext`` hook.
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
    """Bare table names a metric's SQL reads (``FROM``/``JOIN``), qualifiers and quotes dropped."""
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
    """``hits`` with a class hit for every table in ``tables`` (pinned ones first).

    Each missing table is looked up by a similarity search on its own name and
    kept only on an exact table-name match, so nothing unrelated is added.
    Best-effort: a lookup failure leaves ``hits`` unchanged.
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
