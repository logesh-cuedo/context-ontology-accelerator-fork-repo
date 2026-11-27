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
# Most already-resolved entities offered back as P labels. Ten covers a "top 10"
# answer whose every company a follow-up may then narrow; the cap falls on the
# oldest turn first, so the subject the user is on keeps its labels.
_MAX_PRIOR = 10
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
    def ident(self) -> tuple[str, str]:
        """What makes it the same entity, for dedupe."""
        return (self.kind, self.key)

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
    # True when the question leaned on an earlier turn for an entity rather than
    # naming it — the model answered with a P label. The SQL writer is given the
    # question alone, so it cannot tell "and its roce?" from a first question, and
    # answered the earlier one again; this is what tells it otherwise.
    follows_up: bool = False

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


def _named_entities(matcher: dict, names: list[str]) -> list[EntityCandidate]:
    """The entities these names identify, or ``[]`` unless EVERY name resolves to exactly one.

    Takes the names as a list, never as one joined string: a name is matched whole, so
    whatever punctuation it contains is part of it rather than a separator this function
    has to agree with its callers about. The all-or-nothing rule is what makes a caller
    able to trust the result — a partial list would silently narrow the question.

    Labels may carry the attribute we showed ("Bajaj Auto Ltd. (Automobile)"), so each
    name is tried as written and again with that suffix removed.
    """
    picks: list[EntityCandidate] = []
    for name in names:
        if not (name := name.strip()):
            continue
        hits = exact(matcher, name) or exact(matcher, _TRAILING_LABEL.sub("", name))
        if len(hits) != 1:
            return []
        picks.append(_from_name_entry(hits[0]))
    return picks


def _picked_answer(matcher: dict, answer: str) -> list[EntityCandidate]:
    """The entities named by a clarification answer, or ``[]`` unless every part is exact.

    ``answer`` is the text after "User clarification:" — one option label, or
    "all of: A; B". This is the ONLY format with a ``;`` convention, because it is the
    only one that arrives as prose the user produced; everything the system resolved
    itself is passed as a list to ``_named_entities`` instead.
    """
    parts = answer.removeprefix("all of:").split(";") if answer.startswith("all of:") else [answer]
    return _named_entities(matcher, parts)


def _conversation(matcher: dict | None, history: list[dict[str, str]] | None) -> tuple[str, list[EntityCandidate]]:
    """The conversation so far as (transcript, prior entities), newest turn last.

    Each question is rendered with the entities that turn resolved to, labelled P1,
    P2, …, so the model can see WHICH turn each label belongs to:

        1. revenue of tcs and infosys
           → resolved: P1 (Tata Consultancy Services Ltd.), P2 (Infosys Ltd.)
        2. revenue of pharmaceuticals sector     [most recent]
           → resolved: P3 (Pharmaceuticals)

    Pairing matters when the topic changes. A flat list of entities cannot show that
    the companies came from an abandoned question and the sector from the current one,
    so "roce for those" was as likely to be answered with the stale companies as with
    the sector the user had moved on to. The turn each label sits under is what makes
    that judgement possible.

    Questions come from the user turns and entities from the assistant turn that
    answered them: ``resolved_entities`` holds what resolution settled on rather than
    the words the question was asked in, which is how a misspelled name ("relaience")
    survives into the next turn. Each name is looked up in the catalog, so a P label
    resolves to that exact row — two entities can differ only by a suffix ("Tata Steel
    Ltd." and "Tata Steel Ltd. - (TATASTEELPP)"), and re-picking such a name by eye
    returns the twin the user already rejected.
    """
    if not history:
        return "", []
    # Walk forwards, pairing each question with the entities of the reply that follows.
    turns: list[tuple[str, list[str]]] = []
    for turn in history:
        role, content = turn.get("role"), str(turn.get("content") or "").strip()
        if role == "user":
            question, sep, answer = content.partition(CLARIFICATION_PREFIX)
            asked = question.strip()[:_HISTORY_CHARS]
            if not asked:
                continue
            # A resumed turn carries both the ambiguous words and the answer that
            # settled them. Left as written the words read as a question to resolve
            # again, and the same clarification comes back.
            if sep and (reply := answer.strip()):
                asked += f" (asked which entity; the user answered: {reply[:_HISTORY_CHARS]})"
            turns.append((asked, []))
        elif role == "assistant" and turns:
            # Only an actual list. The turn is typed as string-valued, and a string here
            # would be iterated character by character — each letter looked up as a
            # company name.
            stored = turn.get("resolved_entities")
            if isinstance(stored, list):
                turns[-1][1].extend(str(n) for n in stored)

    turns = turns[-_HISTORY_TURNS:]

    # Resolve each turn's names, newest turn first, so the cap falls on the subject the
    # user has moved on from rather than the one they are on: a first question naming
    # six companies otherwise filled every slot and the sector the follow-up was
    # actually about got no label at all.
    resolved: dict[int, list[EntityCandidate]] = {}
    allowed: set[tuple[str, str]] = set()
    for position in reversed(range(len(turns))):
        kept = []
        for name in turns[position][1]:
            # Exactly one match only: a name identifying several rows cannot be carried
            # without guessing which, and guessing is the twin mistake.
            hits = exact(matcher, name) if matcher is not None else []
            if len(hits) != 1:
                continue
            candidate = _from_name_entry(hits[0])
            if candidate.ident not in allowed:
                if len(allowed) >= _MAX_PRIOR:
                    continue
                allowed.add(candidate.ident)
            kept.append(candidate)
        resolved[position] = kept

    # Number in reading order, so P1 is the first label the transcript shows.
    prior: list[EntityCandidate] = []
    numbers: dict[tuple[str, str], int] = {}
    for position in sorted(resolved):
        for candidate in resolved[position]:
            if candidate.ident not in numbers:
                prior.append(candidate)
                numbers[candidate.ident] = len(prior)

    lines = []
    for position, (question, _) in enumerate(turns):
        recency = "     [most recent question]" if position == len(turns) - 1 else ""
        lines.append(f"{position + 1}. {question}{recency}")
        if labels := [f"P{numbers[c.ident]} ({c.name})" for c in resolved[position]]:
            lines.append(f"   → resolved: {', '.join(labels)}")
    return "\n".join(lines), prior


