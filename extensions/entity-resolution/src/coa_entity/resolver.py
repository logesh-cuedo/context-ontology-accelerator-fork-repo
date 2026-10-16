# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Tier-2 entity resolution: which configured entities is the user asking about?

Every configured kind — an entity type such as ``company`` or a group such as
``sector`` — goes through the SAME path (see ``config.KindInfo``):

    user query ──► candidates per kind = vector search  ∪  name match (lexical)
               ──► LLM picks from the candidates
               ──► found       → exact filters handed to SQL generation
                   no_entity   → the question names no entity; generic rules apply
                   not_found   → ask the user (numbered options)
                   ambiguous   → ask the user which one (numbered options; a
                                 group kind also offers "All of these")

Fail-open: a search error, no candidates or an unusable LLM reply return
``status="skipped"`` and Tier 2 runs with the generic filter rules.

A clarification is resumed on the user's NEXT message through the session
history (:func:`resume_clarification`): numbers ("2", "2.", "1,3"), "all", or a
name are merged into the original question; a reply that is itself a new
question is treated as a new question.
"""

from __future__ import annotations

import asyncio
import json
import re
from dataclasses import dataclass, field
from typing import Any

import structlog

from .config import EntityConfig, KindInfo
from .lexical import NameMatcher, tokens

logger = structlog.get_logger(__name__)

# Every clarification ends with this line. resume_clarification() recognises a
# clarification turn in the session history by it, so keep the two in sync.
CLARIFICATION_MARKER = "Reply with the number or the name."
ALL_OPTION = "All of these"

_MAX_OPTIONS = 6
_LEXICAL_EXTRA = 8  # name-match candidates added per kind on top of vector top-k
_OPTION_LINE = re.compile(r"^\s*(\d+)\.\s+(.+?)\s*$")
_STATUSES = {"found", "no_entity", "not_found", "ambiguous"}


@dataclass(frozen=True)
class EntityCandidate:
    """One candidate entity (from vector search or name match)."""

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
        """Chosen entity names grouped by kind — the trace step's detail."""
        out: dict[str, list[str]] = {}
        for c in self.chosen:
            out.setdefault(c.kind, []).append(c.name)
        return out


# ── SQL-prompt sections ──────────────────────────────────────────────────


def like_literal(name: str) -> str:
    """Lower-case a name for a LIKE pattern: double quotes, drop ``%``."""
    return name.lower().replace("'", "''").replace("%", "")


def _quote(value: str) -> str:
    """A SQL string-literal body: single quotes doubled."""
    return value.replace("'", "''")


def _column_note(k: KindInfo) -> str:
    """Where the kind's column lives, when the entity table names it differently."""
    if k.table_column and k.table_column != k.sql_column:
        return f" (fact tables: {k.sql_column}; on the {k.table} table use {k.table_column})"
    return ""


def resolved_block(resolution: EntityResolution, config: EntityConfig) -> str:
    """SQL-prompt section naming the exact entities to filter on (status ``found``)."""
    if resolution.status != "found" or not resolution.chosen:
        return ""
    lines = [
        "## Resolved entities (authoritative)",
        "The question's entities were resolved against the configured entity tables. "
        "Filter on exactly these and nothing broader; do not rebuild the filters from the "
        "user's words. Apply every listed filter; an 'AND <column> = ...' part only on "
        "tables that have that column. Other attributes in parentheses (and any in the "
        "question's 'User clarification' line) only identify the entity: do NOT turn them "
        "into extra WHERE conditions unless the question asks to filter by them.",
    ]
    groups: dict[str, list[str]] = {}
    for c in resolution.chosen:
        k = config.kind(c.kind)
        if k is None:
            continue
        if k.is_group:
            groups.setdefault(c.kind, []).append(c.name)
            continue
        ident = ", ".join([f"{k.id_column} {c.key}", *(f"{a} {v}" for a, v in c.attrs)])
        attrs = dict(c.attrs)
        member = config.member_spec(c.kind)
        extra = "".join(
            f" AND {g.sql_column} = '{_quote(attrs[g.column])}'"
            for g in (member.groups if member else ())
            if g.filter_with_member and attrs.get(g.column)
        )
        lines.append(f"- {c.kind}: {c.name} ({ident}) → LOWER({k.sql_column}) LIKE '%{like_literal(c.name)}%'{extra}")
    for kind, names in groups.items():
        k = config.kind(kind)
        assert k is not None
        values = ", ".join(f"'{_quote(n)}'" for n in names)
        lines.append(f"- {kind}: {', '.join(names)} → {k.sql_column} IN ({values}){_column_note(k)}")
    lines.append(_answer_shape(config))
    return "\n".join(lines)


