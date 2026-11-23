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
     "protectedTermsUri": "s3://bucket/answer-consistency/<ns>/protected_terms.json",  # optional
     "answersUri": "s3://bucket/answer-consistency/<ns>/verified_answers.json",       # optional
     "strategy": "nl_to_sql"}           # optional: pin the Tier-2 strategy (no fallback)

No parameter -> the feature is off and serve runs exactly as before. Any error
(SSM, S3, bad JSON) also turns it off for that request; it never fails a query.

A cached SQL is used only while the rules, the namespace's metric summaries and
``cacheVersion`` are unchanged.

Verified answers: ``answersUri`` is a JSON list of {"question", "sql", ...cache
fields}. A question that matches one (typo rule below) always runs that SQL,
whatever the rules or metrics are; it is checked before the AI cache.

Typos: a question is the same question when its protected words are identical
and in the same order, and its other words differ only by small typos.
Protected words are numbers, '%', words of 3 letters or less, the logic words
below, and the namespace's terms file (metric, sector and period words). So
"compnies" finds "companies", but 20% vs 80%, Q3FY26 vs Q2FY26, PAT vs PBT,
above vs below are different questions. Change ``cacheVersion`` to clear the cache by hand
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


def _words(text: str) -> list[str]:
    """'a b c' -> ['a', 'b', 'c']."""
    return text.split()


# Dropped before comparing: they never change what a question asks.
_STOPWORDS = frozenset(
    _words(
        "a an the of in on at for to is are was were be been it its which that who whom what whats please "
        "give me show tell can could you we us my our has have had do does did will would should this these "
        "those with by from as during also along there their them they kindly i"
    )
)
# Always compared exactly: changing one changes the answer.
LOGIC_WORDS = frozenset(
    _words(
        "above below greater less more fewer than between atleast atmost least most not no never but except "
        "without only all any each every both either neither and or over under exceed exceeds exceeding "
        "highest lowest top bottom max min maximum minimum median average mean total sum count rank growth "
        "grown grew grow growing decline declined declining increase increased decrease decreased compression "
        "expansion improve improved fall fell rise rose yoy qoq previous last latest recent recently "
        "concluded current first second third fourth next prior before after since until ago yesterday today "
        "trailing quarter quarters quarterly year years yearly annual annually month months week weeks "
        "standalone consolidated percent percentage crore crores lakh lakhs bps basis points ratio versus "
        "compare same different one two three four five six seven eight nine ten eleven twelve twenty thirty "
        "forty fifty hundred thousand million billion january february march april may june july august "
        "september october november december sept time times listed unlisted end start begin beginning ending "
        "ended"
    )
)


def question_parts(text: str, protected_terms: frozenset[str] = frozenset()) -> tuple[list[str], list[str]]:
    """Split a question into (protected words, other words), both in order, stopwords removed."""
    text = text.lower().replace("&", " and ")
    text = re.sub(r"(?<=\d),(?=\d)", "", text)  # 1,500 -> 1500
    text = re.sub(r"\bat\s+least\b", "atleast", text)
    text = re.sub(r"\bat\s+most\b", "atmost", text)
    protected: list[str] = []
    loose: list[str] = []
    for word in re.findall(r"[a-z]+|\d+(?:\.\d+)?|%", text):
        if word in _STOPWORDS or _is_stopword_typo(word, protected_terms):
            continue
        if not word.isalpha() or len(word) <= 3 or word in LOGIC_WORDS or word in protected_terms:
            protected.append(word)
        else:
            loose.append(word)
    return protected, loose


def _is_stopword_typo(word: str, protected_terms: frozenset[str]) -> bool:
    """A 3-letter word one letter off a longer stopword: 'gve' (give), 'hve' (have), 'whch' is not short."""
    if len(word) != 3 or not word.isalpha() or word in LOGIC_WORDS or word in protected_terms:
        return False
    return any(len(stop) >= 4 and _edit_distance(word, stop) == 1 for stop in _STOPWORDS)


