# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Resolver: one path for companies and sectors — candidates, pick, prompts, resume."""

from __future__ import annotations

import json
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from coa_entity.lexical import NameEntry, build_matcher
from coa_entity.resolver import (
    ALL_OPTION,
    CLARIFICATION_MARKER,
    EntityCandidate,
    EntityResolution,
    fallback_rules,
    resolve_entities,
    resolved_block,
    resume_clarification,
)

from .helpers import sample_config


def _hit(uri: str, name: str, **attrs: str) -> SimpleNamespace:
    return SimpleNamespace(
        metadata={"entity_uri": uri, "context_text": json.dumps({"name": name, "attrs": attrs})}, score=0.9
    )


COMPANY_HITS = [
    _hit("101", "Bajaj Auto Ltd.", cd_sector="Automobile Two & Three Wheelers"),
    _hit("102", "Bajaj Finance Ltd.", cd_sector="Finance - NBFC"),
]
SECTOR_HITS = [_hit("Automobile Two & Three Wheelers", "Automobile Two & Three Wheelers")]
NAMES = build_matcher(
    [
        NameEntry("company", "201", "Grindwell Norton Ltd.", {"cd_sector": "Abrasives"}),
        NameEntry("company", "101", "Bajaj Auto Ltd.", {"cd_sector": "Automobile Two & Three Wheelers"}),
        NameEntry("company", "301", "Tata Consultancy Services Ltd.", {"cd_sector": "IT - Software"}),
        NameEntry("sector", "Automobile Two & Three Wheelers", "Automobile Two & Three Wheelers"),
        NameEntry("sector", "Automobiles - Passenger Cars", "Automobiles - Passenger Cars"),
        NameEntry("sector", "Abrasives", "Abrasives"),
    ]
)


def _resolver(reply: dict | str, company_hits=COMPANY_HITS, sector_hits=SECTOR_HITS, search_error=None):
    vector = AsyncMock()

    def search(*_a, entity_type, **_k):
        if search_error:
            raise search_error
        return {"company": company_hits, "sector": sector_hits}[entity_type]

    vector.search.side_effect = search
    llm = AsyncMock()
    llm.converse.return_value = SimpleNamespace(text=reply if isinstance(reply, str) else json.dumps(reply))
    return (vector, llm), vector, llm


async def _resolve(clients, query, matcher=None):
    return await resolve_entities(
        *clients, query, "ns1", sample_config(), index="ix-v1", matcher=matcher, embedding=[0.1]
    )


def _prompt(llm) -> str:
    return llm.converse.call_args.args[0]


@pytest.fixture(autouse=True)
def _no_retry_sleep(monkeypatch):
    import coa_entity.resolver as r

    monkeypatch.setattr(r.asyncio, "sleep", AsyncMock())


@pytest.mark.unit
class TestCandidates:
    async def test_every_kind_searched_in_the_given_index(self):
        resolver, vector, _ = _resolver({"status": "no_entity"})
        await _resolve(resolver, "q")
        searched = {c.kwargs["entity_type"]: c.kwargs for c in vector.search.call_args_list}
        assert set(searched) == {"company", "sector"}
        assert searched["company"]["index"] == "ix-v1"

    async def test_name_match_adds_partial_names_vector_search_missed(self):
        resolver, _, llm = _resolver({"status": "no_entity"}, company_hits=[], sector_hits=[])
        await _resolve(resolver, "total revenue of norton", matcher=NAMES)
        assert "[company] Grindwell Norton Ltd." in _prompt(llm)

    async def test_name_match_finds_every_sector_for_a_broad_word(self):
        resolver, _, llm = _resolver({"status": "no_entity"}, sector_hits=[])
        await _resolve(resolver, "top 5 by pat in automobile sector", matcher=NAMES)
        prompt = _prompt(llm)
        assert "[sector] Automobile Two & Three Wheelers" in prompt
        assert "[sector] Automobiles - Passenger Cars" in prompt

    async def test_duplicates_from_both_sources_appear_once(self):
        resolver, _, llm = _resolver({"status": "no_entity"})
        await _resolve(resolver, "bajaj auto pat", matcher=NAMES)
        assert _prompt(llm).count("Bajaj Auto Ltd.") == 1

    async def test_cold_search_is_retried_once(self):
        resolver, vector, _ = _resolver({"status": "no_entity"})
        calls = {"n": 0}

        def flaky(*_a, entity_type, **_k):
            calls["n"] += 1
            if calls["n"] == 1:
                raise TimeoutError("cold")
            return {"company": COMPANY_HITS, "sector": SECTOR_HITS}[entity_type]

        vector.search.side_effect = flaky
        assert (await _resolve(resolver, "q")).status == "no_entity"

    async def test_search_failure_still_resolves_from_names(self):
        resolver, _, _ = _resolver({"status": "found", "chosen": ["E1"]}, search_error=RuntimeError("down"))
        res = await _resolve(resolver, "tcs pat", matcher=NAMES)
        assert res.by_kind() == {"company": ["Tata Consultancy Services Ltd."]}

    async def test_nothing_at_all_is_skipped(self):
        resolver, _, llm = _resolver({"status": "found"}, company_hits=[], sector_hits=[])
        res = await _resolve(resolver, "q")
        assert res.reason == "entity index empty"
        llm.converse.assert_not_called()


