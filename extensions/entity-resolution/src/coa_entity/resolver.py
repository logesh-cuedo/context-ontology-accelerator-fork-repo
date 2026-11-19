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

import json
import re
import time
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
# How close a second name match must score to the best one to count as "equally
# good". 0.95 keeps it to genuine ties — several entities sharing the one word the
# user actually wrote — rather than merely close runners-up.
_TIE_RATIO = 0.95
_STATUSES = {"found", "no_entity", "not_found", "ambiguous"}
# How far back a follow-up may refer. Three turns covers "compare both" after the
# question that named the entities; more mostly adds entities the user has moved on
# from, which the model then carries into a question that is not about them.
_HISTORY_TURNS = 3
_HISTORY_CHARS = 300  # per turn, so one long pasted question cannot crowd out the prompt
_OPTION_LINE = re.compile(r"^\s*(\d+)\.\s+(.+?)\s*$")
_WORDS = re.compile(r"[a-z0-9]+")  # a name's words, for matching it inside a question
_WORDS_INDEX_KEY = "_by_words"  # where _words_index caches itself on the matcher
# A carried-back name must be at least this many words. One word ("reliance", "tata")
# names a house rather than a company and is rarely the whole of what was meant.
_CARRY_MIN_WORDS = 2
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


def _sql_literal(value: str) -> str:
    """``value`` as a SQL literal — unquoted when it is a number.

    Entity keys are text here, but the column behind them may not be: company_id is a
    bigint, and quoting it fails the query with "Cannot apply operator: bigint =
    varchar". A key of all digits is written bare; anything else is quoted.
    """
    return value if value.isdigit() else f"'{_quote(value)}'"


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
        "user's words. Use each filter EXACTLY as written — an id filter stays an id "
        "filter; never replace it with a LIKE on the name, which would also match a "
        "different company whose name merely starts the same. Apply every listed filter; "
        "an 'AND <column> = ...' part only on tables that have that column. Other "
        "attributes in parentheses (and any in the question's 'User clarification' line) "
        "only identify the entity: do NOT turn them into extra WHERE conditions unless "
        "the question asks to filter by them.",
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
            # Filter on the id, not the name. One name can be a prefix of another
            # ("Tata Steel Ltd." and "Tata Steel Ltd. - (TATASTEELPP)" are two companies),
            # so a LIKE on the chosen name silently matches the other one as well — and
            # after a clarification that is the very entity the user rejected. Resolution
            # has the id, so use it; the name stays in the line to read against.
            lines.append(f"- {c.kind}: {c.name} ({ident}) → {k.id_column} = {_sql_literal(c.key)}{extra}")
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


def _picked_options(matcher: dict, query: str) -> list[EntityCandidate]:
    """The entities the user picked from our options, or ``[]``.

    Only when EVERY part of the answer names exactly one entity — "Bajaj Auto Ltd." or
    "all of: A; B". A typed answer such as "bajaj auto" matches no name exactly, so the
    whole answer is left for Bedrock to decide rather than half-resolved here.
    """
    return _picked_answer(matcher, query.split(CLARIFICATION_PREFIX)[-1].strip())


def _picked_answer(matcher: dict, answer: str) -> list[EntityCandidate]:
    """The entities named by a clarification answer, or ``[]`` unless every part is exact.

    ``answer`` is the text after "User clarification:" — one option label, or
    "all of: A; B". Labels carry the attribute we showed ("Bajaj Auto Ltd. (Automobile)"),
    so each part is tried as written and again with that suffix removed.
    """
    parts = [p.strip() for p in answer.removeprefix("all of:").split(";")] if answer.startswith("all of:") else [answer]
    picks: list[EntityCandidate] = []
    for part in parts:
        hits = exact(matcher, part) or exact(matcher, _TRAILING_LABEL.sub("", part))
        if len(hits) != 1:
            return []
        picks.append(_from_name_entry(hits[0]))
    return picks


