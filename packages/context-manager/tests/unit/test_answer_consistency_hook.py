# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""cuedo-ext: the NL->SQL strategy side of extensions/answer-consistency.

The strategy reads ``options["_consistency"]`` (set by the orchestrator hook):
rules join the prompt, ``top_p`` reaches the SQL writer, a cached SQL skips
generation (firewall + execution still run), and a fresh SQL with rows is saved.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from unittest.mock import AsyncMock, MagicMock

import pytest
from coa_serve.tier2.nl_to_sql.strategy import NLtoSQLStrategy
from coa_serve.tier2.strategy import StrategyContext
from coa_serve.trace import TraceCollector

from .test_nl_to_sql_strategy import _make_exec_result, _make_firewall_result, _make_nl_to_sql_result


@dataclass
class FakeConsistency:
    rules: str = "## Rules\n- previous quarter"
    top_p: float | None = 0.0
    cached: dict | None = None
    saved: list = field(default_factory=list)

    def save(self, entry):
        self.saved.append(entry)


def _setup(consistency, row_count=1):
    gen, fw, ex = AsyncMock(), MagicMock(), AsyncMock()
    gen.generate.return_value = _make_nl_to_sql_result(sql="SELECT 1")
    fw.evaluate.return_value = _make_firewall_result(authorized_sql="SELECT 1")
    ex.execute.return_value = _make_exec_result(row_count=row_count)
    strategy = NLtoSQLStrategy(sql_generator=gen, firewall=fw, query_executor=ex, oss_ontology_index="idx")
    options = {"maxResults": 100, "resolvedEntities": "## Entities"}
    if consistency is not None:
        options["_consistency"] = consistency
    context = StrategyContext(embedding=[0.1], profile={"userId": "u"}, options=options, trace=TraceCollector())
    return strategy, gen, ex, context


@pytest.mark.unit
@pytest.mark.asyncio
async def test_without_consistency_nothing_changes():
    strategy, gen, _, context = _setup(None)
    await strategy.resolve("q", "ns", context)
    kwargs = gen.generate.call_args.kwargs
    assert kwargs["entities"] == "## Entities" and kwargs["top_p"] is None


@pytest.mark.unit
@pytest.mark.asyncio
async def test_rules_and_top_p_reach_the_writer_and_rows_are_saved():
    ext = FakeConsistency()
    strategy, gen, _, context = _setup(ext)
    result = await strategy.resolve("q", "ns", context)
    kwargs = gen.generate.call_args.kwargs
    assert kwargs["entities"].startswith("## Rules") and "## Entities" in kwargs["entities"]
    assert kwargs["top_p"] == 0.0
    assert result.sql == "SELECT 1" and ext.saved[0]["sql"] == "SELECT 1"
    assert ext.saved[0]["data_source_id"] == "ds-1"


@pytest.mark.unit
@pytest.mark.asyncio
async def test_cached_sql_skips_generation_but_still_executes():
    cached = {"sql": "SELECT 1", "confidence": 0.9, "data_source_id": "ds-1", "retrieved_tables": ["orders"]}
    ext = FakeConsistency(cached=cached)
    strategy, gen, ex, context = _setup(ext)
    result = await strategy.resolve("q", "ns", context)
    gen.generate.assert_not_called()
    ex.execute.assert_awaited()
    assert result.sql == "SELECT 1" and result.confidence == 0.9 and result.data_source_id == "ds-1"


@pytest.mark.unit
@pytest.mark.asyncio
async def test_zero_rows_are_not_saved():
    ext = FakeConsistency()
    strategy, _, _, context = _setup(ext, row_count=0)
    await strategy.resolve("q", "ns", context)
    assert ext.saved == []
