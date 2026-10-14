# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Tier-2 entity resolution: similarity search → top-k → LLM pick → found / clarify."""

from __future__ import annotations

import json
from unittest.mock import AsyncMock

import pytest
from coa_serve.clients.base import ConverseResult, VectorHit
from coa_serve.tier2.entity_resolution import (
    CLARIFICATION_MARKER,
    EntityResolver,
    resume_clarification,
)

NS = "ns-1"


def _company(cid: str, name: str, sector: str, score: float = 0.8) -> VectorHit:
    return VectorHit(
        id=cid,
        text=name,
        score=score,
        metadata={
            "entity_type": "company",
            "entity_uri": cid,
            "context_text": json.dumps({"company_name": name, "cd_sector": sector, "cd_subsector": ""}),
        },
    )


def _sector(name: str, score: float = 0.6) -> VectorHit:
    return VectorHit(
        id=name,
        text=name,
        score=score,
        metadata={"entity_type": "sector", "entity_uri": name, "context_text": json.dumps({"cd_sector": name})},
    )


COMPANIES = [
    _company("101", "Bajaj Auto Ltd.", "Automobile"),
    _company("102", "Bajaj Finance Ltd.", "Finance"),
    _company("103", "Tata Consultancy Services Ltd.", "IT - Software"),
]
SECTORS = [_sector("Automobile"), _sector("Finance")]


def _resolver(llm_reply: dict | str, companies=COMPANIES, sectors=SECTORS, prefix="coll"):
    vector = AsyncMock()

    async def search(_vec, *, entity_type=None, **_kw):
        return list(companies if entity_type == "company" else sectors)

    vector.search.side_effect = search
    llm = AsyncMock()
    llm.embed.return_value = [0.1, 0.2]
    text = llm_reply if isinstance(llm_reply, str) else json.dumps(llm_reply)
    llm.converse.return_value = ConverseResult(text=text)
    return EntityResolver(vector, llm, prefix), vector, llm


async def test_found_returns_the_exact_company_and_a_like_filter_on_its_full_name():
    resolver, vector, _ = _resolver({"status": "found", "companies": ["C1"], "sectors": []})

    result = await resolver.resolve("latest pat of bajaj auto", NS, embedding=[0.3])

    assert result.status == "found"
    assert [c.name for c in result.companies] == ["Bajaj Auto Ltd."]
    assert "LOWER(company_name) LIKE '%bajaj auto ltd.%'" in result.prompt_block()
    # searched the namespace's entity index, companies and sectors separately
    indexes = {call.kwargs["index"] for call in vector.search.call_args_list}
    assert indexes == {"coll-entities-ns-1"}


async def test_query_embedding_is_reused_when_supplied():
    resolver, _, llm = _resolver({"status": "no_entity"})
    await resolver.resolve("top 10 companies by revenue", NS, embedding=[0.3])
    llm.embed.assert_not_called()


async def test_no_entity_needs_no_clarification_and_adds_nothing_to_the_prompt():
    resolver, _, _ = _resolver({"status": "no_entity"})
    result = await resolver.resolve("median PE of all companies", NS)
    assert result.status == "no_entity"
    assert not result.needs_clarification
    assert result.prompt_block() == ""


async def test_ambiguous_asks_which_candidate_with_numbered_options():
    resolver, _, _ = _resolver({"status": "ambiguous", "mention": "bajaj", "ambiguous_candidates": ["C1", "C2"]})
    result = await resolver.resolve("latest pat of bajaj", NS)

    assert result.status == "ambiguous"
    assert result.needs_clarification
    assert "1. Bajaj Auto Ltd. (Automobile)" in result.clarification
    assert "2. Bajaj Finance Ltd. (Finance)" in result.clarification
    assert result.clarification.endswith(CLARIFICATION_MARKER)