def fallback_rules(config: EntityConfig) -> str:
    """SQL-prompt rules for entity filters when nothing was resolved.

    Applies whenever a namespace has an entity config but the resolver did not
    produce a ``found`` result (no entity named, index missing, step skipped).
    """
    kinds = config.kind_infos()
    if not kinds:
        return ""
    lines = [
        "## Entity filters",
        "When you filter on one of these columns, use a case-insensitive LIKE — never = or "
        "IN, and this overrides any 'allowed values' list on them. Build <word> from the "
        "user's words: lower-case it, drop a trailing corporate suffix (ltd, limited, pvt, "
        "private, inc, corp, corporation, co) and double any single quote. For several, OR "
        "one LIKE per value inside parentheses.",
    ]
    for k in kinds:
        what = f"a {k.type} category such as a sector word" if k.is_group else f"a {k.type} name"
        lines.append(f"- {what}: LOWER({k.sql_column}) LIKE '%<word>%'{_column_note(k)}")
    lines.append("Never build <word> from a generic word alone (company, group, holdings, enterprises, india).")
    lines.append(_answer_shape(config))
    return "\n".join(lines)


def _answer_shape(config: EntityConfig) -> str:
    """Make listings readable: return names and the values, never bare ids."""
    names = ", ".join(dict.fromkeys(k.table_column if k.is_group else k.sql_column for k in config.kind_infos()))
    return (
        f"When the answer lists, ranks or compares entities, SELECT their name ({names}) together with "
        "the value used (e.g. the metric being ranked) and its period column — never return only an id column."
    )


# ── candidates ───────────────────────────────────────────────────────────


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
        attrs=tuple((str(a), str(v)) for a, v in attrs.items() if v),
        score=float(getattr(hit, "score", 0.0) or 0.0),
    )


def _merge(per_kind_vector: dict[str, list[EntityCandidate]], lexical: list[EntityCandidate]) -> list[EntityCandidate]:
    """Name matches first (they carry the user's exact words), then vector hits; deduped."""
    out: list[EntityCandidate] = []
    seen: set[tuple[str, str]] = set()
    kinds = list(dict.fromkeys([*per_kind_vector, *(c.kind for c in lexical)]))
    for kind in kinds:
        for c in [*(c for c in lexical if c.kind == kind), *per_kind_vector.get(kind, [])]:
            if (c.kind, c.key) not in seen:
                seen.add((c.kind, c.key))
                out.append(c)
    return out


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


def _numbered(candidates: list[EntityCandidate], *, offer_all: bool = False) -> str:
    lines = [f"{i}. {c.label}" for i, c in enumerate(candidates, start=1)]
    if offer_all:
        lines.append(f"{len(candidates) + 1}. {ALL_OPTION}")
    return "\n".join(lines)


