# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""The one object serve calls (see the ``cuedo-ext`` hooks in serve).

    hook.resume(query, history)       the question plus the user's answer, when the
                                      user is answering our question; else None
    await hook.before_tier2(...)      Tier2Outcome(clarification=..., sql_context=...)
    hook.clarification_response(...)  the response that asks the user to choose

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
from .config import EntityConfig, EntityConfigError, load_config
from .index_builder import index_name
from .lexical import matcher_from_catalog
from .resolver import fallback_rules, resolve_entities, resolved_block, resume_clarification

logger = structlog.get_logger(__name__)

STEP_ID = "t2.entity.resolve"
_CONFIG_TTL_S = 300.0
_POINTER_TTL_S = 60.0


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
        self._vector = vector_client
        self._llm = llm_client
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

    async def config_for(self, namespace: str) -> EntityConfig | None:
        """The namespace's entity config, cached for 5 minutes. None means the feature is off."""
        cached = self._configs.get(namespace)
        if cached is not None and time.monotonic() - cached[1] < _CONFIG_TTL_S:
            return cached[0]
        try:
            config = await asyncio.to_thread(load_config, self._ssm, self._ssm_prefix, namespace)
        except EntityConfigError as exc:
            logger.warning("entity_config_invalid", namespace=namespace, error=str(exc)[:300])
            config = None
        except Exception as exc:
            # SSM did not answer: do not cache, try again on the next request.
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
        """Find the question's companies / sectors, and log a trace step. Never raises an error.

        Time periods (FY25, Q3 FY25, ...) are not handled here: a ``time`` block in the
        config is still accepted but ignored. Periods are left to the metrics.
        """
        config = await self.config_for(namespace)
        if config is None:
            return Tier2Outcome()
        sections: list[str] = []

        if config.entity_types:
            start = time.perf_counter()
            # Which index version to search. Cached for 1 minute; on an SSM error the last one is kept.
            cached = self._pointers.get(namespace)
            if cached is not None and time.monotonic() - cached[1] < _POINTER_TTL_S:
                pointer = cached[0]
            else:
                try:
                    pointer = await asyncio.to_thread(read_pointer, self._ssm, self._ssm_prefix, namespace)
                except Exception as exc:
                    logger.warning("entity_pointer_unavailable", namespace=namespace, error=str(exc)[:200])
                    pointer = cached[0] if cached else None
                self._pointers[namespace] = (pointer, time.monotonic())

            index, matcher = index_name(self._collection, namespace), None  # older index without versions
            if pointer is not None:
                index, uri = pointer.index, pointer.names_uri
                matcher = self._matchers.get(uri)
                if matcher is None and uri:  # load this version's name list from S3 (only once)
                    try:
                        bucket, _, key = uri.removeprefix("s3://").partition("/")
                        matcher = await asyncio.to_thread(
                            lambda: matcher_from_catalog(
                                json.loads(self._s3.get_object(Bucket=bucket, Key=key)["Body"].read())
                            )
                        )
                        if len(self._matchers) >= 8:  # keep at most 8; drop the oldest
                            self._matchers.pop(next(iter(self._matchers)))
                        self._matchers[uri] = matcher
                    except Exception as exc:
                        logger.warning("entity_names_unavailable", namespace=namespace, error=str(exc)[:200])

            resolution = await resolve_entities(
                self._vector,
                self._llm,
                query,
                namespace,
                config,
                index=index,
                matcher=matcher,
                embedding=embedding,
                model_id=model_id,
            )
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
            sections.append(resolved_block(resolution, config) or fallback_rules(config))

        return Tier2Outcome(sql_context="\n\n".join(s for s in sections if s))

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