def _recent_turns(history: list[dict[str, str]] | None, matcher: dict | None = None) -> str:
    """The user's last few questions, oldest first, for a follow-up that refers back.

    User turns only: an assistant reply restates the names it answered about, which
    pulls the resolver towards its own previous answer rather than the question.
    """
    if not history:
        return ""
    asked = [str(t.get("content") or "").strip() for t in history if t.get("role") == "user"]
    # A resumed turn is stored as the original question plus the answer, so the question
    # it was built from is already in the list. Keep the resumed one — it carries the
    # name the user chose — and drop the bare copy, which only repeats the ambiguity.
    resumed = {q.split(CLARIFICATION_PREFIX)[0].strip() for q in asked if CLARIFICATION_PREFIX in q}
    kept = [q for q in asked if q and q not in resumed]

    def rendered(q: str) -> str:
        # A resumed turn still carries the ambiguous words the user was asked about
        # ("tata steel"), next to the answer that settled them. Left as written, those
        # words read as a question to resolve again, and the same clarification comes
        # back. Show the answer as the settled fact it is, and drop the question.
        question, sep, answer = q.partition(CLARIFICATION_PREFIX)
        if sep and (answer := answer.strip()):
            asked_about = question.strip()[:_HISTORY_CHARS]
            # Name the entity the answer resolves to, not the option text the user
            # clicked: where candidates differ only by a suffix, that text reads as a
            # match for either of them, and the rejected one comes back.
            picked = _picked_answer(matcher, answer) if matcher is not None else []
            settled = ", ".join(c.name for c in picked) or answer[:_HISTORY_CHARS]
            return f"- {asked_about}\n  (the user was asked which entity, and answered: {settled})"
        return f"- {q[:_HISTORY_CHARS]}"

    return "\n".join(rendered(q) for q in kept[-_HISTORY_TURNS:])


def _pinned_choice(matcher: dict, history: list[dict[str, str]] | None) -> list[EntityCandidate]:
    """The entities the user last chose by answering a clarification, or ``[]``.

    Read back by the same exact-name lookup that resolved the answer, so a follow-up
    reuses the very row the user picked. Asking the model again instead does not work:
    the candidates behind a clarification differ only by a suffix, so it re-picks the
    rejected twin or offers both — measured at 0/5 conversations kept on the right row.
    """
    for turn in reversed(history or []):
        if turn.get("role") != "user":
            continue
        _, sep, answer = str(turn.get("content") or "").partition(CLARIFICATION_PREFIX)
        if sep and (picked := _picked_answer(matcher, answer.strip())):
            return picked
    return []


def _words_index(matcher: dict) -> tuple[dict[str, tuple], int]:
    """Catalog names keyed by their words alone, with the longest name's word count.

    The stored keys keep their punctuation ("marg ltd."), which a question rarely
    reproduces exactly, so they are re-keyed on words alone ("marg ltd").
    Cached on the matcher itself, which is built once per index version and dropped with
    it, so the cache cannot outlive or disagree with the names it was built from.
    """
    if (cached := matcher.get(_WORDS_INDEX_KEY)) is not None:
        return cached
    whole: dict[str, list] = {}
    prefixes: dict[str, list] = {}
    for name, entries in matcher["by_name"].items():
        words = _WORDS.findall(name)
        if not words:
            continue
        whole.setdefault(" ".join(words), []).extend(entries)
        # Every leading run of the name as well: people write "reliance industries",
        # never "Reliance Industries Ltd.", so indexing the full name alone meant a
        # comparison almost never found what it referred back to. A prefix may name
        # several companies; only one that identifies exactly one is kept.
        for n in range(_CARRY_MIN_WORDS, len(words)):
            prefixes.setdefault(" ".join(words[:n]), []).extend(entries)
    # A name written out in full wins over being the start of a longer one: "Tata Steel
    # Ltd." IS one company, though it also begins "Tata Steel Ltd. - (TATASTEELPP)".
    index = {k: v for k, v in prefixes.items() if k not in whole}
    index.update(whole)
    one = {
        k: tuple(v)
        for k, v in index.items()
        if len({(e.kind, e.key) for e in v}) == 1 and len(k.split()) >= _CARRY_MIN_WORDS
    }
    built = (one, max((len(k.split()) for k in one), default=0))
    matcher[_WORDS_INDEX_KEY] = built
    return built


def _names_in(matcher: dict, text: str) -> list[tuple[str, tuple]]:
    """The catalog names written out in ``text``, as (name, entries).

    Matched on whole words, so punctuation and spacing differ freely ("Marg Ltd."
    matches "marg ltd pat") while "IOL" is not found inside "iolite". Every run of
    words in the question is looked up directly: testing all 8,334 names against the
    question instead costs about half a second on each comparison.
    """
    index, longest = _words_index(matcher)
    words = _WORDS.findall(text.lower())
    found: dict[str, tuple] = {}
    for i in range(len(words)):
        for j in range(i + 1, min(i + longest, len(words)) + 1):
            if entries := index.get(key := " ".join(words[i:j])):
                found[key] = tuple(entries)
    return list(found.items())