class EntityResolver:
    """Candidates (vector ∪ name match) → LLM selection, one path for every kind."""

    def __init__(self, vector_client: Any, llm_client: Any):
        """Wire serve's shared clients (AOSS search and Bedrock)."""
        self._vector = vector_client
        self._llm = llm_client

    async def resolve(
        self,
        query: str,
        namespace: str,
        config: EntityConfig,
        *,
        index: str,
        matcher: NameMatcher | None = None,
        embedding: list[float] | None = None,
        model_id: str | None = None,
    ) -> EntityResolution:
        """Resolve the configured entities a question refers to. Never raises."""
        kinds = config.kind_infos()
        lexical: list[EntityCandidate] = []
        if matcher is not None:
            for e, score in matcher.match(query, {k.type: _LEXICAL_EXTRA for k in kinds}):
                lexical.append(
                    EntityCandidate(
                        kind=e.kind,
                        key=e.key,
                        name=e.name,
                        attrs=tuple((a, v) for a, v in e.attrs.items() if v),
                        score=score,
                    )
                )
        try:
            vector = embedding or await self._llm.embed(query)
            per_kind = await self._search(vector, namespace, index, kinds)
        except Exception as exc:
            logger.warning("entity_search_failed", namespace=namespace, error=str(exc)[:200])
            if not lexical:
                return EntityResolution(status="skipped", reason="similarity search failed")
            per_kind = {}
        picks = _picked_entities(query, matcher)
        candidates = _merge(per_kind, [*lexical, *(c for c in picks if c not in lexical)])
        if not candidates:
            return EntityResolution(status="skipped", reason="entity index empty")

        try:
            reply = await self._llm.converse(
                self._selection_prompt(query, candidates, kinds),
                max_tokens=1500,
                temperature=0.0,
                model_id=model_id,
            )
            choice = _parse_json_object(reply.text or "")
        except Exception as exc:
            logger.warning("entity_selection_failed", namespace=namespace, error=str(exc)[:200])
            choice = None
        if choice is None or choice.get("status") not in _STATUSES:
            return EntityResolution(status="skipped", reason="unusable selection reply")

        resolution = self._build_resolution(choice, candidates, config, query)
        if picks:
            # Options the user picked by exact name are certain — never left to the model.
            keep = [c for c in resolution.chosen if (c.kind, c.key) not in {(p.kind, p.key) for p in picks}]
            resolution = EntityResolution(status="found", chosen=[*picks, *keep])
        logger.info(
            "entity_resolved",
            namespace=namespace,
            status=resolution.status,
            entities=resolution.by_kind(),
            candidates=len(candidates),
            lexical=len(lexical),
        )
        return resolution

    async def _search(
        self, vector: list[float], namespace: str, index: str, kinds: list[KindInfo]
    ) -> dict[str, list[EntityCandidate]]:
        """Vector top-k per kind, in parallel; one retry (AOSS may be scaling up from zero)."""

        async def one(k: KindInfo) -> list[Any]:
            for attempt in range(2):
                try:
                    return await self._vector.search(
                        vector, namespace=namespace, top_k=k.top_k, index=index, entity_type=k.type
                    )
                except Exception:
                    if attempt:
                        raise
                    await asyncio.sleep(1.5)
            return []

        results = await asyncio.gather(*(one(k) for k in kinds))
        return {
            k.type: [c for h in hits if (c := _candidate_from_hit(h, k.type))]
            for k, hits in zip(kinds, results, strict=True)
        }

    @staticmethod
    def _selection_prompt(query: str, candidates: list[EntityCandidate], kinds: list[KindInfo]) -> str:
        names = ", ".join(k.type for k in kinds)
        groups = [k.type for k in kinds if k.is_group]
        lines = "\n".join(
            f"E{i}. [{c.kind}] {c.name}" + (" | " + ", ".join(f"{a}: {v}" for a, v in c.attrs) if c.attrs else "")
            for i, c in enumerate(candidates, start=1)
        )
        group_rules = ""
        if groups:
            g = groups[0]
            group_rules = (
                f"## {'/'.join(groups).capitalize()} names count as entities\n"
                f'- A question about companies "in", "under" or "of" a {g} NAMES that {g} '
                f'("top 5 by PAT in automobile {g}", "median PAT of IT software companies", '
                f'"pharma {g} revenue"). Resolve it like a company name — never "no_entity".\n'
                f'- One {g} candidate clearly matches → "found" with it.\n'
                f'- A broad word fits several {g} candidates (e.g. "automobile"/"automotive" fits '
                f'Two & Three Wheelers, Passenger Cars, Tractors, …) → "ambiguous" listing ALL of '
                f"those candidates; the user then picks one, several or all.\n"
                f'- Only a pure breakdown names no {g}: "by {g}", "per {g}", "each {g}", '
                f'"which {g} has the highest …".\n'
                f"- When the question also names a specific company, the company decides its own "
                f"{g}: choose the company (plus the {g} candidate equal to its own {g}, if listed) "
                f'and do NOT ask which {g} — e.g. "bajaj auto pat in automobile {g}" → found Bajaj Auto.\n\n'
            )
        clarification_rule = (
            "## Answer to an earlier clarification\n"
            "If the question contains 'User clarification:', the user is answering which entity "
            'they meant. Pick the candidate(s) their answer names and return "found" — do NOT '
            'return "no_entity" or ask again unless the answer matches no candidate. '
            "'all of: A; B; C' means choose every one of those.\n\n"
        )
        return (
            f"You resolve which named entities ({names}) a data question refers to.\n"
            "A search over the database's entity tables (by meaning and by name) returned the "
            "candidates below. Choose ONLY from these candidates — never invent one.\n\n"
            f"## Question\n<question>{query}</question>\n\n"
            f"## Candidates\n{lines}\n\n"
            "## Decide one status\n"
            '- "no_entity": the question names no specific entity at all (e.g. "top 10 companies '
            'by revenue", "total PAT of all companies"). The candidates are then irrelevant.\n'
            '- "found": every entity the question names matches exactly one candidate. Short '
            "names, acronyms (TCS → Tata Consultancy Services, L&T → Larsen & Toubro), missing "
            "suffixes (Ltd, Limited) and small typos still count as a match. Choose every entity "
            "the question names, of every kind.\n"
            '- "ambiguous": a name in the question fits two or more candidates and nothing in the '
            'question decides between them (e.g. "Bajaj" with Bajaj Auto and Bajaj Finance listed).\n'
            '- "not_found": the question names an entity that matches NO candidate.\n\n'
            f"{group_rules}"
            f"{clarification_rule}"
            "## Output — one JSON object, nothing else\n"
            "{\n"
            '  "status": "found" | "no_entity" | "ambiguous" | "not_found",\n'
            '  "chosen": ["E1"],                      // found: the chosen candidate labels\n'
            '  "mention": "bajaj",                    // ambiguous/not_found: the name as written\n'
            '  "ambiguous_candidates": ["E1", "E2"]   // ambiguous: the candidates it could be\n'
            "}"
        )

    @staticmethod
    def _build_resolution(
        choice: dict, candidates: list[EntityCandidate], config: EntityConfig, query: str
    ) -> EntityResolution:
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
        mention = str(choice.get("mention") or "").strip() or _mention_fallback(query)

        if status == "found":
            chosen = pick(choice.get("chosen"))
            if chosen:
                return EntityResolution(status="found", chosen=chosen)
            status = "not_found"  # "found" with no valid label → ask rather than guess

        if status == "ambiguous":
            options = pick(choice.get("ambiguous_candidates"))[:_MAX_OPTIONS]
            if len(options) >= 2:
                offer_all = all((k := config.kind(o.kind)) is not None and k.is_group for o in options)
                return EntityResolution(
                    status="ambiguous",
                    clarification=(
                        f"**{mention}** matches more than one entry. Which one did you mean?\n\n"
                        f"{_numbered(options, offer_all=offer_all)}\n\n{CLARIFICATION_MARKER}"
                    ),
                )
            status = "not_found"

        if status == "not_found":
            kinds = " or ".join(k.type for k in config.kind_infos())
            return EntityResolution(
                status="not_found",
                clarification=(
                    f"I couldn't find **{mention}** among this namespace's {kinds} entries. "
                    f"Did you mean one of these?\n\n{_numbered(candidates[: _MAX_OPTIONS - 1])}\n\n"
                    f"{CLARIFICATION_MARKER}"
                ),
            )

        return EntityResolution(status="no_entity")


