# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""The serve hook, and the orchestrator hook points that call it (upstream coa_serve)."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock

import pytest

from coa_entity.resolver import CLARIFICATION_MARKER, EntityCandidate, EntityResolution
from coa_entity.serve_hook import STEP_ID, EntityHook, build_entity_hook

from .helpers import sample_document

coa_serve = pytest.importorskip("coa_serve")
from coa_serve.models import InvokeRequest  # noqa: E402
from coa_serve.trace import TraceCollector  # noqa: E402

# Upstream's own orchestrator test factory, loaded by path (it lives in a
# different tests package).
_ORCH_TESTS = Path(__file__).resolve().parents[3] / "packages/context-manager/tests/unit/test_orchestrator.py"
_spec = importlib.util.spec_from_file_location("upstream_test_orchestrator", _ORCH_TESTS)
assert _spec is not None and _spec.loader is not None
_upstream = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_upstream)

BAJAJ_AUTO = EntityCandidate(kind="company", key="101", name="Bajaj Auto Ltd.", attrs=(("cd_sector", "Automobile"),))
CLARIFY = f"Which?\n\n1. Bajaj Auto Ltd. (Automobile)\n2. Bajaj Finance Ltd. (Finance)\n\n{CLARIFICATION_MARKER}"


def _ssm(config: dict | None) -> MagicMock:
    ssm = MagicMock()
    ssm.exceptions.ParameterNotFound = type("ParameterNotFound", (Exception,), {})

    def get_parameter(Name):  # noqa: N803
        if config is None or not Name.endswith("/default"):
            raise ssm.exceptions.ParameterNotFound()
        return {"Parameter": {"Value": json.dumps(config)}}

    ssm.get_parameter.side_effect = get_parameter
    return ssm


def _hook(resolution: EntityResolution, config: dict | None = None) -> tuple[EntityHook, AsyncMock]:
    resolver = AsyncMock()
    resolver.resolve.return_value = resolution
    return EntityHook(resolver, _ssm(sample_document() if config is None else config), "/cuedo"), resolver


@pytest.mark.unit
class TestEntityHook:
    async def test_found_gives_resolved_block_and_records_step(self):
        hook, _ = _hook(EntityResolution(status="found", chosen=[BAJAJ_AUTO]))
        trace = TraceCollector()
        out = await hook.before_tier2("bajaj auto pat", "ns1", [0.1], trace, None)
        assert "Resolved entities" in out.sql_context and "Bajaj Auto Ltd." in out.sql_context
        step = next(s for s in trace.steps if s.step == STEP_ID)
        assert step.detail == {"status": "found", "entities": {"company": ["Bajaj Auto Ltd."]}}

    async def test_no_entity_still_gets_fallback_rules(self):
        hook, _ = _hook(EntityResolution(status="no_entity"))
        out = await hook.before_tier2("top 10 by pat", "ns1", [0.1], TraceCollector(), None)
        assert "Entity name filters" in out.sql_context

    async def test_without_config_the_step_is_absent(self):
        hook, resolver = _hook(EntityResolution(status="found"), config={})
        hook._ssm = _ssm(None)
        trace = TraceCollector()
        out = await hook.before_tier2("q", "ns1", [0.1], trace, None)
        assert out.sql_context == "" and out.clarification == ""
        resolver.resolve.assert_not_called()
        assert not trace.steps

    def test_switched_off(self, monkeypatch):
        monkeypatch.setenv("SSM_PREFIX", "/cuedo")
        monkeypatch.setenv("SERVE_ENTITY_RESOLUTION", "off")
        assert build_entity_hook(vector_client=None, llm_client=None, collection="c") is None


def _orchestrator(resolution: EntityResolution):
    orch, parts = _upstream._make_orchestrator(tier2_success=True, tier2_ontop_assembly=False, return_parts=True)
    hook, resolver = _hook(resolution)
    orch._entity_hook = hook
    return orch, parts, resolver


def _strategy_options(parts) -> dict:
    return parts["strategy_resolve"].call_args.args[2].options


@pytest.mark.unit
class TestOrchestratorHookPoints:
    async def test_found_entities_reach_sql_generation(self):
        orch, parts, _ = _orchestrator(EntityResolution(status="found", chosen=[BAJAJ_AUTO]))
        response = await orch.resolve(InvokeRequest(query="latest pat of bajaj auto", namespace="demo"))
        assert response.result.tier == 2
        assert "Bajaj Auto Ltd." in _strategy_options(parts)["resolvedEntities"]

    @pytest.mark.parametrize("status", ["not_found", "ambiguous"])
    async def test_unresolved_entity_asks_and_runs_no_query(self, status):
        orch, parts, _ = _orchestrator(EntityResolution(status=status, clarification=CLARIFY))
        response = await orch.resolve(InvokeRequest(query="latest pat of bajaj", namespace="demo"))
        assert response.result.synthesized_answer == CLARIFY
        assert response.result.metadata["clarification"] == {"kind": "entity"}
        parts["strategy_resolve"].assert_not_called()
        parts["knowledge_retriever"].resolve.assert_not_called()

    async def test_reply_reruns_the_original_question(self):
        orch, _, resolver = _orchestrator(EntityResolution(status="found", chosen=[BAJAJ_AUTO]))
        request = InvokeRequest(query="1", namespace="demo")
        history = [{"role": "user", "content": "latest pat of bajaj"}, {"role": "assistant", "content": CLARIFY}]
        await orch.resolve(request, conversation_history=history)
        merged = "latest pat of bajaj\nUser clarification: Bajaj Auto Ltd. (Automobile)"
        assert resolver.resolve.call_args.args[0] == merged
        assert request.query == merged

    async def test_without_the_hook_upstream_is_unchanged(self):
        orch, parts = _upstream._make_orchestrator(tier2_success=True, tier2_ontop_assembly=False, return_parts=True)
        request = InvokeRequest(query="1", namespace="demo")
        response = await orch.resolve(
            request, conversation_history=[{"role": "user", "content": "q"}, {"role": "assistant", "content": CLARIFY}]
        )
        assert request.query == "1"
        assert "resolvedEntities" not in _strategy_options(parts)
        assert all(s.step != STEP_ID for s in response.result.trace)
