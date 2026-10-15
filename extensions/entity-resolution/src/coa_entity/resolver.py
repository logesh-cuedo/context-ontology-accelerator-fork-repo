# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Tier-2 entity resolution: which configured entities is the user asking about?

Flow (one request):

    user query ──► similarity search over the namespace's entity index, one
                   search per configured entity type (see coa_entity.config)
               ──► top-k candidates ──► LLM picks from the candidates
               ──► found       → exact entities handed to SQL generation
                   no_entity   → the question names no entity; continue
                   not_found   → ask the user for clarification
                   ambiguous   → ask the user which candidate they meant

Fail-open: an empty index, a search error, or an unparseable LLM reply all
return ``status="skipped"`` and Tier 2 runs as if this step did not exist.

A clarification is resumed on the user's NEXT message through the session
history (:func:`resume_clarification`): the reply is merged with the original
question, so the whole pipeline re-runs on the question the user asked.
"""

from __future__ import annotations

import asyncio
import json
import re
from dataclasses import dataclass, field
from typing import Any

import structlog

from .config import EntityConfig
from .index_builder import index_name

logger = structlog.get_logger(__name__)

# Every clarification ends with this line. resume_clarification() recognises a
# clarification turn in the session history by it, so keep the two in sync.
CLARIFICATION_MARKER = "Reply with the number or the name."

# Options listed in a clarification — enough to contain the right one without
# burying it.
_MAX_OPTIONS = 5
_OPTION_LINE = re.compile(r"^\s*(\d+)\.\s+(.+?)\s*$")
_STATUSES = {"found", "no_entity", "not_found", "ambiguous"}


@dataclass(frozen=True)
class EntityCandidate:
    """One entity returned by the similarity search."""

    kind: str
    key: str
    name: str
    attrs: tuple[tuple[str, str], ...] = ()
    score: float = 0.0

    @property
    def label(self) -> str:
        """Option text: the name plus its first attribute, e.g. ``Bajaj Auto Ltd. (Automobile)``."""
        return f"{self.name} ({self.attrs[0][1]})" if self.attrs else self.name


@dataclass
class EntityResolution:
    """Outcome of one resolution: what was found, or what to ask the user."""

    status: str  # found | no_entity | not_found | ambiguous | skipped
    chosen: list[EntityCandidate] = field(default_factory=list)
    clarification: str = ""
    reason: str = ""

    @property
    def needs_clarification(self) -> bool:
        """True when the pipeline must stop and ask the user."""
        return self.status in ("not_found", "ambiguous")

    def by_kind(self) -> dict[str, list[str]]:
        """Chosen entity names grouped by type — the trace step's detail."""
        out: dict[str, list[str]] = {}
        for c in self.chosen:
            out.setdefault(c.kind, []).append(c.name)
        return out


def like_literal(name: str) -> str:
    """Lower-case a name for a LIKE pattern: double quotes, drop ``%``."""
    return name.lower().replace("'", "''").replace("%", "")


def _quote(value: str) -> str:
    """A SQL string-literal body: single quotes doubled."""
    return value.replace("'", "''")


def resolved_block(resolution: EntityResolution, config: EntityConfig) -> str:
    """SQL-prompt section naming the exact entities to filter on (status ``found``)."""
    if resolution.status != "found" or not resolution.chosen:
        return ""
    lines = [
        "## Resolved entities (authoritative)",
        "The question's entities were resolved against the configured entity tables. "
        "Filter on exactly these and nothing broader; do not rebuild the filters from "
        "the user's words. Apply every listed filter (an 'AND <column> = ...' part only on "
        "tables that have that column). Other attributes in parentheses (and any in the "
        "question's 'User clarification' line) only identify the entity: do NOT turn "
        "them into extra WHERE conditions unless the question asks to filter by them.",
    ]
    for c in resolution.chosen:
        column = config.sql_column(c.kind)
        member = config.member_spec(c.kind)
        if member is not None:
            ident = ", ".join([f"{member.id_column} {c.key}", *(f"{k} {v}" for k, v in c.attrs)])
            attrs = dict(c.attrs)
            extra = "".join(
                f" AND {g.sql_column} = '{_quote(attrs[g.column])}'"
                for g in member.groups
                if g.filter_with_member and attrs.get(g.column)
            )
            lines.append(f"- {c.kind}: {c.name} ({ident}) → LOWER({column}) LIKE '%{like_literal(c.name)}%'{extra}")
        else:
            lines.append(f"- {c.kind}: {c.name} → {column} = '{_quote(c.name)}'")
    return "\n".join(lines)