def _selection_prompt(
    query: str,
    candidates: list[EntityCandidate],
    kinds: list[KindInfo],
    history_block: str = "",
    tie_block: str = "",
    prior: list[EntityCandidate] | None = None,
) -> str:
    names = ", ".join(k.type for k in kinds)
    groups = [k.type for k in kinds if k.is_group]
    lines = "\n".join(
        f"E{i}. [{c.kind}] {c.name}" + (" | " + ", ".join(f"{a}: {v}" for a, v in c.attrs) if c.attrs else "")
        for i, c in enumerate(candidates, start=1)
    )
    prior_section = ""
    if prior:
        prior_lines = "\n".join(f"P{i}. [{c.kind}] {c.name}" for i, c in enumerate(prior, start=1))
        prior_section = (
            "## Entities this conversation already settled\n"
            "Options you may choose, exactly like the candidates below. The conversation "
            "above shows which question each one came from.\n"
            f"{prior_lines}\n\n"
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
    if prior:
        carry_over_rule = (
            "## Follow-up to an earlier question\n"
            "A question need not name its entity: it can point back at one this "
            "conversation already settled. Answer those with the P label, which IS that "
            "entity — never re-pick it from the E candidates, where the same name plus a "
            "suffix or code is a DIFFERENT entity with different data.\n"
            "- Points back without naming anybody (a word standing in for an entity, or "
            'a bare metric or period on its own: "and its roce?", "same for FY24") → '
            '"found" with the P label(s) it means.\n'
            '- Narrows what came before ("just the first two", "only the Tata ones", '
            '"drop Wipro") → "found" with ONLY the P labels that survive. Choose the '
            "subset the question asks for, not every P label.\n"
            '- Names an entity of its own AND points back ("compare it with X", "versus '
            'X", "and X too") → "found" with both: the E candidate it names and the P '
            "label it refers to.\n"
            "- Names its own entity and points back at nobody → ignore the P labels "
            "entirely. The earlier questions change nothing.\n"
            '- Asks about every entity ("top 10 by revenue") → "no_entity". It refers to '
            "nobody, so choose no P label.\n"
            "\n"
            "### The conversation can change topic\n"
            "A P label belongs to the question it is listed under, and those questions "
            "are not all about the same thing: the user can drop one subject and take up "
            "another. So choose by WHICH question the follow-up continues, not by what is "
            "available.\n"
            "- Default to the most recent question's entities. That is the subject the "
            "user is on, and a bare follow-up continues it.\n"
            "- An earlier question's entities are for a follow-up that reaches back to "
            'that question on purpose ("and the two companies from before", "compare it '
            'with the first one"). A follow-up that simply continues does NOT revive '
            "them.\n"
            "- Never mix entities from a question the user has moved on from with the "
            "current one. Filtering on both returns rows that satisfy neither — a sector "
            "AND two companies outside it is an empty answer.\n"
            "- Different kinds are a strong sign of a topic change: where the most recent "
            f"question settled a {'/'.join(k.type for k in kinds if k.is_group) or 'group'} "
            "and an earlier one settled companies, a bare follow-up means the recent one "
            "alone, unless the question names the earlier subject again.\n"
        )
    history_section = f"## This conversation so far\n{history_block}\n\n" if history_block else ""
    return (
        f"You resolve which named entities ({names}) a data question refers to.\n"
        "A search over the database's entity tables (by meaning and by name) returned the "
        "candidates below. Choose ONLY from the labels given to you — an E candidate, or a "
        "P entity this conversation already settled — and never invent one.\n"
        "The search is fuzzy, so most candidates are wrong: it matches on shared letters "
        "and will offer an entity whose name merely resembles an ordinary word of the "
        "question. A candidate counts only where the question is genuinely naming it — "
        "if the words that matched are being used as plain English, it is not a name, "
        "and no candidate they pulled in may be chosen.\n\n"
        f"{history_section}"
        f"## Question\n<question>{query}</question>\n\n"
        f"{prior_section}"
        f"## Candidates\n{lines}\n\n"
        f"{tie_block}"
        "## Decide one status\n"
        '- "no_entity": the question names no specific entity at all (e.g. "top 10 companies '
        'by revenue", "total PAT of all companies"). The candidates are then irrelevant.\n'
        '- "found": every entity the question names matches exactly ONE candidate. Short '
        "names, acronyms (TCS → Tata Consultancy Services, L&T → Larsen & Toubro), missing "
        "suffixes (Ltd, Limited) and small typos still count as a match. Choose every entity "
        "the question names, of every kind.\n"
        "  A typo is still only the word it misspells. Where the user writes ONE word and "
        "a candidate is that word plus further words of its own (a line of business, a "
        "place, a group member), the candidate is not what they wrote: the extra words are "
        "the part that picks one company out of a family sharing the first word, and the "
        "user supplied none of it. Such a candidate being the only one of its family listed "
        "is a fact about what the search returned, not about which the user meant — the "
        'others exist and simply did not score. Report "not_found" and name the word they '
        "wrote, so they are shown that family and choose within it.\n"
        '- "ambiguous": a name in the question fits two or more candidates and nothing in the '
        'question decides between them (e.g. "Bajaj" with Bajaj Auto and Bajaj Finance listed). '
        "This includes candidates that are the same name plus a suffix or code — those are "
        "SEPARATE entities with different data, so where nothing says which, ask; never pick "
        "one as the obvious reading, and never answer with both. What the user has already "
        "told you does say which: if the earlier questions below settle it, that is not "
        "ambiguous, so use their answer instead of asking it again. A question may name "
        "SEVERAL entities where only one of them is ambiguous — the status describes the "
        'whole question, so report "ambiguous" and ALSO put every entity you did settle '
        'in "chosen". Leaving them out drops them from the answer: a two-company question '
        "comes back about one company.\n"
        '- "not_found": the question names an entity that no candidate IS. A list that '
        "offers only near misses is not a match: one candidate left standing is not the "
        "same as one candidate that fits, and the search returns whatever is closest "
        "whether or not anything is close. Say not_found and name the entity in "
        '"mention" — the user is then shown the near misses and picks, which is right '
        "even when one of them turns out to be what they meant. Choosing it for them is "
        "wrong whenever it is not: the answer comes back as another company's numbers "
        "under the name the user asked for, and nothing on screen says so.\n\n"
        f"{group_rules}"
        f"{carry_over_rule}"
        f"{clarification_rule}"
        "## Output — one JSON object, nothing else\n"
        "{\n"
        '  "status": "found" | "no_entity" | "ambiguous" | "not_found",\n'
        '  "chosen": ["E1", "P1"],                // found: the chosen labels — an E '
        "candidate the question names, a P entity it points back at, or both; on "
        '"ambiguous" ALSO list every entity the question names that you DID settle, so '
        "the user is not asked about those again\n"
        '  "mention": "bajaj",                    // ambiguous/not_found: the name as written\n'
        '  "ambiguous_candidates": ["E1", "E2"],  // ambiguous: the candidates it could be\n'
        '  "ambiguous_by_mention": {              // ambiguous: EVERY unclear name, each '
        "with its own candidates. Fill this whenever the question leaves more than one "
        "name unclear, so the user is asked about all of them at once instead of being "
        "asked again on the next turn\n"
        '    "bajaj": ["E1", "E2"], "reliance": ["E3", "E4"]\n'
        "  },\n"
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
    # The conversation so far, and the entities it settled, numbered together: each
    # question is shown with the P labels it resolved to, so a follow-up is answered
    # from the question it continues rather than from whatever is on the list.
    history_block, prior = _conversation(matcher, history)

    # The user has just picked from the options we offered, and every part names exactly
    # one entity: the answer is settled. Searching and asking Bedrock again can only
    # re-derive it — or contradict the person who chose. A typed answer ("bajaj auto")
    # matches no name exactly, so it still goes the long way round and the model decides.
    if matcher is not None and CLARIFICATION_PREFIX in query and (picked := _picked_options(matcher, query)):
        # The pick IS the answer: it goes straight on, with nothing added by guesswork.
        #
        # The question may have named other entities besides the ambiguous one we asked
        # about ("tata steel and jsw steel ..."), and only the ambiguous name was put to
        # the user. Those come from the turn that asked: the model reported them as
        # settled, we showed them back ("keeping Tata Steel Ltd."), and they are in that
        # turn's resolved entities. Re-reading the original question with the name
        # matcher instead guessed at what it already knew, and the guess was wrong: it
        # scored the question's ordinary words against the catalog, so "revenue of
        # reliance" answered with Reliance Industries — the pick — plus Reliance
        # Communications, Reliance Home Finance and a stock index whose name contains
        # "revenue". A tie test was meant to hold those back and could not: identical
        # scores were compared pairwise, so the LAST of a tied run had nothing after it
        # to tie with and passed as a clear winner.
        keys = {c.ident for c in picked}
        picked += [c for c in prior if c.ident not in keys]
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
    #
    # Every tied cluster, not only one at the top of the kind. A question naming
    # several entities scores them on their own merits, so the ambiguous one sits
    # wherever its score puts it: "roce for relaience, infosysis and tcs" ranked TCS
    # 4.946 and Infosys 1.557 above four Reliance companies tied on 0.412, and a test
    # that compared only the top two saw 1.557 against 4.946, called it no tie, and let
    # the model pick a Reliance by itself — it chose Reliance Infrastructure, which
    # answered the misspelling "relaience" with zeroes from the wrong company.
    tied: dict[str, list[EntityCandidate]] = {}
    for kind in {c.kind for c in named}:
        ranked = [c for c in named if c.kind == kind]
        for pos, best in enumerate(ranked):
            if best.score <= 0:
                break
            cluster = [c for c in ranked[pos:] if c.score >= best.score * _TIE_RATIO]
            if len(cluster) >= 2:
                tied[kind] = cluster[:_MAX_OPTIONS]
                break
    tie_block = ""
    if tied:
        lines_ = "\n".join(f"- {kind}: " + ", ".join(c.name for c in cs) for kind, cs in tied.items())
        tie_block = (
            "## Equally good name matches\n"
            "These candidates matched the question's wording EQUALLY well — the name as "
            "written does not distinguish them:\n"
            f"{lines_}\n"
            "If the question names one of these and nothing in it decides which, that is "
            '"ambiguous" — list them in "ambiguous_candidates" and ask. Do not pick one '
            "because it is the largest or best known company; the user's words did not say "
            "so, and guessing returns another company's numbers as if they were theirs.\n\n"
        )

    # 2. Ask Bedrock to choose. Its reply should contain one JSON object.
    try:
        text = clients.converse(
            _selection_prompt(query, candidates, kinds, history_block, tie_block, prior),
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

    # 3. Read the choice. Only labels we offered are kept — E for a candidate from this
    #    question, P for an entity this conversation already settled. A P label resolves
    #    to the row that turn ended on, so a follow-up cannot drift onto a same-named
    #    twin; nothing else is accepted, so an invented label is simply dropped.
    by_label: dict[str, EntityCandidate] = {f"E{i}": c for i, c in enumerate(candidates, start=1)}
    by_label.update({f"P{i}": c for i, c in enumerate(prior, start=1)})

    def chosen_from(labels: object) -> list[EntityCandidate]:
        """The entities these labels name, in order, each once. Unknown labels are dropped.

        Deduped on ``ident``, not on the candidate itself: one entity can be offered
        both as an E candidate and as a P label, and those two instances carry
        different scores — so they compare unequal, and a question that names an
        entity it also points back at ("sun pharma roce" after a five-company answer)
        listed it twice, right through to two identical filters in the SQL prompt.
        """
        picked: dict[tuple[str, str], EntityCandidate] = {}
        for label in labels if isinstance(labels, list) else []:
            if (c := by_label.get(str(label).strip().upper())) is not None:
                picked.setdefault(c.ident, c)
        return list(picked.values())

    status = choice["status"]
    # If the reply did not say which name, use the user's own words.
    mention = str(choice.get("mention") or "").strip() or query.split(CLARIFICATION_PREFIX)[-1].strip()[:60]
    mention = mention or "that name"

    resolution = EntityResolution(status="no_entity")
    if status == "found":
        # Both sides of a comparison ("compare it with X") arrive in one list: the E
        # candidate the question names and the P entity it points back at. Ordered as
        # the model gave them, so "compare it with X" reads P first, X second.
        chosen = chosen_from(choice.get("chosen"))
        # A P label is an entity carried from an earlier turn, so choosing one is the
        # model saying this question continues that one.
        picked_prior = {c.ident for c in prior} & {c.ident for c in chosen}
        resolution = EntityResolution(status="found", chosen=chosen, follows_up=bool(picked_prior))
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
