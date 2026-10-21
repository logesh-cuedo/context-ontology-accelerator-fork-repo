# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Find out which companies or sectors a question is about.

Companies (an entity type) and sectors (a group) are handled the same way:

    1. Collect candidates: similarity search plus name matching (lexical.py).
    2. Ask Bedrock to pick from the candidates. The result is one of:
         found       the exact names are added to the SQL prompt
         no_entity   the question names nothing; the general filter rules are used
         not_found   ask the user, with numbered options
         ambiguous   ask the user which one, with numbered options (for sectors
                     there is also an "All of these" option)

If anything goes wrong (search error, no candidates, a reply we cannot read)
the status is "skipped" and Tier 2 runs with the general filter rules.

When we ask the user to choose, their NEXT message is the answer
(see resume_clarification): a number ("2", "2.", "1,3"), "all", or a name is
added to the original question. If the reply is a new question, it is run as one.
"""

from __future__ import annotations

import asyncio
import json
import re
from dataclasses import dataclass, field
from typing import Any

import structlog

from .config import EntityConfig, KindInfo
from .lexical import NameEntry, exact, match, tokens

logger = structlog.get_logger(__name__)

# Every "which one did you mean?" message ends with this line, so we can spot
# it in the chat history later (see resume_clarification).
CLARIFICATION_MARKER = "Reply with the number or the name."
ALL_OPTION = "All of these"
CLARIFICATION_PREFIX = "\nUser clarification:"  # the user's answer is added after this

_MAX_OPTIONS = 6
_NAME_MATCHES_PER_KIND = 8  # extra name matches per kind, on top of the search results
_STATUSES = {"found", "no_entity", "not_found", "ambiguous"}
_OPTION_LINE = re.compile(r"^\s*(\d+)\.\s+(.+?)\s*$")
_TRAILING_LABEL = re.compile(r"\s*\([^()]*\)\s*$")  # removes "(Automobile)" from "Bajaj Auto Ltd. (Automobile)"


@dataclass(frozen=True)
class EntityCandidate:
    """One possible match, from the similarity search or from name matching."""

    kind: str
    key: str
    name: str
    attrs: tuple[tuple[str, str], ...] = ()
    score: float = 0.0

    @property
    def label(self) -> str:
        """Text shown in the options list, e.g. ``Bajaj Auto Ltd. (Automobile)``."""
        return f"{self.name} ({self.attrs[0][1]})" if self.attrs else self.name


@dataclass
class EntityResolution:
    """The result: what was found, or what to ask the user."""

    status: str  # found | no_entity | not_found | ambiguous | skipped
    chosen: list[EntityCandidate] = field(default_factory=list)
    clarification: str = ""
    reason: str = ""

    @property
    def needs_clarification(self) -> bool:
        """True when we must stop and ask the user."""
        return self.status in ("not_found", "ambiguous")

    def by_kind(self) -> dict[str, list[str]]:
        """Chosen names grouped by kind, e.g. {"company": ["Bajaj Auto Ltd."]}."""
        names: dict[str, list[str]] = {}
        for c in self.chosen:
            names.setdefault(c.kind, []).append(c.name)
        return names


# ── text added to the SQL prompt ─────────────────────────────────────────


def like_literal(name: str) -> str:
    """Make a name safe for a LIKE pattern: lower case, double any quote, drop ``%``."""
    return name.lower().replace("'", "''").replace("%", "")


def _quote(value: str) -> str:
    """Make text safe inside SQL quotes by doubling any single quote."""
    return value.replace("'", "''")


def _column_note(k: KindInfo) -> str:
    """A note for when the entity table uses a different column name than the data tables."""
    if k.table_column and k.table_column != k.sql_column:
        return f" (fact tables: {k.sql_column}; on the {k.table} table use {k.table_column})"
    return ""


def _answer_shape(config: EntityConfig) -> str:
    """Tell the SQL writer to return names and values, not just id columns."""
    names = ", ".join(dict.fromkeys(k.table_column if k.is_group else k.sql_column for k in config.kind_infos()))
    return (
        f"When the answer lists, ranks or compares entities, SELECT their name ({names}) together with "
        "the value used (e.g. the metric being ranked) and its period column — never return only an id column."
    )


def resolved_block(resolution: EntityResolution, config: EntityConfig) -> str:
    """The SQL prompt text that lists the exact names to filter on (only when status is "found")."""
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
    group_values: dict[str, list[str]] = {}
    for c in resolution.chosen:
        k = config.kind(c.kind)
        if k is None:
            continue
        if k.is_group:
            group_values.setdefault(c.kind, []).append(c.name)
        else:  # a company: LIKE on its full name, plus its sector if the config says so
            ident = ", ".join([f"{k.id_column} {c.key}", *(f"{a} {v}" for a, v in c.attrs)])
            attrs = dict(c.attrs)
            member = config.member_spec(c.kind)
            extra = "".join(
                f" AND {g.sql_column} = '{_quote(attrs[g.column])}'"
                for g in (member.groups if member else ())
                if g.filter_with_member and attrs.get(g.column)
            )
            lines.append(
                f"- {c.kind}: {c.name} ({ident}) → LOWER({k.sql_column}) LIKE '%{like_literal(c.name)}%'{extra}"
            )
    for kind, names in group_values.items():  # one IN (...) list per group, e.g. all chosen sectors
        k = config.kind(kind)
        if k is None:
            continue
        values = ", ".join(f"'{_quote(n)}'" for n in names)
        lines.append(f"- {kind}: {', '.join(names)} → {k.sql_column} IN ({values}){_column_note(k)}")
    lines.append(_answer_shape(config))
    return "\n".join(lines)


def fallback_rules(config: EntityConfig) -> str:
    """The SQL prompt text with general filter rules, used when nothing was found."""
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


# ── helpers ──────────────────────────────────────────────────────────────


def _from_name_entry(e: NameEntry, score: float = 0.0) -> EntityCandidate:
    return EntityCandidate(e.kind, e.key, e.name, tuple((a, v) for a, v in e.attrs.items() if v), score)


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


def _numbered(candidates: list[EntityCandidate], offer_all: bool = False) -> str:
    lines = [f"{i}. {c.label}" for i, c in enumerate(candidates, start=1)]
    if offer_all:
        lines.append(f"{len(candidates) + 1}. {ALL_OPTION}")
    return "\n".join(lines)


async def resolve_entities(
    vector_client: Any,
    llm_client: Any,
    query: str,
    namespace: str,
    config: EntityConfig,
    *,
    index: str,
    matcher: dict | None = None,
    embedding: list[float] | None = None,
    model_id: str | None = None,
) -> EntityResolution:
    """Find the companies / sectors the question is about. Never raises an error."""
    kinds = config.kind_infos()

    # 1a. Names that share words with the question.
    by_name = []
    if matcher is not None:
        matches = match(matcher, query, {k.type: _NAME_MATCHES_PER_KIND for k in kinds})
        by_name = [_from_name_entry(e, score) for e, score in matches]

    # 1b. Similarity search for each kind, all at once. Each search is tried twice,
    #     because OpenSearch can be slow to wake up.
    async def search(k: KindInfo, vector: list[float]) -> list[Any]:
        try:
            return await vector_client.search(
                vector, namespace=namespace, top_k=k.top_k, index=index, entity_type=k.type
            )
        except Exception:
            await asyncio.sleep(1.5)
            return await vector_client.search(
                vector, namespace=namespace, top_k=k.top_k, index=index, entity_type=k.type
            )

    vector_hits: dict[str, list[EntityCandidate]] = {}
    try:
        vector = embedding or await llm_client.embed(query)
        results = await asyncio.gather(*(search(k, vector) for k in kinds))
    except Exception as exc:
        logger.warning("entity_search_failed", namespace=namespace, error=str(exc)[:200])
        if not by_name:
            return EntityResolution(status="skipped", reason="similarity search failed")
        results = []
    for k, hits in zip(kinds, results, strict=False):
        vector_hits[k.type] = []
        for hit in hits:  # each hit is a document saved by index_builder; skip it if it has no id
            meta = getattr(hit, "metadata", None) or {}
            key = str(meta.get("entity_uri") or "").strip()
            if not key:
                continue
            try:
                context = json.loads(meta.get("context_text") or "{}")
            except (TypeError, ValueError):
                context = {}
            name = str(context.get("name") or "").strip() or key
            attrs = context.get("attrs") if isinstance(context.get("attrs"), dict) else {}
            pairs = tuple((str(a), str(v)) for a, v in attrs.items() if v)
            vector_hits[k.type].append(
                EntityCandidate(k.type, key, name, pairs, float(getattr(hit, "score", 0.0) or 0.0))
            )

    # 1c. Names the user picked from our options (e.g. "Bajaj Auto Ltd." or "all of: A; B").
    #     Used only if every part matches exactly one name. A typed answer such as
    #     "bajaj auto" is left for Bedrock to decide.
    picks: list[EntityCandidate] = []
    if matcher is not None and CLARIFICATION_PREFIX in query:
        answer = query.split(CLARIFICATION_PREFIX)[-1].strip()
        parts = (
            [p.strip() for p in answer.removeprefix("all of:").split(";")] if answer.startswith("all of:") else [answer]
        )
        for part in parts:
            hits = exact(matcher, part) or exact(matcher, _TRAILING_LABEL.sub("", part))
            if len(hits) != 1:
                picks = []
                break
            picks.append(_from_name_entry(hits[0]))

    # 1d. Put the lists together, per kind: name matches first (they use the user's own
    #     words), then search results. No duplicates.
    named = [*by_name, *(p for p in picks if p not in by_name)]
    candidates: list[EntityCandidate] = []
    seen: set[tuple[str, str]] = set()
    for kind in dict.fromkeys([*vector_hits, *(c.kind for c in named)]):
        for c in [*(c for c in named if c.kind == kind), *vector_hits.get(kind, [])]:
            if (c.kind, c.key) not in seen:
                seen.add((c.kind, c.key))
                candidates.append(c)
    if not candidates:
        return EntityResolution(status="skipped", reason="entity index empty")

    # 2. Ask Bedrock to choose. Its reply should contain one JSON object.
    try:
        reply = await llm_client.converse(
            _selection_prompt(query, candidates, kinds), max_tokens=1500, temperature=0.0, model_id=model_id
        )
    except Exception as exc:
        logger.warning("entity_selection_failed", namespace=namespace, error=str(exc)[:200])
        return EntityResolution(status="skipped", reason="unusable selection reply")
    text = reply.text or ""
    start, end = text.find("{"), text.rfind("}")
    try:
        choice = json.loads(text[start : end + 1]) if start != -1 and end > start else None
    except ValueError:
        choice = None
    if not isinstance(choice, dict) or choice.get("status") not in _STATUSES:
        return EntityResolution(status="skipped", reason="unusable selection reply")

    # 3. Read the choice. Only labels that exist in our list (E1, E2, ...) are kept.
    by_label = {f"E{i}": c for i, c in enumerate(candidates, start=1)}

    def chosen_from(labels: object) -> list[EntityCandidate]:
        found = [by_label.get(str(label).strip().upper()) for label in (labels if isinstance(labels, list) else [])]
        return list(dict.fromkeys(c for c in found if c is not None))  # unknown labels dropped, no repeats

    status = choice["status"]
    # If the reply did not say which name, use the user's own words.
    mention = str(choice.get("mention") or "").strip() or query.split(CLARIFICATION_PREFIX)[-1].strip()[:60]
    mention = mention or "that name"
    resolution = EntityResolution(status="no_entity")
    if status == "found":
        chosen = chosen_from(choice.get("chosen"))
        resolution = EntityResolution(status="found", chosen=chosen)
        if not chosen:
            status = "not_found"  # "found" but no valid label: ask the user instead of guessing
    if status == "ambiguous":
        options = chosen_from(choice.get("ambiguous_candidates"))[:_MAX_OPTIONS]
        if len(options) >= 2:
            all_groups = all((info := config.kind(o.kind)) is not None and info.is_group for o in options)
            resolution = EntityResolution(
                status="ambiguous",
                clarification=(
                    f"**{mention}** matches more than one entry. Which one did you mean?\n\n"
                    f"{_numbered(options, offer_all=all_groups)}\n\n{CLARIFICATION_MARKER}"
                ),
            )
        else:
            status = "not_found"
    if status == "not_found":
        kind_names = " or ".join(k.type for k in kinds)
        resolution = EntityResolution(
            status="not_found",
            clarification=(
                f"I couldn't find **{mention}** among this namespace's {kind_names} entries. "
                f"Did you mean one of these?\n\n{_numbered(candidates[: _MAX_OPTIONS - 1])}\n\n"
                f"{CLARIFICATION_MARKER}"
            ),
        )

    # 4. Names the user picked from our options are always kept as chosen.
    if picks:
        picked_keys = {(p.kind, p.key) for p in picks}
        others = [c for c in resolution.chosen if (c.kind, c.key) not in picked_keys]
        resolution = EntityResolution(status="found", chosen=[*picks, *others])

    logger.info(
        "entity_resolved",
        namespace=namespace,
        status=resolution.status,
        entities=resolution.by_kind(),
        candidates=len(candidates),
        lexical=len(by_name),
    )
    return resolution


# ── reading the user's answer to our question ────────────────────────────

_ALL_REPLIES = {"all", "all of them", "all of these", "all of those", "both", "everything", "all the above"}
_NUMBERS_ONLY = re.compile(r"^(?:#|no\.?|option|options|number)?\s*\d+(?:\s*(?:,|&|and|/|\s)\s*\d+)*\s*[.)]?$")


def resume_clarification(query: str, history: list[dict[str, str]] | None) -> str | None:
    r"""Add the user's answer to the question we asked them about.

    If our last reply was a "which one did you mean?" message (it ends with
    CLARIFICATION_MARKER), then ``query`` is the user's answer:

    - numbers ("2", "2.", "#2", "1,3", "1 and 3") pick those options
    - "all", "both" or the "All of these" option pick every option
    - a new question returns None, so it is run as asked
    - anything else (a name) is used as typed

    Returns "<original question>\\nUser clarification: <answer>", or None.
    """
    # Our last reply must be a "which one did you mean?" message, about an earlier question.
    history = history or []
    roles = [str(turn.get("role")) for turn in history]
    if "assistant" not in roles:
        return None
    i = len(roles) - 1 - roles[::-1].index("assistant")
    clarification = str(history[i].get("content") or "")
    if CLARIFICATION_MARKER not in clarification:
        return None
    questions = [str(t.get("content") or "") for t in history[:i] if t.get("role") == "user"]
    if not questions or not questions[-1]:
        return None
    original = questions[-1].split(CLARIFICATION_PREFIX)[0]  # keep only the first question

    # The numbered options we offered: {"1": "Bajaj Auto Ltd. (Automobile)", ...}
    options = {m.group(1): m.group(2) for line in clarification.splitlines() if (m := _OPTION_LINE.match(line))}
    real_options = [text for text in options.values() if text != ALL_OPTION]
    reply = query.strip()
    normalised = reply.lower().strip(" .!")
    answer = reply
    if _NUMBERS_ONLY.match(normalised):
        chosen = [options[n] for n in re.findall(r"\d+", normalised) if n in options]
        if ALL_OPTION in chosen:
            chosen = real_options
        if chosen:
            answer = chosen[0] if len(chosen) == 1 else "all of: " + "; ".join(chosen)
    elif normalised in _ALL_REPLIES and real_options:
        answer = "all of: " + "; ".join(real_options)
    else:
        # Is it a new question instead of a pick? "total revenue of grindell" after
        # "total revenue of norton" repeats words of the question (total, revenue).
        option_words = {w for text in options.values() for w in tokens(text)}
        answer_words = {w for w in tokens(reply) if w not in option_words}
        question_words = set(tokens(original)) - option_words
        if len(tokens(reply)) >= 3 and len(answer_words & question_words) >= 2:
            return None
    return f"{original}{CLARIFICATION_PREFIX} {answer}"