def _edit_distance(a: str, b: str) -> int:
    """Letters to add, remove, change or swap (adjacent) to turn a into b."""
    prev2: list[int] = []
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i] + [0] * len(b)
        for j, cb in enumerate(b, 1):
            cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb))
            if i > 1 and j > 1 and ca == b[j - 2] and a[i - 2] == cb:
                cur[j] = min(cur[j], prev2[j - 2] + 1)
        prev2, prev = prev, cur
    return prev[-1]


def same_words(a: list[str], b: list[str]) -> bool:
    """Same words allowing typos: 1 letter for words of 4-7 letters, 2 for longer words."""
    if len(a) != len(b):
        return False
    for x, y in zip(a, b, strict=True):
        if x != y and _edit_distance(x, y) > (1 if min(len(x), len(y)) < 8 else 2):
            return False
    return True


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
    loose: list[str] = field(default_factory=list)
    _s3: Any = field(default=None, repr=False)

    def save(self, result: dict) -> None:
        """Store a fresh SQL that returned rows. Never raises; does nothing on a cache hit."""
        if self.cached is not None or not self.cache_key or self._s3 is None:
            return
        entry = {k: result.get(k) for k in CACHE_FIELDS}
        entry.update(
            question=self.question, version=self.version, loose=self.loose, savedAt=datetime.now(UTC).isoformat()
        )
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
                # Serve lists metrics in load order, which differs between containers: sort them.
                metrics = sorted(metric_definitions or [], key=lambda m: json.dumps(m, sort_keys=True, default=str))
                version = hashlib.sha256(
                    json.dumps(
                        [rules, metrics, str(config.get("cacheVersion", ""))],
                        sort_keys=True,
                        default=str,
                    ).encode()
                ).hexdigest()[:16]
                terms = frozenset(json.loads(self.rules_for(config.get("protectedTermsUri", "")) or "[]"))
                protected, loose = question_parts(query, terms)
                bucket, prefix = split_s3_uri(cache_uri)
                # Questions with the same protected words share a folder; typos are matched inside it.
                folder = hashlib.sha256(json.dumps([protected, version]).encode()).hexdigest()[:24]
                name = hashlib.sha256(f"{question}\n{version}".encode()).hexdigest()[:32]
                folder_prefix = f"{prefix.rstrip('/')}/{folder}/"
                ext.cache_bucket, ext.cache_key = bucket, f"{folder_prefix}{name}.json"
                ext.question, ext.version, ext.loose = question, version, loose
                ext.cached = (
                    self._verified_answer(config.get("answersUri", ""), protected, loose, terms)
                    or self._read_cache(bucket, ext.cache_key)
                    or self._typo_match(bucket, folder_prefix, loose)
                )
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

    def _verified_answer(self, uri: str, protected: list[str], loose: list[str], terms: frozenset[str]) -> dict | None:
        """The verified SQL for this question (same protected words, typos allowed), or None."""
        if not uri:
            return None
        for answer in json.loads(self.rules_for(uri) or "[]"):
            other_protected, other_loose = question_parts(answer.get("question", ""), terms)
            if answer.get("sql") and other_protected == protected and same_words(loose, other_loose):
                logger.info("consistency_verified_answer", question=answer["question"][:80])
                return {**answer, "verified": True}
        return None

    def _typo_match(self, bucket: str, folder_prefix: str, loose: list[str]) -> dict | None:
        """A stored SQL in the same folder whose other words differ only by typos (oldest first), or None."""
        try:
            listed = self._s3.list_objects_v2(Bucket=bucket, Prefix=folder_prefix, MaxKeys=100)
        except Exception as exc:
            logger.warning("consistency_cache_list_failed", prefix=folder_prefix, error=str(exc)[:200])
            return None
        objects = sorted(listed.get("Contents", []), key=lambda o: (str(o.get("LastModified", "")), o["Key"]))
        for obj in objects:
            entry = self._read_cache(bucket, obj["Key"])
            if entry is not None and same_words(loose, list(entry.get("loose") or [])):
                logger.info("consistency_cache_typo_hit", key=obj["Key"])
                return entry
        return None

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
