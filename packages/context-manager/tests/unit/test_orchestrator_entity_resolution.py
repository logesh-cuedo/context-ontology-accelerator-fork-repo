# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Orchestrator wiring of the Tier-2 entity-resolution step."""

from __future__ import annotations

from unittest.mock import AsyncMock

import pytest
from coa_serve.models import InvokeRequest
from coa_serve.step_ids import StepId
from coa_serve.tier2.entity_resolution import CLARIFICATION_MARKER, EntityCandidate, EntityResolution

from .test_orchestrator import _find_step, _make_orchestrator

BAJAJ_AUTO = EntityCandidate(kind="company", key="101", name="Bajaj Auto Ltd.", sector="Automobile")
CLARIFY = (
    "**bajaj** matches more than one entry. Which one did you mean?\n\n"
    "1. Bajaj Auto Ltd. (Automobile)\n2. Bajaj Finance Ltd. (Finance)\n\n" + CLARIFICATION_MARKER
)


def _with_resolver(resolution: EntityResolution):
    orch, parts = _make_orchestrator(tier2_success=True, tier2_ontop_assembly=False, return_parts=True)
    resolver = AsyncMock()
    resolver.resolve.return_value = resolution
    orch._entity_resolver = resolver
    return orch, parts, resolver


def _strategy_options(parts) -> dict:
    context = parts["strategy_resolve"].call_args.args[2]
    return context.options


@pytest.mark.asyncio
async def test_found_entities_reach_sql_generation_as_resolved_entities():
    orch, parts, _ = _with_resolver(EntityResolution(status="found", companies=[BAJAJ_AUTO]))

    response = await orch.resolve(InvokeRequest(query="latest pat of bajaj auto", namespace="demo"))

    assert response.result.tier == 2
    options = _strategy_options(parts)
    assert "Bajaj Auto Ltd." in options["resolvedEntities"]
    step = _find_step(response.result.trace, StepId.T2_ENTITY_RESOLVE)
    assert step is not None and step.detail["companies"] == ["Bajaj Auto Ltd."]


@pytest.mark.asyncio
@pytest.mark.parametrize("status", ["not_found", "ambiguous"])
async def test_unresolved_entity_asks_the_user_and_runs_no_query(status):
    orch, parts, _ = _with_resolver(EntityResolution(status=status, clarification=CLARIFY))

    response = await orch.resolve(InvokeRequest(query="latest pat of bajaj", namespace="demo"))

    assert response.result.synthesized_answer == CLARIFY
    assert response.result.metadata["clarification"] == {"kind": "entity", "status": status}
    parts["strategy_resolve"].assert_not_called()  # no SQL generated or executed
    parts["knowledge_retriever"].resolve.assert_not_called()  # and no Tier-3 fallback


@pytest.mark.asyncio
@pytest.mark.parametrize("status", ["no_entity", "skipped"])
async def test_no_entity_or_skipped_leaves_tier2_unchanged(status):
    orch, parts, _ = _with_resolver(EntityResolution(status=status))

    await orch.resolve(InvokeRequest(query="top 10 companies by revenue", namespace="demo"))

    assert "resolvedEntities" not in _strategy_options(parts)


@pytest.mark.asyncio
async def test_reply_to_a_clarification_reruns_the_original_question():
    orch, _, resolver = _with_resolver(EntityResolution(status="found", companies=[BAJAJ_AUTO]))
    request = InvokeRequest(query="1", namespace="demo")
    history = [
        {"role": "user", "content": "latest pat of bajaj"},
        {"role": "assistant", "content": CLARIFY},
    ]

    await orch.resolve(request, conversation_history=history)

    merged = "latest pat of bajaj\nUser clarification: Bajaj Auto Ltd. (Automobile)"
    assert resolver.resolve.call_args.args[0] == merged
    # persisted as this turn's question, so a further clarification keeps the root
    assert request.query == merged


@pytest.mark.asyncio
async def test_without_a_resolver_nothing_changes():
    orch, parts = _make_orchestrator(tier2_success=True, tier2_ontop_assembly=False, return_parts=True)
    request = InvokeRequest(query="1", namespace="demo")

    response = await orch.resolve(
        request, conversation_history=[{"role": "user", "content": "q"}, {"role": "assistant", "content": CLARIFY}]
    )

    assert request.query == "1"
    assert _find_step(response.result.trace, StepId.T2_ENTITY_RESOLVE) is None