def _carried_choice(matcher: dict, history: list[dict[str, str]] | None) -> list[EntityCandidate]:
    """The entity an earlier question named outright, for a comparison to refer back to.

    Falls back to this only where no clarification settled the matter (``_pinned_choice``
    is tried first). A full name must appear verbatim in the earlier question, so the
    words are read as a name only when they ARE one. Scoring the old question with the
    fuzzy matcher instead would carry back whatever it resembled — "and the margin"
    scores Marg Ltd., "roce for same" scores Sameera Agro — which is the lookalike
    misread, arriving a turn late and attached to a question that looks answered.
    """
    for turn in reversed(history or []):
        # The answer turn records the names resolution settled on. Reading those is
        # the only way a misspelled name survives: the question beside it says
        # "relaience", which no lookup over the catalog can find, so the carry came
        # back empty and the follow-up answered about every company in the namespace.
        if turn.get("role") == "assistant":
            if named := _picked_answer(matcher, "; ".join(turn.get("resolved_entities") or [])):
                return named
            continue
        if turn.get("role") != "user":
            continue
        content = str(turn.get("content") or "")
        # A clarified turn is settled by the answer the user gave, not by the words they
        # were asked about: "tata steel" there is the ambiguous mention, and reading it
        # as a name would carry back the twin they were choosing between.
        question, sep, answer = content.partition(CLARIFICATION_PREFIX)
        if sep:
            if picked := _picked_answer(matcher, answer.strip()):
                return picked
            content = question
        found = _names_in(matcher, content)
        # One name inside another is one mention, not two: "Tata Steel Ltd." is a
        # substring of "Tata Steel Ltd. - (TATASTEELPP)", so a question about the
        # longer one contains both. Keep only names no other match contains — the
        # words the user actually wrote — or the twin that caused this bug carries
        # nothing at all.
        names = [n for n, _ in found]
        hits = [e for name, entries in found if not any(name != o and name in o for o in names) for e in entries]
        # One name only: two make the referent ambiguous, and guessing which the user
        # meant is the twin-picking mistake in another form.
        if len({(e.kind, e.key) for e in hits}) == 1:
            return [_from_name_entry(hits[0])]
    return []