def fallback_rules(config: EntityConfig) -> str:
    """SQL-prompt rules for entity name filters when nothing was resolved.

    Applies whenever a namespace has an entity config but the resolver did not
    produce a ``found`` result (no entity named, index missing, step skipped).
    """
    columns = list(dict.fromkeys(s.sql_column for s in config.entity_types))
    if not columns:
        return ""
    names = ", ".join(columns)
    return (
        "## Entity name filters\n"
        f"Whenever you filter on {names} in any table, write LOWER(<column>) LIKE '%<name>%'. "
        "Never compare these columns with = or IN, even for a full official name, and this "
        "overrides any 'allowed values' list on them. Build <name> from the user's words: "
        "lower-case it, drop a trailing corporate suffix (ltd, limited, pvt, private, inc, "
        "corp, corporation, co) and double any single quote. Never build it from a generic "
        "word alone (company, group, holdings, enterprises, india, indian). For several "
        "entities, OR one LIKE per entity inside parentheses."
    )


def _candidate_from_hit(hit: Any, kind: str) -> EntityCandidate | None:
    """Shape a vector hit written by coa_entity.index_builder into a candidate."""
    meta = getattr(hit, "metadata", None) or {}
    key = str(meta.get("entity_uri") or "").strip()
    if not key:
        return None
    try:
        ctx = json.loads(meta.get("context_text") or "{}")
    except (TypeError, ValueError):
        ctx = {}
    name = str(ctx.get("name") or "").strip() or key
    attrs = ctx.get("attrs") if isinstance(ctx.get("attrs"), dict) else {}
    return EntityCandidate(
        kind=kind,
        key=key,
        name=name,
        attrs=tuple((str(k), str(v)) for k, v in attrs.items() if v),
        score=float(getattr(hit, "score", 0.0) or 0.0),
    )


def _parse_json_object(text: str) -> dict | None:
    """Extract the first JSON object from an LLM reply (tolerates fences/prose)."""
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end <= start:
        return None
    try:
        parsed = json.loads(text[start : end + 1])
    except ValueError:
        return None
    return parsed if isinstance(parsed, dict) else None


def _numbered(candidates: list[EntityCandidate]) -> str:
    return "\n".join(f"{i}. {c.label}" for i, c in enumerate(candidates, start=1))


