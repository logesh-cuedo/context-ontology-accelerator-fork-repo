# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Session management via AgentCore Memory SDK.

Provides create/resume, history loading, and turn storage for
multi-turn conversations. Sessions use ULID IDs and are
scoped per namespace through DynamoDB metadata for discovery.
"""

from __future__ import annotations

import asyncio
import datetime
import json
from concurrent.futures import ThreadPoolExecutor
from decimal import Decimal

import structlog
from bedrock_agentcore.memory import MemorySessionManager
from bedrock_agentcore.memory.constants import ConversationalMessage, MessageRole
from ulid import ULID

logger = structlog.get_logger(__name__)

DEFAULT_HISTORY_WINDOW = 5
_EXECUTOR = ThreadPoolExecutor(max_workers=4, thread_name_prefix="memory")

# Maximum size for the serialized JSON envelope stored as assistant message text.
_MAX_ENVELOPE_CHARS = 10_000


def _json_default(obj: object) -> object:
    """json.dumps fallback for types the stdlib encoder can't handle.

    Query result rows can carry non-JSON-native types sourced from the
    underlying database (e.g. a ``numeric``/``DECIMAL`` column arrives as
    Python ``Decimal`` via asyncpg). Without this, envelope serialization
    raises ``TypeError: Object of type Decimal is not JSON serializable`` and
    the turn is never persisted, the response is never delivered, and the
    UI hangs on "Running query". Decimal → float (JSON number); date/datetime →
    ISO-8601 string.
    """
    if isinstance(obj, Decimal):
        return float(obj)
    if isinstance(obj, (datetime.date, datetime.datetime, datetime.time)):
        return obj.isoformat()
    raise TypeError(f"Object of type {obj.__class__.__name__} is not JSON serializable")


def _build_message_envelope(
    answer: str,
    result_metadata: dict | None = None,
) -> str:
    """Build a JSON envelope containing answer text plus metadata.

    The envelope is stored as the assistant ConversationalMessage text.
    On read, the parser detects it (object with "text" key) and splits
    content from metadata.

    ``result_metadata`` is expected to come pre-serialized (camelCase keys,
    no None values) from QueryResult.model_dump(). This function merges it
    as-is, only applying a size guard on the trace detail fields.
    """
    envelope: dict = {"text": answer}
    if result_metadata:
        envelope.update(result_metadata)

    serialized = json.dumps(envelope, separators=(",", ":"), default=_json_default)

    # Truncate trace details if envelope is too large
    if len(serialized) > _MAX_ENVELOPE_CHARS and "trace" in envelope:
        for step in envelope["trace"]:
            if "detail" in step:
                step.pop("detail")
            serialized = json.dumps(envelope, separators=(",", ":"), default=_json_default)
            if len(serialized) <= _MAX_ENVELOPE_CHARS:
                break

    return serialized


def _resolved_entities(metadata: dict) -> list[str]:
    """Entity names the resolver settled on for this turn, from its trace step."""
    for step in metadata.get("trace") or []:
        if not isinstance(step, dict) or "entity.resolve" not in str(step.get("step", "")):
            continue
        by_kind = (step.get("detail") or {}).get("entities") or {}
        return [n for names in by_kind.values() if isinstance(names, list) for n in names]
    return []


def _answered_columns(metadata: dict) -> list[str]:
    """The column headings this turn's answer came back with.

    Read from the first result row, which is where the shape of an answer actually
    shows: a turn that reported ROCE has a "Roce" column whatever its SQL looked like.
    Carried so the next question can be told what has already been answered — the SQL
    writer sees the question alone, so "and its roce?" after a net-sales question read
    as a fresh request and returned net sales a second time.
    """
    rows = metadata.get("resultRows") or metadata.get("result_rows")
    if isinstance(rows, list) and rows and isinstance(rows[0], dict):
        return [str(c) for c in rows[0]][:12]
    return []


def _parse_assistant_content(raw_text: str) -> tuple[str, dict | None]:
    """Parse assistant message content, detecting JSON envelope.

    Returns (display_text, metadata_or_none).
    Legacy plain-string messages return (raw_text, None).
    """
    if not raw_text.startswith("{"):
        return raw_text, None
    try:
        obj = json.loads(raw_text)
        if isinstance(obj, dict) and "text" in obj:
            text = obj.pop("text")
            metadata = obj if obj else None
            return text, metadata
    except (json.JSONDecodeError, TypeError):
        pass
    return raw_text, None


class SessionManager:
    """Manages conversation sessions backed by AgentCore Memory."""

    def __init__(self, memory_id: str, region: str | None = None):
        """Wire up the AgentCore Memory session manager.

        Args:
            memory_id: AgentCore Memory resource id backing conversation storage.
            region: AWS region for the Memory client; uses the default when None.
        """
        self._manager = MemorySessionManager(
            memory_id=memory_id,
            region_name=region,
        )

    @staticmethod
    def generate_session_id() -> str:
        """Generate a new unique session ID (ULID)."""
        return str(ULID())

    @staticmethod
    def _memory_actor(user_id: str, namespace_id: str) -> str:
        """Compose the AgentCore Memory actor id, scoped by namespace.

        Conversation turns are stored in AgentCore Memory keyed by
        (actor_id, session_id). Keying the actor on ``user_id`` alone lets a
        session id reused across namespaces (same user) share one history —
        cross-namespace context leakage. Qualifying the actor with the namespace
        isolates history per (user, namespace) so the same session id in a
        different namespace resolves to a distinct, empty history.

        The Memory API constrains actor_id to ``[a-zA-Z0-9][a-zA-Z0-9-_/]*`` —
        ``/`` is permitted (``#`` is not), so we join with ``/``. An empty
        ``namespace_id`` returns the bare ``user_id`` unchanged, preserving the
        prior key for any caller that cannot supply a namespace.
        """
        return f"{user_id}/{namespace_id}" if namespace_id else user_id

    async def create_or_resume(
        self,
        user_id: str,
        namespace_id: str,
        session_id: str | None = None,
        max_turns: int = DEFAULT_HISTORY_WINDOW,
    ) -> tuple[str, list[dict[str, str]]]:
        """Create or resume a session, returning ID and conversation history.

        For the orchestrator path: extracts only the text content from
        envelope messages, keeping the LLM context clean.

        Returns:
            Tuple of (session_id, conversation_history).
        """
        sid = session_id or SessionManager.generate_session_id()
        history = await self._load_history(user_id, sid, max_turns, include_metadata=False, namespace_id=namespace_id)

        logger.info(
            "session_ready",
            session_id=sid,
            user_id=user_id,
            namespace_id=namespace_id,
            resumed_turns=len(history),
        )
        return sid, history

    async def get_rich_history(
        self,
        user_id: str,
        session_id: str,
        max_turns: int = 25,
        *,
        namespace_id: str = "",
    ) -> list[dict]:
        """Retrieve session history with metadata for UI restore.

        Returns list of dicts: {role, content, metadata?}
        """
        history = await self._load_history(
            user_id, session_id, max_turns, include_metadata=True, namespace_id=namespace_id
        )

        logger.info(
            "rich_history_loaded",
            session_id=session_id,
            user_id=user_id,
            messages=len(history),
        )
        return history

    async def get_rich_history_page(
        self,
        user_id: str,
        session_id: str,
        limit: int = 5,
        offset: int = 0,
        max_turns: int = 25,
        *,
        namespace_id: str = "",
    ) -> tuple[list[dict], int, bool]:
        """Retrieve a page of session history (newest-first pagination).

        Loads history up to max_turns, then slices to return the requested page.
        Messages are ordered oldest-first in the returned list so the client
        can prepend them naturally.

        For initial restore, use a small max_turns (25) for fast response.
        For deep scroll-back, callers can pass a larger max_turns (500).

        Args:
            user_id: Identifier of the user whose history is being read.
            session_id: Conversation session to page through.
            limit: Number of messages per page.
            offset: How many messages from the end to skip (0 = most recent).
            max_turns: Upper bound on turns to fetch from AgentCore Memory.
            namespace_id: Namespace scoping the memory actor; isolates history
                per (user, namespace).

        Returns:
            Tuple of (messages_page, total_count, has_more).
        """
        history = await self._load_history(
            user_id, session_id, max_turns, include_metadata=True, namespace_id=namespace_id
        )
        total = len(history)

        # Slice from the end: offset=0 means the last `limit` messages
        end_idx = total - offset
        start_idx = max(0, end_idx - limit)
        page = history[start_idx:end_idx] if end_idx > 0 else []
        has_more = start_idx > 0

        logger.info(
            "rich_history_page_loaded",
            session_id=session_id,
            user_id=user_id,
            total=total,
            offset=offset,
            limit=limit,
            page_size=len(page),
            has_more=has_more,
        )
        return page, total, has_more

    async def _load_history(
        self,
        user_id: str,
        session_id: str,
        max_turns: int,
        *,
        include_metadata: bool,
        namespace_id: str = "",
    ) -> list[dict]:
        """Fetch turns from AgentCore Memory and parse messages."""
        session = self._manager.create_memory_session(
            actor_id=self._memory_actor(user_id, namespace_id),
            session_id=session_id,
        )
        loop = asyncio.get_running_loop()
        turns = await loop.run_in_executor(_EXECUTOR, session.get_last_k_turns, max_turns)

        history: list[dict] = []
        for event_messages in reversed(turns):
            for msg in event_messages:
                role = msg.get("role", "").lower()
                text = msg.get("content", {}).get("text", "")
                if role not in ("user", "assistant") or not text:
                    continue

                if role == "assistant":
                    display_text, metadata = _parse_assistant_content(text)
                    entry: dict = {"role": role, "content": display_text}
                    if include_metadata and metadata:
                        entry["metadata"] = metadata
                    elif metadata and (resolved := _resolved_entities(metadata)):
                        # The orchestrator path takes text only, to keep the LLM
                        # context clean. But a follow-up ("what about roce") names
                        # nobody and must carry the entity from the turn before,
                        # which it reads back from the stored words — and a
                        # misspelled name ("relaience") is not findable in those
                        # words, so the carry found nobody and the follow-up
                        # answered about every company in the namespace. The names
                        # resolution settled on are already in this turn's trace;
                        # carrying just those keeps the turn readable without
                        # restoring the whole envelope.
                        entry["resolved_entities"] = resolved
                    # Independently of the entities: a turn can answer with columns
                    # while naming nobody ("top 10 by revenue"), and the next question
                    # still must not repeat it.
                    if metadata and not include_metadata and (cols := _answered_columns(metadata)):
                        entry["answered_columns"] = cols
                    history.append(entry)
                else:
                    history.append({"role": role, "content": text})

        return history

    async def append_turn(
        self,
        user_id: str,
        session_id: str,
        query: str,
        answer_summary: str,
        *,
        namespace_id: str = "",
        result_metadata: dict | None = None,
    ) -> None:
        """Store a conversation turn (user query + assistant response).

        Stores plain text first (guaranteed to work), then optionally
        attempts to store with JSON envelope for rich history.
        """
        # Build the text to store. Try envelope, fall back to plain text.
        assistant_text = answer_summary
        if result_metadata:
            try:
                assistant_text = _build_message_envelope(
                    answer=answer_summary,
                    result_metadata=result_metadata,
                )
            except Exception:
                logger.warning("envelope_build_failed", session_id=session_id, exc_info=True)
                assistant_text = answer_summary

        session = self._manager.create_memory_session(
            actor_id=self._memory_actor(user_id, namespace_id),
            session_id=session_id,
        )
        messages = [
            ConversationalMessage(query, MessageRole.USER),
            ConversationalMessage(assistant_text, MessageRole.ASSISTANT),
        ]

        # Store the turn. No metadata param; keep it simple and reliable.
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(_EXECUTOR, session.add_turns, messages)
