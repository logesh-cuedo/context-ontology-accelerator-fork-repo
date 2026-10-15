# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Generic resolver: search per configured kind, LLM pick, prompt sections, resume."""

from __future__ import annotations

import json
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from coa_entity.resolver import (
    CLARIFICATION_MARKER,
    EntityResolution,
    EntityResolver,
    fallback_rules,
    resolved_block,
    resume_clarification,
)

from .helpers import sample_config


def _hit(uri: str, name: str, **attrs: str) -> SimpleNamespace:
    return SimpleNamespace(
        metadata={"entity_uri": uri, "context_text": json.dumps({"name": name, "attrs": attrs})}, score=0.9
    )


COMPANY_HITS = [
    _hit("101", "Bajaj Auto Ltd.", cd_sector="Automobile"),
    _hit("102", "Bajaj Finance Ltd.", cd_sector="Finance"),
]
SECTOR_HITS = [_hit("Automobile", "Automobile")]


def _resolver(reply: dict | str, company_hits=COMPANY_HITS, sector_hits=SECTOR_HITS):
    vector = AsyncMock()
    vector.search.side_effect = lambda *a, entity_type, **k: {"company": company_hits, "sector": sector_hits}[
        entity_type
    ]
    llm = AsyncMock()
    llm.converse.return_value = SimpleNamespace(text=reply if isinstance(reply, str) else json.dumps(reply))
    return EntityResolver(vector, llm, "coll"), vector, llm


@pytest.mark.unit
class TestResolve:
    async def test_searches_every_configured_kind_in_the_namespace_index(self):
        resolver, vector, _ = _resolver({"status": "no_entity"})
        await resolver.resolve("q", "ns1", sample_config(), embedding=[0.1])
        searched = {c.kwargs["entity_type"]: c.kwargs for c in vector.search.call_args_list}
        assert set(searched) == {"company", "sector"}
        assert searched["company"]["index"] == "coll-entities-ns1"
        assert searched["company"]["top_k"] == 10 and searched["sector"]["top_k"] == 5

    async def test_found(self):
        resolver, _, _ = _resolver({"status": "found", "chosen": ["E1", "E3"]})
        res = await resolver.resolve("bajaj auto pat", "ns1", sample_config(), embedding=[0.1])
        assert res.status == "found"
        assert res.by_kind() == {"company": ["Bajaj Auto Ltd."], "sector": ["Automobile"]}

    async def test_ambiguous_lists_numbered_options(self):
        resolver, _, _ = _resolver({"status": "ambiguous", "mention": "bajaj", "ambiguous_candidates": ["E1", "E2"]})
        res = await resolver.resolve("bajaj pat", "ns1", sample_config(), embedding=[0.1])
        assert res.needs_clarification
        assert "1. Bajaj Auto Ltd. (Automobile)\n2. Bajaj Finance Ltd. (Finance)" in res.clarification
        assert res.clarification.endswith(CLARIFICATION_MARKER)

    async def test_hallucinated_label_asks_instead_of_guessing(self):
        resolver, _, _ = _resolver({"status": "found", "chosen": ["E99"]})
        res = await resolver.resolve("x", "ns1", sample_config(), embedding=[0.1])
        assert res.status == "not_found"

    @pytest.mark.parametrize("reply", ["not json", {"status": "maybe"}])
    async def test_unusable_reply_is_skipped(self, reply):
        resolver, _, _ = _resolver(reply)
        assert (await resolver.resolve("x", "ns1", sample_config(), embedding=[0.1])).status == "skipped"

    async def test_empty_index_is_skipped(self):
        resolver, _, llm = _resolver({"status": "found"}, company_hits=[], sector_hits=[])
        res = await resolver.resolve("x", "ns1", sample_config(), embedding=[0.1])
        assert res.reason == "entity index empty"
        llm.converse.assert_not_called()


@pytest.mark.unit
class TestPromptSections:
    def test_resolved_block_uses_configured_columns(self):
        from coa_entity.resolver import EntityCandidate

        res = EntityResolution(
            status="found",
            chosen=[
                EntityCandidate(
                    kind="company", key="101", name="Bajaj Auto Ltd.", attrs=(("cd_sector", "Automobile"),)
                ),
                EntityCandidate(kind="sector", key="Automobile", name="Automobile"),
            ],
        )
        block = resolved_block(res, sample_config())
        # the picked company's sector rides along as a filter (filterWithMember),
        # under the fact tables' column name (filterColumn "sector")
        assert (
            "company: Bajaj Auto Ltd. (company_id 101, cd_sector Automobile) → "
            "LOWER(company_name) LIKE '%bajaj auto ltd.%' AND sector = 'Automobile'"
        ) in block
        assert "do NOT turn them into extra WHERE conditions" in block
        assert "sector: Automobile → sector = 'Automobile'" in block

    def test_fallback_rules_name_the_filter_columns(self):
        rules = fallback_rules(sample_config())
        assert "company_name" in rules and "LIKE" in rules


@pytest.mark.unit
class TestResume:
    HISTORY = [
        {"role": "user", "content": "bajaj pat"},
        {
            "role": "assistant",
            "content": f"Which?\n\n1. Bajaj Auto Ltd. (Automobile)\n2. Bajaj Finance Ltd.\n\n{CLARIFICATION_MARKER}",
        },
    ]

    def test_number_expands_to_option(self):
        assert resume_clarification("1", self.HISTORY) == "bajaj pat\nUser clarification: Bajaj Auto Ltd. (Automobile)"

    def test_not_a_clarification(self):
        assert resume_clarification("1", [{"role": "assistant", "content": "hello"}]) is None