class EntityResolver:
    """Similarity search → top-k → LLM selection over the namespace entity index."""

    def __init__(self, vector_client: Any, llm_client: Any, collection: str):
        """Wire serve's shared clients.

        Args:
            vector_client: Serve's AOSS client (search-only is enough).
            llm_client: Bedrock client used for the embedding and selection calls.
            collection: The AOSS collection name; the per-namespace index is
                ``{collection}-entities-{namespace}``.
        """
        self._vector = vector_client
        self._llm = llm_client
        self._collection = collection

    async def resolve(
        self,
        query: str,
        namespace: str,
        config: EntityConfig,
        *,
        embedding: list[float] | None = None,
        model_id: str | None = None,
    ) -> EntityResolution:
        """Resolve the configured entities a question refers to. Never raises."""
        try:
            vector = embedding or await self._llm.embed(query)
            candidates = await self._similarity_search(vector, namespace, config)
        except Exception as exc:
            logger.warning("entity_search_failed", namespace=namespace, error=str(exc)[:200])
            return EntityResolution(status="skipped", reason="similarity search failed")
        if not candidates:
            return EntityResolution(status="skipped", reason="entity index empty")

        try:
            reply = await self._llm.converse(
                self._selection_prompt(query, candidates, config),
                max_tokens=600,
                temperature=0.0,
                model_id=model_id,
            )
            choice = _parse_json_object(reply.text or "")
        except Exception as exc:
            logger.warning("entity_selection_failed", namespace=namespace, error=str(exc)[:200])
            choice = None
        if choice is None or choice.get("status") not in _STATUSES:
            return EntityResolution(status="skipped", reason="unusable selection reply")

        resolution = self._build_resolution(choice, candidates, config)
        logger.info(
            "entity_resolved",
            namespace=namespace,
            status=resolution.status,
            entities=resolution.by_kind(),
            candidates=len(candidates),
        )
        return resolution

    async def _similarity_search(
        self, vector: list[float], namespace: str, config: EntityConfig
    ) -> list[EntityCandidate]:
        """Top-k candidates of every configured kind, one search per kind, in parallel."""
        index = index_name(self._collection, namespace)
        kinds = config.kinds()
        results = await asyncio.gather(
            *(
                self._vector.search(vector, namespace=namespace, top_k=top_k, index=index, entity_type=kind)
                for kind, top_k in kinds
            )
        )
        return [
            c
            for (kind, _), hits in zip(kinds, results, strict=True)
            for h in hits
            if (c := _candidate_from_hit(h, kind))
        ]

    @staticmethod
    def _selection_prompt(query: str, candidates: list[EntityCandidate], config: EntityConfig) -> str:
        kinds = ", ".join(kind for kind, _ in config.kinds())
        lines = "\n".join(
            f"E{i}. [{c.kind}] {c.name}" + (" | " + ", ".join(f"{k}: {v}" for k, v in c.attrs) if c.attrs else "")
            for i, c in enumerate(candidates, start=1)
        )
        return (
            f"You resolve which named entities ({kinds}) a data question refers to.\n"
            "A similarity search over the database's entity tables returned the candidates "
            "below. Choose ONLY from these candidates — never invent one.\n\n"
            f"## Question\n<question>{query}</question>\n\n"
            f"## Candidates\n{lines}\n\n"
            "## Decide one status\n"
            '- "no_entity": the question names no specific entity (e.g. "top 10 by revenue", '
            '"median PE", a breakdown "by sector"). The candidates are then irrelevant.\n'
            '- "found": every entity the question names matches exactly one candidate. Short '
            "names, acronyms (TCS → Tata Consultancy Services), missing suffixes (Ltd, Limited) "
            "and small typos still count as a match.\n"
            '- "ambiguous": a name in the question fits two or more candidates equally well and '
            'nothing in the question decides between them (e.g. "Bajaj" with Bajaj Auto and '
            "Bajaj Finance both listed).\n"
            '- "not_found": the question names an entity that matches NO candidate.\n'
            "If the question contains 'User clarification:', that text is the user's answer to "
            "an earlier question about which entity they meant — use it to decide.\n\n"
            "## Output — one JSON object, nothing else\n"
            "{\n"
            '  "status": "found" | "no_entity" | "ambiguous" | "not_found",\n'
            '  "chosen": ["E1"],                      // found: the chosen candidate labels\n'
            '  "mention": "bajaj",                    // ambiguous/not_found: the name as written\n'
            '  "ambiguous_candidates": ["E1", "E2"]   // ambiguous: the candidates it could be\n'
            "}"
        )

    @staticmethod
    def _build_resolution(choice: dict, candidates: list[EntityCandidate], config: EntityConfig) -> EntityResolution:
        """Validate the LLM's labels against the candidate list and build the outcome."""
        by_label = {f"E{i}": c for i, c in enumerate(candidates, start=1)}

        def pick(labels: object) -> list[EntityCandidate]:
            picked: list[EntityCandidate] = []
            for label in labels if isinstance(labels, list) else []:
                cand = by_label.get(str(label).strip().upper())
                if cand is not None and cand not in picked:  # hallucinated labels dropped
                    picked.append(cand)
            return picked

        status = choice["status"]
        mention = str(choice.get("mention") or "").strip() or "that name"

        if status == "found":
            chosen = pick(choice.get("chosen"))
            if chosen:
                return EntityResolution(status="found", chosen=chosen)
            status = "not_found"  # "found" with no valid label → ask rather than guess

        if status == "ambiguous":
            options = pick(choice.get("ambiguous_candidates"))[:_MAX_OPTIONS]
            if len(options) >= 2:
                return EntityResolution(
                    status="ambiguous",
                    clarification=(
                        f"**{mention}** matches more than one entry. Which one did you mean?\n\n"
                        f"{_numbered(options)}\n\n{CLARIFICATION_MARKER}"
                    ),
                )
            status = "not_found"

        if status == "not_found":
            kinds = " or ".join(kind for kind, _ in config.kinds())
            return EntityResolution(
                status="not_found",
                clarification=(
                    f"I couldn't find **{mention}** among this namespace's {kinds} entries. "
                    f"Did you mean one of these?\n\n{_numbered(candidates[:_MAX_OPTIONS])}\n\n{CLARIFICATION_MARKER}"
                ),
            )

        return EntityResolution(status="no_entity")


def resume_clarification(query: str, history: list[dict[str, str]] | None) -> str | None:
    r"""Merge the user's reply into the question that triggered a clarification.

    When the previous assistant turn was an entity clarification (it ends with
    :data:`CLARIFICATION_MARKER`), the current ``query`` is the user's answer. A
    bare option number ("2") is expanded to that option's text. Returns
    ``"<original question>\\nUser clarification: <answer>"``, or ``None`` when the
    previous turn was not a clarification.
    """
    if not history:
        return None
    last_assistant = next((i for i in range(len(history) - 1, -1, -1) if history[i].get("role") == "assistant"), None)
    if last_assistant is None:
        return None
    clarification = str(history[last_assistant].get("content") or "")
    if CLARIFICATION_MARKER not in clarification:
        return None
    original = next(
        (
            str(history[j].get("content") or "")
            for j in range(last_assistant - 1, -1, -1)
            if history[j].get("role") == "user"
        ),
        "",
    )
    if not original:
        return None

    answer = query.strip()
    if answer.isdigit():
        options = {m.group(1): m.group(2) for line in clarification.splitlines() if (m := _OPTION_LINE.match(line))}
        answer = options.get(answer, answer)
    # A resumed question can itself be a resumed question; keep only the root.
    original = original.split("\nUser clarification:")[0]
    return f"{original}\nUser clarification: {answer}"