async def test_not_found_asks_for_clarification_offering_the_top_candidates():
    resolver, _, _ = _resolver({"status": "not_found", "mention": "yaap"})
    result = await resolver.resolve("latest pat of yaap", NS)

    assert result.status == "not_found"
    assert "**yaap**" in result.clarification
    assert "3. Tata Consultancy Services Ltd. (IT - Software)" in result.clarification


async def test_hallucinated_labels_are_dropped_and_turn_into_a_clarification():
    resolver, _, _ = _resolver({"status": "found", "companies": ["C9"], "mention": "acme"})
    result = await resolver.resolve("revenue of acme", NS)
    assert result.status == "not_found"


@pytest.mark.parametrize(
    ("reply", "companies", "prefix"),
    [
        ("not json at all", COMPANIES, "coll"),  # unparseable LLM reply
        ({"status": "maybe"}, COMPANIES, "coll"),  # unknown status
        ({"status": "found", "companies": ["C1"]}, [], "coll"),  # empty index
        ({"status": "found", "companies": ["C1"]}, COMPANIES, ""),  # no index configured
    ],
)
async def test_fail_open_cases_skip_without_asking(reply, companies, prefix):
    resolver, _, _ = _resolver(reply, companies=companies, sectors=[] if not companies else SECTORS, prefix=prefix)
    result = await resolver.resolve("latest pat of bajaj auto", NS)
    assert result.status == "skipped"
    assert not result.needs_clarification


async def test_search_error_skips():
    resolver, vector, _ = _resolver({"status": "found", "companies": ["C1"]})
    vector.search.side_effect = RuntimeError("aoss down")
    assert (await resolver.resolve("pat of bajaj auto", NS)).status == "skipped"


# ── resume_clarification ────────────────────────────────────────────────

CLARIFY = (
    "**bajaj** matches more than one entry. Which one did you mean?\n\n"
    "1. Bajaj Auto Ltd. (Automobile)\n2. Bajaj Finance Ltd. (Finance)\n\n" + CLARIFICATION_MARKER
)


def test_resume_expands_an_option_number_and_keeps_the_original_question():
    history = [
        {"role": "user", "content": "latest pat of bajaj"},
        {"role": "assistant", "content": CLARIFY},
    ]
    merged = resume_clarification("2", history)
    assert merged == "latest pat of bajaj\nUser clarification: Bajaj Finance Ltd. (Finance)"


def test_resume_passes_free_text_answers_through():
    history = [{"role": "user", "content": "pat of bajaj"}, {"role": "assistant", "content": CLARIFY}]
    assert resume_clarification("the auto one", history).endswith("User clarification: the auto one")


def test_resume_keeps_only_the_root_question_across_repeated_clarifications():
    history = [
        {"role": "user", "content": "pat of bajaj\nUser clarification: auto"},
        {"role": "assistant", "content": CLARIFY},
    ]
    assert resume_clarification("1", history) == "pat of bajaj\nUser clarification: Bajaj Auto Ltd. (Automobile)"


@pytest.mark.parametrize(
    "history",
    [
        None,
        [],
        [{"role": "user", "content": "q"}, {"role": "assistant", "content": "Here is your answer."}],
        [{"role": "assistant", "content": CLARIFY}],  # no user turn before it
    ],
)
def test_no_resume_when_the_last_turn_was_not_a_clarification(history):
    assert resume_clarification("2", history) is None


# ── SQL prompt block ────────────────────────────────────────────────────


def test_sql_prompt_carries_the_resolved_entities_section():
    from coa_serve.tier2.nl_to_sql.sql_generator import _entities_block

    assert _entities_block("") == ""
    block = _entities_block("- company: Bajaj Auto Ltd.")
    assert "## Resolved entities (authoritative)" in block
    assert "Bajaj Auto Ltd." in block


def test_like_pattern_escapes_quotes_and_drops_percent():
    from coa_serve.tier2.entity_resolution import _like_literal

    assert _like_literal("Dr. Reddy's Laboratories Ltd.") == "dr. reddy''s laboratories ltd."
    assert _like_literal("100% Foods") == "100 foods"
