# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Same question, same answer: per-namespace SQL rules, fixed sampling, and an SQL cache.

Serve calls one method (see the ``cuedo-ext`` hooks in serve):

    await hook.before_tier2(query, namespace, metric_definitions, trace)
        -> Tier2Consistency, or None when the namespace has no config

and passes the result to the NL->SQL strategy, which

    - adds ``rules`` to the SQL prompt (every request, whatever Tier 1 matched),
    - calls the model with ``top_p`` (0 = always the most likely next word),
    - reuses ``cached`` SQL when the same question was answered before,
    - calls ``save(...)`` after a fresh SQL returned rows.

Config, one SSM parameter per namespace: ``{SSM_PREFIX}/consistency/{namespace}``

    {"rulesUri": "s3://bucket/answer-consistency/<ns>/rules.md",
     "cacheUri": "s3://bucket/answer-consistency/<ns>/cache/",
     "topP": 0,
     "cacheVersion": "1",
     "strategy": "nl_to_sql"}           # optional: pin the Tier-2 strategy (no fallback)

No parameter -> the feature is off and serve runs exactly as before. Any error
(SSM, S3, bad JSON) also turns it off for that request; it never fails a query.

A cached SQL is used only while the rules, the namespace's metric summaries and
``cacheVersion`` are unchanged. Change ``cacheVersion`` to clear the cache by hand
(e.g. after an ontology change). Delete one cache object to forget one answer.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import os
import re
import time
from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any

import structlog

logger = structlog.get_logger(__name__)

STEP_ID = "t2.consistency"
_CONFIG_TTL_S = 300.0
_RULES_TTL_S = 300.0
# Fields of the SQL generator's result needed to run a cached SQL again.
CACHE_FIELDS = (
    "sql",
    "confidence",
    "data_source_id",
    "retrieved_tables",
    "expanded_tables",
    "table_sources",
    "ddl_context",
    "column_direction",
)


def normalize_question(text: str) -> str:
    """Lower case, single spaces, no punctuation at the ends: 'Hello  World?' -> 'hello world'."""
    return re.sub(r"\s+", " ", text).strip().strip(".?!").strip().lower()


def split_s3_uri(uri: str) -> tuple[str, str]:
    """'s3://bucket/a/b' -> ('bucket', 'a/b')."""
    if not uri.startswith("s3://"):
        raise ValueError(f"not an s3:// uri: {uri!r}")
    bucket, _, key = uri.removeprefix("s3://").partition("/")
    return bucket, key


@dataclass
class Tier2Consistency:
    """What the NL->SQL strategy uses for one request."""

    rules: str = ""
    top_p: float | None = None
    cached: dict | None = None
    cache_bucket: str = ""
    cache_key: str = ""
    question: str = ""
    version: str = ""
    _s3: Any = field(default=None, repr=False)

    def save(self, result: dict) -> None:
        """Store a fresh SQL that returned rows. Never raises; does nothing on a cache hit."""
        if self.cached is not None or not self.cache_key or self._s3 is None:
            return
        entry = {k: result.get(k) for k in CACHE_FIELDS}
        entry.update(question=self.question, version=self.version, savedAt=datetime.now(UTC).isoformat())
        try:
            self._s3.put_object(
                Bucket=self.cache_bucket,
                Key=self.cache_key,
                Body=json.dumps(entry, default=str).encode(),
                ContentType="application/json",
            )
            logger.info("consistency_cache_saved", key=self.cache_key)
        except Exception as exc:
            logger.warning("consistency_cache_save_failed", key=self.cache_key, error=str(exc)[:200])


