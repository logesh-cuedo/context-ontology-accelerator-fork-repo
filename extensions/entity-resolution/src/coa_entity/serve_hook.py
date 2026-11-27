# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""The one object serve calls (see the ``cuedo-ext`` hooks in serve).

    hook.resume(query, history)       the question plus the user's answer, when the
                                      user is answering our question; else None
    await hook.before_tier2(...)      Tier2Outcome(clarification=..., sql_context=...)
    hook.clarification_response(...)  the response that asks the user to choose

before_tier2 is the only async method: it runs ``run`` in a worker thread, and
everything under ``run`` is plain code, so a debugger steps through it in order.

Which index to search, and the name list for name matching, come from the
pointer the index build saves (active.py). If anything is missing or fails
(no config, a bad config, an SSM or S3 error), Tier 2 simply runs as normal.
"""

from __future__ import annotations

import asyncio
import json
import os
import time
from dataclasses import dataclass
from typing import Any

import structlog

from .active import ActivePointer, read_pointer
from .clients import Clients
from .config import EntityConfig, EntityConfigError, load_config
from .index_builder import index_name
from .lexical import matcher_from_catalog
from .resolver import fallback_rules, resolve_entities, resolved_block, resume_clarification
from .time_period import carried_period, split_periods, time_block

logger = structlog.get_logger(__name__)

STEP_ID = "t2.entity.resolve"
TIME_STEP_ID = "t2.time.resolve"
_CONFIG_TTL_S = 300.0
_POINTER_TTL_S = 60.0


def _follow_up_block(history: list[dict[str, str]] | None) -> str:
    """What the previous turn asked and answered, for a question that continues it.

    Tier 2 is given the question alone. A follow-up is written as the remainder of a
    sentence — "and its roce?", "same for FY24" — so on its own it reads as a thin or
    partial request, and the writer filled the gap from the only thing it could see:
    it reproduced the previous answer, or answered both at once. Naming the previous
    question and the columns it returned says which part is already done, so the
    answer is the part that is not.

    Only what is needed to draw that line: the question's words and its column
    headings, not its rows.
    """
    asked = [t for t in (history or []) if t.get("role") == "user"]
    answered = [t for t in (history or []) if t.get("role") == "assistant"]
    previous = str(asked[-1].get("content") or "").strip() if asked else ""
    columns = answered[-1].get("answered_columns") if answered else None
    if not previous:
        return ""
    lines = [
        "## This question continues the previous one",
        f'The previous question was: "{previous[:300]}"',
    ]
    if isinstance(columns, list) and columns:
        lines.append(f"It was answered with these columns: {', '.join(str(c) for c in columns)}.")
    lines.append(
        "Answer only what THIS question asks. It is phrased as a continuation, which "
        "makes it read as the earlier question repeated — it is not. Carry over the "
        "entities and the period, and change the measure to the one asked for now. Do "
        "not return the previous answer again, and do not answer both unless this "
        "question asks to compare them."
    )
    return "\n".join(lines)


@dataclass(frozen=True)
class Tier2Outcome:
    """What serve does next: ask the user, or run Tier 2 with extra text in the SQL prompt."""

    clarification: str = ""
    sql_context: str = ""


class EntityHook:
    """Connects entity resolution to serve, and keeps small caches between requests."""

    def __init__(
        self, vector_client: Any, llm_client: Any, ssm_client: Any, s3_client: Any, ssm_prefix: str, collection: str
    ):
        """Keep the clients: search and Bedrock (from serve), SSM for the config, S3 for the name list."""
        self._clients = Clients(vector_client, llm_client)
        self._ssm = ssm_client
        self._s3 = s3_client
        self._ssm_prefix = ssm_prefix
        self._collection = collection
        self._configs: dict[str, tuple[EntityConfig | None, float]] = {}
        self._pointers: dict[str, tuple[ActivePointer | None, float]] = {}
        self._matchers: dict[str, dict] = {}  # key: the name list's S3 path (one per index version)

    def resume(self, query: str, history: list[dict[str, str]] | None) -> str | None:
        """The original question plus the user's answer, when this message answers our question."""
        return resume_clarification(query, history)

    async def before_tier2(
        self,
        query: str,
        namespace: str,
        embedding: list[float] | None,
        trace: Any,
        model_id: str | None,
        history: list[dict[str, str]] | None = None,
    ) -> Tier2Outcome:
        """Serve awaits this. The work is ``run``, a plain function, in a worker thread.

        The trace step is recorded here, back on serve's event loop: recording it
        sends it to the browser, which must not happen from another thread.
        """
        outcome, step = await asyncio.to_thread(self.run, query, namespace, embedding, model_id, history)
        if step is not None:
            trace.record(STEP_ID, step["status"], step["ms"], detail=step["detail"], tool_used="opensearch")
        return outcome

    def run(
        self,
        query: str,
        namespace: str,
        embedding: list[float] | None,
        model_id: str | None,
        history: list[dict[str, str]] | None = None,
    ) -> tuple[Tier2Outcome, dict | None]:
        """Find the question's companies / sectors. Never raises an error.

        Returns what serve does next, and the trace step to record (None when the
        feature is off for this namespace).

        Time periods (FY25, Q3 FY25, ...) are resolved here too when the config has a
        ``time`` block, and a follow-up that names none carries the previous question's.
        """
        config = self.config_for(namespace)
        if config is None or not config.entity_types:
            return Tier2Outcome(), None

        start = time.perf_counter()
        pointer = self.pointer_for(namespace)
        index = pointer.index if pointer else index_name(self._collection, namespace)  # no pointer: older index
        matcher = self.matcher_for(pointer, namespace)
        self._clients.last_reasoning = ""
        resolution = resolve_entities(
            self._clients,
            query,
            namespace,
            config,
            index=index,
            matcher=matcher,
            embedding=embedding,
            model_id=model_id,
            history=history,
        )
        detail: dict[str, Any] = {
            "status": resolution.status,
            "entities": resolution.by_kind(),
            **({"reason": resolution.reason} if resolution.reason else {}),
        }
        if os.environ.get("ENTITY_REASONING_EFFORT") and self._clients.last_reasoning:
            # Debugging only: the model's reasoning goes into the trace (ask.py prints it).
            detail["reasoning"] = self._clients.last_reasoning
        step = {
            "status": "skipped" if resolution.status == "skipped" else "success",
            "ms": int((time.perf_counter() - start) * 1000),
            "detail": detail,
        }
        if resolution.needs_clarification:
            return Tier2Outcome(clarification=resolution.clarification), step
        sections = [resolved_block(resolution, config) or fallback_rules(config)]
        if resolution.follows_up and (continues := _follow_up_block(history)):
            detail["follows_up"] = True
            sections.append(continues)
        # The period, worked out here rather than left to the SQL writer. It is given the
        # question alone, so "that year" has nothing to resolve against and it counts back
        # from TODAY instead — FY26 for a conversation about FY25. The dates are arithmetic
        # over the configured fiscal year-end, so computing them is exact where asking a
        # model to is not.
        # Fail open, like every other step here: the periods are an enrichment, and a
        # fault in them must not cost the caller the entity filters resolved above.
        try:
            if config.time is not None:
                periods, excluded = split_periods(query, config.time)
                if not periods and not excluded:
                    periods = carried_period(query, history, config.time)
                if periods or excluded:
                    # Into ``detail`` rather than through ``step``: it is the same dict,
                    # and the one the type checker can see is a dict.
                    detail["periods"] = [p.label for p in periods]
                    if excluded:
                        detail["excluded_periods"] = [p.label for p in excluded]
                    sections.append(time_block(periods, config.time, excluded))
        except Exception:
            logger.warning("time_period_failed", namespace=namespace, exc_info=True)
        return Tier2Outcome(sql_context="\n\n".join(s for s in sections if s)), step

    def config_for(self, namespace: str) -> EntityConfig | None:
        """The namespace's entity config, cached for 5 minutes. None means the feature is off."""
        cached = self._configs.get(namespace)
        if cached is not None and time.monotonic() - cached[1] < _CONFIG_TTL_S:
            return cached[0]
        try:
            config = load_config(self._ssm, self._ssm_prefix, namespace)
        except EntityConfigError as exc:
            logger.warning("entity_config_invalid", namespace=namespace, error=str(exc)[:300])
            config = None
        except Exception as exc:
            # SSM did not answer: do not cache, try again on the next request.
            logger.warning("entity_config_unavailable", namespace=namespace, error=str(exc)[:200])
            return None
        self._configs[namespace] = (config, time.monotonic())
        return config

    def pointer_for(self, namespace: str) -> ActivePointer | None:
        """Which index version to search. Cached for 1 minute; on an SSM error the last one is kept."""
        cached = self._pointers.get(namespace)
        if cached is not None and time.monotonic() - cached[1] < _POINTER_TTL_S:
            return cached[0]
        try:
            pointer = read_pointer(self._ssm, self._ssm_prefix, namespace)
        except Exception as exc:
            logger.warning("entity_pointer_unavailable", namespace=namespace, error=str(exc)[:200])
            pointer = cached[0] if cached else None
        self._pointers[namespace] = (pointer, time.monotonic())
        return pointer

    def matcher_for(self, pointer: ActivePointer | None, namespace: str) -> dict | None:
        """The name list for name matching, loaded from S3 once per index version. None if unavailable."""
        uri = pointer.names_uri if pointer else ""
        if not uri:
            return None
        if uri in self._matchers:
            return self._matchers[uri]
        try:
            bucket, _, key = uri.removeprefix("s3://").partition("/")
            matcher = matcher_from_catalog(json.loads(self._s3.get_object(Bucket=bucket, Key=key)["Body"].read()))
        except Exception as exc:
            logger.warning("entity_names_unavailable", namespace=namespace, error=str(exc)[:200])
            return None
        if len(self._matchers) >= 8:  # keep at most 8; drop the oldest
            self._matchers.pop(next(iter(self._matchers)))
        self._matchers[uri] = matcher
        return matcher

    @staticmethod
    def clarification_response(text: str, trace: Any, metadata: dict) -> Any:
        """A response that asks the user to choose, instead of running a query."""
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
    """Create the hook for serve, or return None when the feature is off.

    Off when ``SERVE_ENTITY_RESOLUTION=off``, or when there is no OpenSearch
    collection or no ``SSM_PREFIX`` to read the config from.
    """
    ssm_prefix = os.environ.get("SSM_PREFIX", "")
    if not collection or not ssm_prefix or os.environ.get("SERVE_ENTITY_RESOLUTION", "on").lower() == "off":
        return None
    import boto3

    region = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION") or "us-east-1"
    return EntityHook(
        vector_client,
        llm_client,
        boto3.client("ssm", region_name=region),
        boto3.client("s3", region_name=region),
        ssm_prefix,
        collection,
    )