@pytest.mark.unit
class TestOutcomes:
    async def test_found_company_and_sector(self):
        resolver, _, _ = _resolver({"status": "found", "chosen": ["E1", "E3"]})
        res = await _resolve(resolver, "bajaj auto pat")
        assert res.by_kind() == {"company": ["Bajaj Auto Ltd."], "sector": ["Automobile Two & Three Wheelers"]}

    async def test_ambiguous_companies_get_numbered_options(self):
        resolver, _, _ = _resolver({"status": "ambiguous", "mention": "bajaj", "ambiguous_candidates": ["E1", "E2"]})
        res = await _resolve(resolver, "bajaj pat")
        assert "1. Bajaj Auto Ltd. (Automobile Two & Three Wheelers)\n2. Bajaj Finance Ltd. (Finance - NBFC)" in (
            res.clarification
        )
        assert ALL_OPTION not in res.clarification
        assert res.clarification.endswith(CLARIFICATION_MARKER)

    async def test_ambiguous_sectors_also_offer_all_of_these(self):
        probe, _, llm = _resolver({"status": "no_entity"}, sector_hits=[])
        await _resolve(probe, "automobile sector pat", matcher=NAMES)
        labels = [ln.split(".")[0] for ln in _prompt(llm).splitlines() if "[sector] Automobile" in ln]
        resolver, _, _ = _resolver(
            {"status": "ambiguous", "mention": "automobile", "ambiguous_candidates": labels}, sector_hits=[]
        )
        res = await _resolve(resolver, "automobile sector pat", matcher=NAMES)
        assert f"3. {ALL_OPTION}" in res.clarification

    async def test_hallucinated_label_asks_instead_of_guessing(self):
        resolver, _, _ = _resolver({"status": "found", "chosen": ["E99"]})
        assert (await _resolve(resolver, "x")).status == "not_found"

    async def test_missing_mention_uses_the_users_words(self):
        resolver, _, _ = _resolver({"status": "ambiguous", "ambiguous_candidates": ["E1", "E2"]})
        res = await _resolve(resolver, "latest pat of norton\nUser clarification: latest pat of nextgen")
        assert "**latest pat of nextgen**" in res.clarification
        assert "that name" not in res.clarification

    async def test_options_picked_by_name_are_never_dropped(self):
        # Bedrock's reply leaves out one of the picks; the names the user picked still win
        resolver, _, _ = _resolver({"status": "found", "chosen": ["E1"]}, sector_hits=[])
        q = (
            "top 5 in automobile sector\nUser clarification: all of: Automobile Two & Three Wheelers; "
            "Automobiles - Passenger Cars"
        )
        res = await _resolve(resolver, q, matcher=NAMES)
        assert res.status == "found"
        assert set(res.by_kind()["sector"]) == {"Automobile Two & Three Wheelers", "Automobiles - Passenger Cars"}

    async def test_option_label_with_attribute_maps_to_the_entity(self):
        resolver, _, _ = _resolver({"status": "no_entity"})
        res = await _resolve(
            resolver, "bajaj pat\nUser clarification: Bajaj Auto Ltd. (Automobile Two & Three Wheelers)", NAMES
        )
        assert res.status == "found" and res.by_kind() == {"company": ["Bajaj Auto Ltd."]}

    async def test_free_text_reply_is_left_to_the_model(self):
        resolver, _, llm = _resolver({"status": "found", "chosen": ["E1"]})
        res = await _resolve(resolver, "bajaj pat\nUser clarification: bajaj auto", NAMES)
        assert res.by_kind() == {"company": ["Bajaj Auto Ltd."]}
        llm.converse.assert_called_once()

    @pytest.mark.parametrize("reply", ["not json", {"status": "maybe"}])
    async def test_unusable_reply_is_skipped(self, reply):
        resolver, _, _ = _resolver(reply)
        assert (await _resolve(resolver, "x")).status == "skipped"


