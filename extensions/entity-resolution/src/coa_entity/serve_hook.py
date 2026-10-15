# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""The single object serve's orchestrator talks to (see the ``cuedo-ext`` hooks).

    hook.resume(query, history)        → merged question when the user is answering
                                         a clarification, else None
    await hook.before_tier2(...)       → Tier2Outcome(clarification=..., sql_context=...)
    hook.clarification_response(...)   → the InvokeResponse that asks the user

Everything is fail-open: no entity config for the namespace, a malformed config,
an SSM error or a resolver failure leave Tier 2 exactly as upstream runs it.
"""

from __future__ import annotations

import asyncio
import os
import time
from dataclasses import dataclass
from typing import Any

import structlog

from .config import EntityConfig, EntityConfigError, load_config
from .resolver import EntityResolver, fallback_rules, resolved_block, resume_clarification

logger = structlog.get_logger(__name__)

STEP_ID = "t2.entity.resolve"
_CONFIG_TTL_S = 300.0


@dataclass(frozen=True)
class Tier2Outcome:
    """What the orchestrator does next: ask the user, or run Tier 2 with extra SQL context."""

    clarification: str = ""
    sql_context: str = ""


class EntityHook:
    """Entity resolution wired into serve: config lookup, resolve, trace, prompt context."""

    def __init__(self, resolver: EntityResolver, ssm_client: Any, ssm_prefix: str):
        """Wire the resolver and the SSM client the per-namespace config is read with."""
        self._resolver = resolver
        self._ssm = ssm_client
        self._ssm_prefix = ssm_prefix
        self._configs: dict[str, tuple[EntityConfig | None, float]] = {}

    def resume(self, query: str, history: list[dict[str, str]] | None) -> str | None:
        """The original question plus the user's answer, when this turn answers a clarification."""
        return resume_clarification(query, history)

    async def config_for(self, namespace: str) -> EntityConfig | None:
        """The namespace's entity config (cached for a few minutes); None → feature off."""
        cached = self._configs.get(namespace)
        if cached is not None and time.monotonic() - cached[1] < _CONFIG_TTL_S:
            return cached[0]
        try:
            config = await asyncio.to_thread(load_config, self._ssm, self._ssm_prefix, namespace)
        except EntityConfigError as exc:
            logger.warning("entity_config_invalid", namespace=namespace, error=str(exc)[:300])
            config = None
        except Exception as exc:
            # Transient SSM failure: do not cache, retry on the next request.
            logger.warning("entity_config_unavailable", namespace=namespace, error=str(exc)[:200])
            return None
        self._configs[namespace] = (config, time.monotonic())
        return config

    async def before_tier2(
        self,
        query: str,
        namespace: str,
        embedding: list[float] | None,
        trace: Any,
        model_id: str | None,
    ) -> Tier2Outcome:
        """Resolve the question's entities and record the trace step. Never raises."""
        config = await self.config_for(namespace)
        if config is None:
            return Tier2Outcome()
        start = time.perf_counter()
        resolution = await self._resolver.resolve(query, namespace, config, embedding=embedding, model_id=model_id)
        trace.record(
            STEP_ID,
            "skipped" if resolution.status == "skipped" else "success",
            int((time.perf_counter() - start) * 1000),
            detail={
                "status": resolution.status,
                "entities": resolution.by_kind(),
                **({"reason": resolution.reason} if resolution.reason else {}),
            },
            tool_used="opensearch",
        )
        if resolution.needs_clarification:
            return Tier2Outcome(clarification=resolution.clarification)
        return Tier2Outcome(sql_context=resolved_block(resolution, config) or fallback_rules(config))

    @staticmethod
    def clarification_response(text: str, trace: Any, metadata: dict) -> Any:
        """An InvokeResponse that asks the user instead of running a query."""
        from coa_serve.models import ConfidenceScore, InvokeResponse, QueryResult

        metadata = {**metadata, "clarification": {"kind": "entity"}}
        return InvokeResponse(
            result=QueryResult(
                tier=2,
                confidence=ConfidenceScore(score=0.0, rationale="Entity not resolved — asking the user"),
                synthesized_answer=text,
                trace=trace.steps,
                metadata=metadata,
            )
        )


def build_entity_hook(*, vector_client: Any, llm_client: Any, collection: str) -> EntityHook | None:
    """The hook serve wires in, or None when the feature is switched off.

    Off when ``SERVE_ENTITY_RESOLUTION=off``, or when there is no AOSS collection
    or ``SSM_PREFIX`` to read the entity config from.
    """
    ssm_prefix = os.environ.get("SSM_PREFIX", "")
    if not collection or not ssm_prefix or os.environ.get("SERVE_ENTITY_RESOLUTION", "on").lower() == "off":
        return None
    import boto3

    region = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION") or "us-east-1"
    return EntityHook(
        EntityResolver(vector_client, llm_client, collection),
        boto3.client("ssm", region_name=region),
        ssm_prefix,
    )