def _selection_prompt(
    query: str,
    candidates: list[EntityCandidate],
    kinds: list[KindInfo],
    history_block: str = "",
    tie_block: str = "",
) -> str:
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
    carry_over_rule = ""
    if history_block:
        carry_over_rule = (
            "## Follow-up to an earlier question\n"
            "The earlier questions are context, NOT the question to answer.\n"
            "- A question that names an entity itself is about that entity. The earlier "
            "questions change nothing — never answer it with an entity from them.\n"
            "- Judge ONLY the words of the question itself. A question that names no "
            'entity in its own words is "no_entity", even where the earlier questions '
            "make plain who it is about — carrying that over is handled for you, and "
            "answering from the earlier questions instead gets the wrong one.\n"
            "- So a question that refers back instead of naming — a word standing in for "
            'an entity, or a bare metric or period on its own — is "no_entity" with '
            '"refers_back": true. Do not copy a name out of the earlier questions into '
            "the mention, and do not ask which entity it is.\n"
            '- A question that asks about every entity ("top 10 by revenue") is also '
            '"no_entity", but with "refers_back": false — it refers back to nobody.\n'
            '- A question may do BOTH: name one entity and refer back to another ("compare '
            'it with X", "versus X", "and X too"). That is "found" with ONLY the entity it '
            'names in "chosen", plus "refers_back": true. The one it refers back to is '
            "added for you — never copy that name out of the earlier questions.\n"
        )
    history_section = f"## Earlier questions in this conversation\n{history_block}\n\n" if history_block else ""
    return (
        f"You resolve which named entities ({names}) a data question refers to.\n"
        "A search over the database's entity tables (by meaning and by name) returned the "
        "candidates below. Choose ONLY from these candidates — never invent one.\n"
        "The search is fuzzy, so most candidates are wrong: it matches on shared letters "
        "and will offer an entity whose name merely resembles an ordinary word of the "
        "question. A candidate counts only where the question is genuinely naming it — "
        "if the words that matched are being used as plain English, it is not a name, "
        "and no candidate they pulled in may be chosen.\n\n"
        f"{history_section}"
        f"## Question\n<question>{query}</question>\n\n"
        f"## Candidates\n{lines}\n\n"
        f"{tie_block}"
        "## Decide one status\n"
        '- "no_entity": the question names no specific entity at all (e.g. "top 10 companies '
        'by revenue", "total PAT of all companies"). The candidates are then irrelevant.\n'
        '- "found": every entity the question names matches exactly ONE candidate. Short '
        "names, acronyms (TCS → Tata Consultancy Services, L&T → Larsen & Toubro), missing "
        "suffixes (Ltd, Limited) and small typos still count as a match. Choose every entity "
        "the question names, of every kind.\n"
        '- "ambiguous": a name in the question fits two or more candidates and nothing in the '
        'question decides between them (e.g. "Bajaj" with Bajaj Auto and Bajaj Finance listed). '
        "This includes candidates that are the same name plus a suffix or code — those are "
        "SEPARATE entities with different data, so where nothing says which, ask; never pick "
        "one as the obvious reading, and never answer with both. What the user has already "
        "told you does say which: if the earlier questions below settle it, that is not "
        "ambiguous, so use their answer instead of asking it again. A question may name "
        "SEVERAL entities where only one of them is ambiguous — the status describes the "
        "whole question, so report \"ambiguous\" and ALSO put every entity you did settle "
        'in "chosen". Leaving them out drops them from the answer: a two-company question '
        "comes back about one company.\n"
        '- "not_found": the question names an entity that matches NO candidate.\n\n'
        f"{group_rules}"
        f"{carry_over_rule}"
        f"{clarification_rule}"
        "## Output — one JSON object, nothing else\n"
        "{\n"
        '  "status": "found" | "no_entity" | "ambiguous" | "not_found",\n'
        '  "chosen": ["E1"],                      // found: the chosen candidate labels; on '
        '"ambiguous" ALSO list every entity the question names that you DID settle, so the '
        "user is not asked about those again\n"
        '  "mention": "bajaj",                    // ambiguous/not_found: the name as written\n'
        '  "ambiguous_candidates": ["E1", "E2"],  // ambiguous: the candidates it could be\n'
        '  "ambiguous_by_mention": {              // ambiguous: EVERY unclear name, each '
        "with its own candidates. Fill this whenever the question leaves more than one "
        "name unclear, so the user is asked about all of them at once instead of being "
        'asked again on the next turn\n'
        '    "bajaj": ["E1", "E2"], "reliance": ["E3", "E4"]\n'
        '  },\n'
        '  "refers_back": false                   // true if it refers to an earlier '
        'question\'s entity: on "no_entity" rather than asking about every entity, on '
        '"found" when it ALSO names one of its own (a comparison)\n'
        "}"
    )


def _numbered(candidates: list[EntityCandidate], offer_all: bool = False, start: int = 1) -> str:
    """The numbered options list, continuing from ``start``.

    ``start`` carries the numbering across blocks, so two ambiguous names asked in
    one message give the user one unbroken set of numbers to answer with rather than
    two lists both beginning at 1.
    """
    lines = [f"{i}. {c.label}" for i, c in enumerate(candidates, start=start)]
    if offer_all:
        lines.append(f"{start + len(candidates)}. {ALL_OPTION}")
    return "\n".join(lines)