@pytest.mark.unit
class TestPromptSections:
    def test_company_filter_carries_its_sector(self):
        res = EntityResolution(
            status="found",
            chosen=[EntityCandidate("company", "101", "Bajaj Auto Ltd.", (("cd_sector", "Automobile"),))],
        )
        assert (
            "company: Bajaj Auto Ltd. (company_id 101, cd_sector Automobile) → "
            "LOWER(company_name) LIKE '%bajaj auto ltd.%' AND sector = 'Automobile'"
        ) in resolved_block(res, sample_config())

    def test_sectors_become_one_in_list_with_the_table_column_named(self):
        res = EntityResolution(
            status="found",
            chosen=[
                EntityCandidate("sector", "Automobiles - Passenger Cars", "Automobiles - Passenger Cars"),
                EntityCandidate("sector", "Automobile Two & Three Wheelers", "Automobile Two & Three Wheelers"),
            ],
        )
        assert (
            "sector: Automobiles - Passenger Cars, Automobile Two & Three Wheelers → "
            "sector IN ('Automobiles - Passenger Cars', 'Automobile Two & Three Wheelers') "
            "(fact tables: sector; on the sectors table use cd_sector)"
        ) in resolved_block(res, sample_config())

    def test_fallback_rules_cover_companies_and_sectors(self):
        rules = fallback_rules(sample_config())
        assert "LOWER(company_name) LIKE '%<word>%'" in rules
        assert "LOWER(sector) LIKE '%<word>%' (fact tables: sector; on the sectors table use cd_sector)" in rules


CLARIFY = f"Which?\n\n1. Bajaj Auto Ltd. (Automobile)\n2. Bajaj Finance Ltd. (Finance)\n\n{CLARIFICATION_MARKER}"
SECTOR_CLARIFY = (
    f"Which?\n\n1. Automobile Two & Three Wheelers\n2. Automobiles - Passenger Cars\n3. {ALL_OPTION}\n\n"
    f"{CLARIFICATION_MARKER}"
)


def _history(question: str, clarification: str) -> list[dict]:
    return [{"role": "user", "content": question}, {"role": "assistant", "content": clarification}]


@pytest.mark.unit
class TestResume:
    @pytest.mark.parametrize("reply", ["1", "1.", "#1", "option 1", " 1 "])
    def test_number_forms(self, reply):
        assert resume_clarification(reply, _history("bajaj pat", CLARIFY)) == (
            "bajaj pat\nUser clarification: Bajaj Auto Ltd. (Automobile)"
        )

    @pytest.mark.parametrize("reply", ["1,2", "1 and 2", "1 & 2", "all", "both", "All of them"])
    def test_several_or_all(self, reply):
        assert resume_clarification(reply, _history("bajaj pat", CLARIFY)) == (
            "bajaj pat\nUser clarification: all of: Bajaj Auto Ltd. (Automobile); Bajaj Finance Ltd. (Finance)"
        )

    def test_all_of_these_option(self):
        assert resume_clarification("3", _history("automobile sector pat", SECTOR_CLARIFY)) == (
            "automobile sector pat\nUser clarification: all of: Automobile Two & Three Wheelers; "
            "Automobiles - Passenger Cars"
        )

    def test_a_name_is_used_as_written(self):
        assert resume_clarification("bajaj auto", _history("latest pat of bajaj", CLARIFY)) == (
            "latest pat of bajaj\nUser clarification: bajaj auto"
        )

    def test_a_new_question_is_not_a_reply(self):
        assert resume_clarification("total revenue of grindell", _history("total revenue of norton", CLARIFY)) is None

    def test_keeps_only_the_root_question(self):
        hist = _history("bajaj pat\nUser clarification: bajaj", CLARIFY)
        assert resume_clarification("2", hist) == "bajaj pat\nUser clarification: Bajaj Finance Ltd. (Finance)"

    def test_not_after_a_normal_answer(self):
        assert resume_clarification("1", [{"role": "assistant", "content": "hello"}]) is None