_TRAILING_LABEL = re.compile(r"\s*\([^()]*\)\s*$")


def _picked_entities(query: str, matcher: NameMatcher | None) -> list[EntityCandidate]:
    """Entities a clarification reply names EXACTLY (option labels, "all of: A; B").

    Returns [] unless every picked part maps to exactly one entity, so a
    free-text reply ("bajaj auto") still goes to the model.
    """
    if matcher is None or "\nUser clarification:" not in query:
        return []
    answer = query.split("\nUser clarification:")[-1].strip()
    parts = [p.strip() for p in answer.removeprefix("all of:").split(";")] if answer.startswith("all of:") else [answer]
    out: list[EntityCandidate] = []
    for part in parts:
        hits = matcher.exact(part) or matcher.exact(_TRAILING_LABEL.sub("", part))
        if len(hits) != 1:
            return []
        e = hits[0]
        out.append(
            EntityCandidate(kind=e.kind, key=e.key, name=e.name, attrs=tuple((a, v) for a, v in e.attrs.items() if v))
        )
    return out


def _mention_fallback(query: str) -> str:
    """The user's own words when the LLM gave no mention (never the literal "that name")."""
    text = query.split("\nUser clarification:")[-1].strip()
    return text[:60] or "that name"


# ── resuming a clarification ─────────────────────────────────────────────