class ConsistencyHook:
    """Reads the namespace config, the rules file and the cache. Keeps small caches between requests."""

    def __init__(self, ssm_client: Any, s3_client: Any, ssm_prefix: str):
        """SSM for the per-namespace config, S3 for the rules file and the SQL cache."""
        self._ssm = ssm_client
        self._s3 = s3_client
        self._ssm_prefix = ssm_prefix.rstrip("/")
        self._configs: dict[str, tuple[dict | None, float]] = {}
        self._rules: dict[str, tuple[str, float]] = {}

    async def before_tier2(
        self, query: str, namespace: str, metric_definitions: list[dict] | None, trace: Any
    ) -> Tier2Consistency | None:
        """Serve awaits this. The work runs in a worker thread; the trace step is recorded here."""
        start = time.perf_counter()
        ext = await asyncio.to_thread(self.prepare, query, namespace, metric_definitions)
        if ext is not None:
            trace.record(
                STEP_ID,
                "hit" if ext.cached is not None else "miss",
                int((time.perf_counter() - start) * 1000),
                detail={"rules": bool(ext.rules), "topP": ext.top_p, "cacheKey": ext.cache_key.rsplit("/", 1)[-1]},
            )
        return ext

    async def strategy_for(self, namespace: str, default: Any) -> Any:
        """The Tier-2 strategy the config pins (``"strategy": "nl_to_sql"``), else ``default``."""
        config = await asyncio.to_thread(self.config_for, namespace)
        pinned = (config or {}).get("strategy")
        if not pinned:
            return default
        try:
            return type(default)(pinned)
        except ValueError:
            logger.warning("consistency_bad_strategy", namespace=namespace, strategy=pinned)
            return default

    def prepare(self, query: str, namespace: str, metric_definitions: list[dict] | None) -> Tier2Consistency | None:
        """Build the per-request object, or None when the namespace has no (valid) config."""
        config = self.config_for(namespace)
        if not config:
            return None
        try:
            rules = self.rules_for(config.get("rulesUri", ""))
            top_p = config.get("topP", 0)
            ext = Tier2Consistency(rules=rules, top_p=None if top_p is None else float(top_p), _s3=self._s3)
            cache_uri = config.get("cacheUri", "")
            if cache_uri:
                question = normalize_question(query)
                version = hashlib.sha256(
                    json.dumps(
                        [rules, metric_definitions or [], str(config.get("cacheVersion", ""))],
                        sort_keys=True,
                        default=str,
                    ).encode()
                ).hexdigest()[:16]
                bucket, prefix = split_s3_uri(cache_uri)
                name = hashlib.sha256(f"{question}\n{version}".encode()).hexdigest()[:32]
                ext.cache_bucket, ext.cache_key = bucket, f"{prefix.rstrip('/')}/{name}.json"
                ext.question, ext.version = question, version
                ext.cached = self._read_cache(bucket, ext.cache_key)
            return ext
        except Exception as exc:
            logger.warning("consistency_prepare_failed", namespace=namespace, error=str(exc)[:200])
            return None

    def config_for(self, namespace: str) -> dict | None:
        """The namespace's config, cached for 5 minutes. None means off."""
        cached = self._configs.get(namespace)
        if cached is not None and time.monotonic() - cached[1] < _CONFIG_TTL_S:
            return cached[0]
        name = f"{self._ssm_prefix}/consistency/{namespace}"
        try:
            config = json.loads(self._ssm.get_parameter(Name=name)["Parameter"]["Value"])
            if not isinstance(config, dict):
                raise ValueError("config is not a JSON object")
        except self._ssm.exceptions.ParameterNotFound:
            config = None
        except Exception as exc:
            # SSM did not answer, or the JSON is bad: off for now, try again next time.
            logger.warning("consistency_config_unavailable", namespace=namespace, error=str(exc)[:200])
            return None
        self._configs[namespace] = (config, time.monotonic())
        return config

    def rules_for(self, uri: str) -> str:
        """The rules text from S3, cached for 5 minutes. Empty when no uri."""
        if not uri:
            return ""
        cached = self._rules.get(uri)
        if cached is not None and time.monotonic() - cached[1] < _RULES_TTL_S:
            return cached[0]
        bucket, key = split_s3_uri(uri)
        text = self._s3.get_object(Bucket=bucket, Key=key)["Body"].read().decode().strip()
        self._rules[uri] = (text, time.monotonic())
        return text

    def _read_cache(self, bucket: str, key: str) -> dict | None:
        """A stored SQL for this question and version, or None."""
        try:
            entry = json.loads(self._s3.get_object(Bucket=bucket, Key=key)["Body"].read())
        except self._s3.exceptions.NoSuchKey:
            return None
        except Exception as exc:
            logger.warning("consistency_cache_read_failed", key=key, error=str(exc)[:200])
            return None
        return entry if isinstance(entry, dict) and entry.get("sql") else None


def build_consistency_hook() -> ConsistencyHook | None:
    """Create the hook for serve, or None when ``SSM_PREFIX`` is missing or ``SERVE_CONSISTENCY=off``."""
    ssm_prefix = os.environ.get("SSM_PREFIX", "")
    if not ssm_prefix or os.environ.get("SERVE_CONSISTENCY", "on").lower() == "off":
        return None
    import boto3

    region = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION") or "us-east-1"
    return ConsistencyHook(boto3.client("ssm", region_name=region), boto3.client("s3", region_name=region), ssm_prefix)