def resolve_entities(
    clients: Any,
    query: str,
    namespace: str,
    config: EntityConfig,
    *,
    index: str,
    matcher: dict | None = None,
    embedding: list[float] | None = None,
    model_id: str | None = None,
    history: list[dict[str, str]] | None = None,
) -> EntityResolution:
    """Find the companies / sectors the question is about. Never raises an error.

    ``clients`` is a ``clients.Clients`` (blocking calls): run this in a worker thread.
    """
    kinds = config.kind_infos()
    history_block = _recent_turns(history, matcher)

    # The user has just picked from the options we offered, and every part names exactly
    # one entity: the answer is settled. Searching and asking Bedrock again can only
    # re-derive it — or contradict the person who chose. A typed answer ("bajaj auto")
    # matches no name exactly, so it still goes the long way round and the model decides.
    if matcher is not None and CLARIFICATION_PREFIX in query and (picked := _picked_options(matcher, query)):
        # The question may have named other companies besides the ambiguous one we asked
        # about ("tata steel and jsw steel ..."). Only the ambiguous name was put to the
        # user, so returning their pick alone answered a two-company question with one.
        # Any name in the question that identifies exactly one entity is added back; an
        # ambiguous name is absent from that index, which is why it was asked about.
        keys = {(c.kind, c.key) for c in picked}
        original = query.split(CLARIFICATION_PREFIX)[0]
        for _, entries in _names_in(matcher, original):
            entry = entries[0]
            if (entry.kind, entry.key) not in keys:
                keys.add((entry.kind, entry.key))
                picked.append(_from_name_entry(entry))
        # ``_names_in`` finds only names written out in full, so a company the user
        # named by its acronym ("tcs") was not added back and the answer came out
        # about the clarified company alone. Scoring the original question finds it
        # the same way the main path does. Only a clear winner is taken: a run-away
        # top score with nothing close behind it is one entity the question names
        # outright, whereas several near-equal scores are the ambiguity that was
        # asked about — and re-adding those would answer with the very companies
        # the user just declined.
        scored = sorted(match(matcher, original, {k.type: _MAX_OPTIONS for k in kinds}), key=lambda t: -t[1])
        for pos, (entry, score) in enumerate(scored):
            runner_up = scored[pos + 1][1] if pos + 1 < len(scored) else 0.0
            if (entry.kind, entry.key) in keys or runner_up >= score * _TIE_RATIO:
                continue
            keys.add((entry.kind, entry.key))
            picked.append(_from_name_entry(entry))
        logger.info("entity_clarification_picked", namespace=namespace, entities=[c.name for c in picked])
        return EntityResolution(status="found", chosen=picked)

    # 1a. Names that share words with the question. A follow-up ("roce for same") names
    #     nobody, so the earlier questions are searched too and the model has the entity
    #     they refer back to among its candidates. Separate lookups, then the union:
    #     searched as one string the earlier questions outweigh the question itself, and
    #     one that does name a company takes no candidate slot of its own.
    by_name = []
    if matcher is not None:
        per_kind = {k.type: _NAME_MATCHES_PER_KIND for k in kinds}
        found = [_from_name_entry(e, score) for e, score in match(matcher, query, per_kind)]
        if history_block:
            found += [_from_name_entry(e, score) for e, score in match(matcher, history_block, per_kind)]
        by_name = list({(c.kind, c.key): c for c in found}.values())

    # 1b. Similarity search for each kind, one after the other. Each search is tried
    #     twice, because OpenSearch can be slow to wake up.
    vector_hits: dict[str, list[EntityCandidate]] = {}
    try:
        vector = embedding or clients.embed(query)
        results = []
        for k in kinds:
            try:
                hits = clients.search(vector, index=index, top_k=k.top_k, entity_type=k.type)
            except Exception:
                time.sleep(1.5)
                hits = clients.search(vector, index=index, top_k=k.top_k, entity_type=k.type)
            results.append(hits)
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

    # (A clarification answer that names its entities exactly returned above; one that
    #  does not resolves through the candidates below, like any other question.)

    # 1c. Put the lists together, per kind: name matches first (they use the user's own
    #     words), then search results. No duplicates.
    #
    # Reranked, not merely concatenated. The two lists score on scales that cannot be
    # compared — lexical is an idf-weighted sum scaled by name coverage, unbounded;
    # vector is a cosine in 0..1 — so a fused number would be meaningless. Instead each
    # list is sorted by its own score and a candidate found by BOTH is lifted to the
    # front of its kind: agreement between an independent name match and a semantic one
    # is the strongest signal available, and it is the one thing concatenation threw
    # away. Previously the scores were computed and then discarded, so the model saw a
    # flat list in which a strong match and a stray lookalike were indistinguishable.
    named = sorted(by_name, key=lambda c: -c.score)
    both = {(c.kind, c.key) for c in named} & {(c.kind, c.key) for hits in vector_hits.values() for c in hits}
    candidates: list[EntityCandidate] = []
    seen: set[tuple[str, str]] = set()
    for kind in dict.fromkeys([*vector_hits, *(c.kind for c in named)]):
        ranked = [
            *(c for c in named if c.kind == kind and (c.kind, c.key) in both),
            *(c for c in named if c.kind == kind and (c.kind, c.key) not in both),
            *sorted(vector_hits.get(kind, []), key=lambda c: -c.score),
        ]
        for c in ranked:
            if (c.kind, c.key) not in seen:
                seen.add((c.kind, c.key))
                candidates.append(c)
    if not candidates:
        return EntityResolution(status="skipped", reason="entity index empty")

    # A name the user misspelled or shortened can match several entities on the SAME
    # single word ("reliance" in Reliance Industries, Power, Infrastructure, …). Those
    # score identically, so which one wins is decided by the sort's tiebreak — name
    # length — which is arbitrary and not reproducible across runs. Measured: one
    # question resolved to four different companies on four identical attempts, one of
    # them a merged shell with no recent data. Where the top name matches of a kind are
    # within a hair of each other, the question genuinely does not say which, so the
    # model is told to ask rather than to pick the one that sorted first.
    tied: dict[str, list[EntityCandidate]] = {}
    for kind in {c.kind for c in named}:
        ranked = [c for c in named if c.kind == kind]
        if len(ranked) >= 2 and ranked[0].score > 0 and ranked[1].score >= ranked[0].score * _TIE_RATIO:
            tied[kind] = [c for c in ranked if c.score >= ranked[0].score * _TIE_RATIO][:_MAX_OPTIONS]
    tie_block = ""
    if tied:
        lines_ = "\n".join(
            f"- {kind}: " + ", ".join(c.name for c in cs) for kind, cs in tied.items()
        )
        tie_block = (
            "## Equally good name matches\n"
            "These candidates matched the question's wording EQUALLY well — the name as "
            "written does not distinguish them:\n"
            f"{lines_}\n"
            'If the question names one of these and nothing in it decides which, that is '
            '"ambiguous" — list them in "ambiguous_candidates" and ask. Do not pick one '
            "because it is the largest or best known company; the user's words did not say "
            "so, and guessing returns another company's numbers as if they were theirs.\n\n"
        )

    # 2. Ask Bedrock to choose. Its reply should contain one JSON object.
    try:
        text = clients.converse(
            _selection_prompt(query, candidates, kinds, history_block, tie_block),
            max_tokens=1500,
            temperature=0.0,
            model_id=model_id,
        )
    except Exception as exc:
        logger.warning("entity_selection_failed", namespace=namespace, error=str(exc)[:200])
        return EntityResolution(status="skipped", reason="unusable selection reply")
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

    # A follow-up names nobody of its own, so its entity is the one the user last chose
    # — already settled, not a judgement to make again. Resolving it afresh instead does
    # not work: the candidates behind a clarification differ only by a suffix, so a
    # second pass re-picks the rejected twin, returns both, or latches onto a lookalike
    # the fuzzy search pulled in. Measured at 0/5 conversations kept on the chosen row.
    #
    # Only a question that names nobody is carried; one that names an entity is that
    # entity's question, whatever came before. Both readings are the model's, because a
    # name match on the question alone cannot tell them apart — it scores a follow-up's
    # ordinary words against a real company above some questions that do name one.
    if (
        matcher is not None
        and status == "no_entity"
        and choice.get("refers_back") is True
        # A clarification settles it where there was one; otherwise the earlier turn
        # does, read from what it RESOLVED to rather than from the words it was asked
        # in. Only the clarified reading was consulted here, so a question answered
        # without asking — including one whose name was misspelled — left the follow-up
        # with nobody to carry, and it answered about every company in the namespace.
        and (pinned := _pinned_choice(matcher, history) or _carried_choice(matcher, history))
    ):
        logger.info("entity_pinned", namespace=namespace, status=status, entities=[c.name for c in pinned])
        return EntityResolution(status="found", chosen=pinned)

    resolution = EntityResolution(status="no_entity")
    if status == "found":
        chosen = chosen_from(choice.get("chosen"))
        # A comparison names one entity and refers back to another ("compare it with X").
        # The named one is the model's; the other is the one already settled, so it is
        # carried the same way a bare follow-up carries it. Added, never substituted —
        # dropping it answered a two-company question with one company.
        if matcher is not None and chosen and choice.get("refers_back") is True:
            keys = {(c.kind, c.key) for c in chosen}
            # Whichever came last: a clarification the user answered, or a question that
            # named its entity outright. Preferring the clarification regardless carried
            # it back long after the user had moved on to another company.
            earlier = _carried_choice(matcher, history)
            if carried := [c for c in earlier if (c.kind, c.key) not in keys]:
                chosen = [*carried, *chosen]
                logger.info("entity_carried_back", namespace=namespace, entities=[c.name for c in chosen])
        resolution = EntityResolution(status="found", chosen=chosen)
        if not chosen:
            status = "not_found"  # "found" but no valid label: ask the user instead of guessing
    if status == "ambiguous":
        # A question can leave SEVERAL names ambiguous at once ("pat for bajaj and
        # reliance"). "ambiguous_candidates" is one flat list and "mention" one name,
        # so the model had to choose which to ask about and the other was guessed or
        # dropped. "ambiguous_by_mention" groups the candidates under the name each
        # belongs to, so every unresolved name is asked in the same message; the flat
        # field stays the fallback for a reply that does not use the grouped one.
        groups: list[tuple[str, list[EntityCandidate]]] = []
        raw_groups = choice.get("ambiguous_by_mention")
        if isinstance(raw_groups, dict):
            for name, labels in raw_groups.items():
                opts = chosen_from(labels)[:_MAX_OPTIONS]
                if len(opts) >= 2:
                    groups.append((str(name).strip() or mention, opts))
        options = chosen_from(choice.get("ambiguous_candidates"))[:_MAX_OPTIONS]
        if len(groups) > 1:
            asked = {(o.kind, o.key) for _, opts in groups for o in opts}
            settled = [c for c in chosen_from(choice.get("chosen")) if (c.kind, c.key) not in asked]
            kept = f" (keeping {', '.join(c.name for c in settled)})" if settled else ""
            blocks, offset = [], 0
            for name, opts in groups:
                all_groups = all((info := config.kind(o.kind)) is not None and info.is_group for o in opts)
                blocks.append(
                    f"**{name}** matches more than one entry:\n\n"
                    f"{_numbered(opts, offer_all=all_groups, start=offset + 1)}"
                )
                offset += len(opts) + (1 if all_groups else 0)
            resolution = EntityResolution(
                status="ambiguous",
                chosen=settled,
                clarification=(
                    f"Two names in your question match more than one entry{kept}. "
                    f"Which did you mean?\n\n" + "\n\n".join(blocks) + f"\n\n{CLARIFICATION_MARKER}"
                ),
            )
        elif len(options) >= 2:
            all_groups = all((info := config.kind(o.kind)) is not None and info.is_group for o in options)
            # A question can name one entity plainly and another ambiguously
            # ("tax for relaience and tcs"): the status is a single value for the
            # WHOLE question, so the model reports "ambiguous" and its "chosen"
            # list still holds the entities it did settle. Reading only the
            # ambiguous options dropped those silently — a two-company question
            # came back resolved to one. Carry them on the resolution (the
            # options are never among them) and name them in the question we ask,
            # so the user can see nothing was lost while they pick.
            asked_keys = {(o.kind, o.key) for o in options}
            settled = [c for c in chosen_from(choice.get("chosen")) if (c.kind, c.key) not in asked_keys]
            kept = f" (keeping {', '.join(c.name for c in settled)})" if settled else ""
            resolution = EntityResolution(
                status="ambiguous",
                chosen=settled,
                clarification=(
                    f"**{mention}** matches more than one entry{kept}. Which one did you mean?\n\n"
                    f"{_numbered(options, offer_all=all_groups)}\n\n{CLARIFICATION_MARKER}"
                ),
            )
        else:
            status = "not_found"
    if status == "not_found":
        kind_names = " or ".join(k.type for k in kinds)
        # Offer what the unfound NAME resembles, not what the whole question matched.
        # The candidate list is scored over every word, and an ordinary word of the
        # question can outrank the name itself — a misspelled "reliance" loses to the
        # "can" in "can you give me ...", which matches "Can Fin Homes". Re-searching
        # the mention alone drops the question's wording and leaves the name's own
        # nearest spellings, which is what "did you mean?" is asking.
        near = candidates
        if matcher is not None and (hits := match(matcher, mention, {k.type: _MAX_OPTIONS for k in kinds})):
            near = [_from_name_entry(e, score) for e, score in hits]
        resolution = EntityResolution(
            status="not_found",
            clarification=(
                f"I couldn't find **{mention}** among this namespace's {kind_names} entries. "
                f"Did you mean one of these?\n\n{_numbered(near[: _MAX_OPTIONS - 1])}\n\n"
                f"{CLARIFICATION_MARKER}"
            ),
        )

    logger.info(
        "entity_resolved",
        namespace=namespace,
        status=resolution.status,
        lexical_names=[f"{c.name}:{c.score:.3f}" for c in named[:8]],
        tied=list(tied),
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