_ALL_REPLIES = {"all", "all of them", "all of these", "all of those", "both", "everything", "all the above"}
_NUMBERS_ONLY = re.compile(r"^(?:#|no\.?|option|options|number)?\s*\d+(?:\s*(?:,|&|and|/|\s)\s*\d+)*\s*[.)]?$")


def _options(clarification: str) -> dict[str, str]:
    return {m.group(1): m.group(2) for line in clarification.splitlines() if (m := _OPTION_LINE.match(line))}


def _option_names(options: dict[str, str]) -> set[str]:
    words: set[str] = set()
    for text in options.values():
        words |= set(tokens(text))
    return words


def _is_new_question(answer: str, original: str, options: dict[str, str]) -> bool:
    """True when the reply asks a fresh question rather than picking an option.

    "total revenue of grindell" after "total revenue of norton" repeats the
    question's own words (total, revenue) — that is a new question, not a pick.
    """
    entity_words = _option_names(options)
    ans = [w for w in tokens(answer) if w not in entity_words]
    orig = set(tokens(original)) - entity_words
    return len(tokens(answer)) >= 3 and len(set(ans) & orig) >= 2


def resume_clarification(query: str, history: list[dict[str, str]] | None) -> str | None:
    r"""Merge the user's reply into the question that triggered a clarification.

    When the previous assistant turn was an entity clarification (it ends with
    :data:`CLARIFICATION_MARKER`), the current ``query`` is the user's answer:

    - numbers ("2", "2.", "#2", "1,3", "1 and 3") pick those options;
    - "all" / "both" / the "All of these" option pick every listed option;
    - a reply that is itself a new question returns ``None`` (run it as asked);
    - anything else (a name) is used as written.

    Returns ``"<original question>\\nUser clarification: <answer>"`` or ``None``.
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
    # A resumed question can itself be a resumed question; keep only the root.
    original = original.split("\nUser clarification:")[0]

    options = _options(clarification)
    picks = {k: v for k, v in options.items() if v != ALL_OPTION}
    raw = query.strip()
    lowered = raw.lower().strip(" .!")
    answer = raw
    if _NUMBERS_ONLY.match(lowered):
        chosen = [options[n] for n in re.findall(r"\d+", lowered) if n in options]
        if any(c == ALL_OPTION for c in chosen):
            chosen = list(picks.values())
        if chosen:
            answer = chosen[0] if len(chosen) == 1 else "all of: " + "; ".join(chosen)
    elif lowered in _ALL_REPLIES and picks:
        answer = "all of: " + "; ".join(picks.values())
    elif _is_new_question(raw, original, options):
        return None
    return f"{original}\nUser clarification: {answer}"
