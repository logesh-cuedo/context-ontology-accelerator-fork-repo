# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Name matching: partial names, acronyms, typos, broad sector words."""

from __future__ import annotations

import pytest

from coa_entity.lexical import NameEntry, acronym, build_matcher, kind_words, match, matcher_from_catalog, tokens

ENTRIES = [
    NameEntry("company", "1", "Grindwell Norton Ltd."),
    NameEntry("company", "2", "Tata Consultancy Services Ltd."),
    NameEntry("company", "3", "Larsen & Toubro Ltd."),
    NameEntry("company", "4", "Bajaj Auto Ltd."),
    NameEntry("company", "5", "Bajaj Finance Ltd."),
    NameEntry("company", "6", "Nifty Services Sector"),
    NameEntry("company", "7", "Total Transport Systems Ltd."),
    NameEntry("sector", "s1", "Automobile Two & Three Wheelers"),
    NameEntry("sector", "s2", "Automobiles - Passenger Cars"),
    NameEntry("sector", "s3", "IT - Software"),
    NameEntry("sector", "s4", "Pharmaceuticals & Drugs"),
]
M = build_matcher(ENTRIES)


def names(query: str, k: int = 5) -> list[str]:
    return [e.name for e, _ in match(M, query, {"company": k, "sector": k})]


@pytest.mark.unit
class TestMatch:
    def test_tokens_and_acronyms(self):
        assert tokens("Larsen & Toubro Ltd.") == ["larsen", "toubro"]
        assert acronym("Tata Consultancy Services Ltd.") == "tcs"
        assert {"sector", "sectors", "company", "companies"} <= kind_words(["sector", "company"])

    def test_partial_name(self):
        assert names("total revenue of norton")[0] == "Grindwell Norton Ltd."

    def test_acronym(self):
        assert names("latest pat of tcs") == ["Tata Consultancy Services Ltd."]

    def test_ampersand_acronym(self):
        assert "Larsen & Toubro Ltd." in names("L&T revenue")

    def test_typos(self):
        assert "Grindwell Norton Ltd." in names("revenue of grindell")
        assert "Bajaj Auto Ltd." in names("bajai pat")

    def test_broad_sector_word_finds_every_sector(self):
        found = names("top 5 companies in automobile sector")
        assert {"Automobile Two & Three Wheelers", "Automobiles - Passenger Cars"} <= set(found)
        assert names("median pat under automotive sector")[:2] == [
            "Automobile Two & Three Wheelers",
            "Automobiles - Passenger Cars",
        ] or {"Automobile Two & Three Wheelers", "Automobiles - Passenger Cars"} <= set(
            names("median pat under automotive sector")
        )

    def test_type_words_name_nothing(self):
        assert "Nifty Services Sector" not in names("top companies by sector")

    def test_from_catalog(self):
        m = matcher_from_catalog({"entities": [["sector", "IT - Software", "IT - Software", {}]]})
        assert [e.name for e, _ in match(m, "it software", {"sector": 3})] == ["IT - Software"]
