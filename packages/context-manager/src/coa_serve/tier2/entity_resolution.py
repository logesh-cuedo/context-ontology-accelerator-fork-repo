# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Entity resolution for Tier 2: which company / sector is the user asking about?

Flow (one request):

    user query ──► similarity search over the namespace's entity index
                   (companies + sectors, built from the sectors table on
                   ontology publish — lambda/entity-index)
               ──► top-k candidates ──► LLM picks from the candidates
               ──► found       → exact entities handed to SQL generation
                   no_entity   → the question names no company/sector; continue
                   not_found   → ask the user for clarification
                   ambiguous   → ask the user which candidate they meant

The resolver is fail-open: no index configured, an empty index, a search error,
or an unparseable LLM reply all return ``status="skipped"`` and Tier 2 runs
exactly as it did before this step existed.

A clarification turn is resumed on the user's NEXT message through the session
history (see :func:`resume_clarification`): the reply is merged with the original
question, so the whole pipeline re-runs on the question the user actually asked.
"""

from __future__ import annotations

import asyncio
import json
import re
from dataclasses import dataclass, field

import structlog
from coa_common import entity_vector_index_name

from ..clients.base import LLMClient, VectorClient, VectorHit

logger = structlog.get_logger(__name__)

# Entity types written by scripts/index_entities.py into the ``entity_type`` field.
ENTITY_TYPE_COMPANY = "company"
ENTITY_TYPE_SECTOR = "sector"

# Every clarification ends with this line. resume_clarification() recognises a
# clarification turn in the session history by it, so keep the two in sync.
CLARIFICATION_MARKER = "Reply with the number or the name."

_DEFAULT_TOP_K_COMPANIES = 10
_DEFAULT_TOP_K_SECTORS = 5
# Options listed in a clarification — enough to contain the right one without
# burying it.
_MAX_OPTIONS = 5
_OPTION_LINE = re.compile(r"^\s*(\d+)\.\s+(.+?)\s*$")

_STATUSES = {"found", "no_entity", "not_found", "ambiguous"}


@dataclass(frozen=True)
class EntityCandidate:
    """One company or sector returned by the similarity search."""

    kind: str  # ENTITY_TYPE_COMPANY | ENTITY_TYPE_SECTOR
    key: str  # company_id for a company, the sector name for a sector
    name: str  # company_name / sector name
    sector: str = ""
    subsector: str = ""
    score: float = 0.0

    @property
    def label(self) -> str:
        """Human-readable option text, e.g. ``Bajaj Auto Ltd. (Automobile)``."""
        if self.kind == ENTITY_TYPE_COMPANY and self.sector:
            return f"{self.name} ({self.sector})"
        return self.name


@dataclass
class EntityResolution:
    """Outcome of one resolution: what was found, or what to ask the user."""

    status: str  # found | no_entity | not_found | ambiguous | skipped
    companies: list[EntityCandidate] = field(default_factory=list)
    sectors: list[EntityCandidate] = field(default_factory=list)
    clarification: str = ""
    reason: str = ""

    @property
    def needs_clarification(self) -> bool:
        """True when the pipeline must stop and ask the user."""
        return self.status in ("not_found", "ambiguous")

    def prompt_block(self) -> str:
        """The resolved entities as an authoritative block for the SQL prompt.

        Empty unless status is ``found``. Company filters keep the
        case-insensitive LIKE rule, but on the FULL resolved name, so "bajaj"
        no longer sweeps in every Bajaj group company.
        """
        if self.status != "found" or not (self.companies or self.sectors):
            return ""
        lines = [
            "The user's entities were resolved against the sectors table. These are the "
            "EXACT entities the question is about — filter on them and nothing broader:"
        ]
        for c in self.companies:
            lines.append(
                f"- company: {c.name} (company_id {c.key}"
                + (f", sector {c.sector}" if c.sector else "")
                + f") → LOWER(company_name) LIKE '%{_like_literal(c.name)}%'"
            )
        for s in self.sectors:
            lines.append(f"- sector: {s.name} → filter the sector column on this exact value")
        return "\n".join(lines)


def _like_literal(name: str) -> str:
    """Lower-case a resolved name for a LIKE pattern: double quotes, drop ``%``.

    ``_`` is left as-is — escaping it needs an ``ESCAPE`` clause the dialects
    spell differently, and a one-character wildcard inside a full company name
    cannot widen the match to another company in practice.
    """
    return name.lower().replace("'", "''").replace("%", "")


def _candidate_from_hit(hit: VectorHit, kind: str) -> EntityCandidate | None:
    """Shape a vector hit written by index_entities.py into a candidate."""
    meta = hit.metadata or {}
    key = str(meta.get("entity_uri") or "").strip()
    if not key:
        return None
    try:
        ctx = json.loads(meta.get("context_text") or "{}")
    except (TypeError, ValueError):
        ctx = {}
    name = str(ctx.get("company_name") or "").strip() if kind == ENTITY_TYPE_COMPANY else key
    if not name:
        return None
    return EntityCandidate(
        kind=kind,
        key=key,
        name=name,
        sector=str(ctx.get("cd_sector") or "").strip(),
        subsector=str(ctx.get("cd_subsector") or "").strip(),
        score=float(hit.score or 0.0),
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

    def __init__(
        self,
        vector_client: VectorClient,
        llm_client: LLMClient,
        index_prefix: str,
        *,
        top_k_companies: int = _DEFAULT_TOP_K_COMPANIES,
        top_k_sectors: int = _DEFAULT_TOP_K_SECTORS,
    ):
        """Wire the shared vector + LLM clients.

        Args:
            vector_client: Serve's AOSS client (search-only is enough).
            llm_client: Bedrock client used for the selection call.
            index_prefix: ``OSS_ONTOLOGY_INDEX`` — the per-namespace entity index
                name is derived from it. Empty disables the resolver.
            top_k_companies: Company candidates fetched per question.
            top_k_sectors: Sector candidates fetched per question.
        """
        self._vector = vector_client
        self._llm = llm_client
        self._index_prefix = index_prefix
        self._top_k_companies = max(1, top_k_companies)
        self._top_k_sectors = max(1, top_k_sectors)

    def index_name(self, namespace: str) -> str:
        """The AOSS index holding this namespace's companies and sectors."""
        return entity_vector_index_name(self._index_prefix, namespace)

    async def resolve(
        self,
        query: str,
        namespace: str,
        *,
        embedding: list[float] | None = None,
        model_id: str | None = None,
    ) -> EntityResolution:
        """Resolve the companies/sectors a question refers to. Never raises."""
        if not self._index_prefix:
            return EntityResolution(status="skipped", reason="no entity index configured")
        try:
            vector = embedding or await self._llm.embed(query)
            companies, sectors = await self._similarity_search(vector, namespace)
        except Exception as exc:
            logger.warning("entity_search_failed", namespace=namespace, error=str(exc)[:200])
            return EntityResolution(status="skipped", reason="similarity search failed")
        if not companies and not sectors:
            # Index not built for this namespace — nothing to resolve against.
            return EntityResolution(status="skipped", reason="entity index empty")

        try:
            reply = await self._llm.converse(
                self._selection_prompt(query, companies, sectors),
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

        resolution = self._build_resolution(choice, companies, sectors)
        logger.info(
            "entity_resolved",
            namespace=namespace,
            status=resolution.status,
            companies=[c.name for c in resolution.companies],
            sectors=[s.name for s in resolution.sectors],
            candidates=len(companies) + len(sectors),
        )
        return resolution

    async def _similarity_search(
        self, vector: list[float], namespace: str
    ) -> tuple[list[EntityCandidate], list[EntityCandidate]]:
        """Top-k companies and top-k sectors for the query vector, in one round-trip each."""
        index = self.index_name(namespace)
        company_hits, sector_hits = await asyncio.gather(
            self._vector.search(
                vector,
                namespace=namespace,
                top_k=self._top_k_companies,
                index=index,
                entity_type=ENTITY_TYPE_COMPANY,
            ),
            self._vector.search(
                vector,
                namespace=namespace,
                top_k=self._top_k_sectors,
                index=index,
                entity_type=ENTITY_TYPE_SECTOR,
            ),
        )
        companies = [c for h in company_hits if (c := _candidate_from_hit(h, ENTITY_TYPE_COMPANY))]
        sectors = [s for h in sector_hits if (s := _candidate_from_hit(h, ENTITY_TYPE_SECTOR))]
        return companies, sectors

    @staticmethod
    def _selection_prompt(query: str, companies: list[EntityCandidate], sectors: list[EntityCandidate]) -> str:
        company_lines = (
            "\n".join(f"C{i}. {c.name} | sector: {c.sector or '-'}" for i, c in enumerate(companies, start=1))
            or "(none)"
        )
        sector_lines = "\n".join(f"S{i}. {s.name}" for i, s in enumerate(sectors, start=1)) or "(none)"
        return (
            "You resolve which companies and sectors a financial-data question refers to.\n"
            "A similarity search over the database's sectors table returned the candidates "
            "below. Choose ONLY from these candidates — never invent one.\n\n"
            f"## Question\n<question>{query}</question>\n\n"
            f"## Candidate companies\n{company_lines}\n\n"
            f"## Candidate sectors\n{sector_lines}\n\n"
            "## Decide one status\n"
            '- "no_entity": the question names no specific company or sector (market-wide '
            'questions such as "top 10 companies by revenue", "median PE", or a breakdown '
            '"by sector"). The candidates are then irrelevant.\n'
            '- "found": every company/sector the question names matches exactly one candidate. '
            "Short names, acronyms (TCS → Tata Consultancy Services), missing suffixes (Ltd, "
            "Limited) and small typos still count as a match.\n"
            '- "ambiguous": a name in the question fits two or more candidates equally well and '
            'nothing in the question decides between them (e.g. "Bajaj" with Bajaj Auto and '
            "Bajaj Finance both listed).\n"
            '- "not_found": the question names a company or sector that matches NO candidate.\n'
            "If the question contains 'User clarification:', that text is the user's answer to "
            "an earlier question about which entity they meant — use it to decide.\n\n"
            "## Output — one JSON object, nothing else\n"
            "{\n"
            '  "status": "found" | "no_entity" | "ambiguous" | "not_found",\n'
            '  "companies": ["C1"],            // found: the chosen company labels\n'
            '  "sectors": ["S1"],              // found: the chosen sector labels\n'
            '  "mention": "bajaj",             // ambiguous/not_found: the name as the user wrote it\n'
            '  "ambiguous_candidates": ["C1", "C2"]  // ambiguous: the candidates it could be\n'
            "}"
        )

    @staticmethod
    def _build_resolution(
        choice: dict, companies: list[EntityCandidate], sectors: list[EntityCandidate]
    ) -> EntityResolution:
        """Validate the LLM's labels against the candidate lists and build the outcome."""
        by_label = {f"C{i}": c for i, c in enumerate(companies, start=1)}
        by_label.update({f"S{i}": s for i, s in enumerate(sectors, start=1)})

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
            chosen = pick(choice.get("companies")) + pick(choice.get("sectors"))
            if chosen:
                return EntityResolution(
                    status="found",
                    companies=[c for c in chosen if c.kind == ENTITY_TYPE_COMPANY],
                    sectors=[c for c in chosen if c.kind == ENTITY_TYPE_SECTOR],
                )
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
            options = (companies or sectors)[:_MAX_OPTIONS]
            return EntityResolution(
                status="not_found",
                clarification=(
                    f"I couldn't find **{mention}** in this namespace's companies and sectors. "
                    f"Did you mean one of these?\n\n{_numbered(options)}\n\n{CLARIFICATION_MARKER}"
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
    last_assistant = None
    for i in range(len(history) - 1, -1, -1):
        if history[i].get("role") == "assistant":
            last_assistant = i
            break
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
