# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Find entity names by the words in the question.

The similarity search finds entities by meaning, but it can miss part of a name
("norton" for Grindwell Norton Ltd.) or a broad word ("automobile" for every
automobile sector). This file fills that gap: each name is scored by the words
it shares with the question. Rare words (``norton``) count more than common
ones (``ltd``, ``india``). How rare a word is comes from the names themselves,
so no word list has to be kept by hand.

A question word matches a name word when it is:
  - the same word                      (``bajaj`` and ``bajaj``)
  - the name's short form              (``tcs`` for Tata Consultancy Services, ``l&t``)
  - the start of it, 4+ letters        (``auto`` and ``automobile``)
  - the same first 5+ letters          (``automotive`` and ``automobile``)
  - a near spelling, 5+ letters        (``bajai`` and ``bajaj``, ``grindell`` and ``grindwell``)
"""

from __future__ import annotations

import math
import os
import re
from collections import defaultdict
from dataclasses import dataclass, field
from difflib import SequenceMatcher

# Words that never identify an entity on their own.
_NOISE = {
    "ltd", "limited", "pvt", "private", "inc", "corp", "corporation", "co", "company",
    "the", "of", "and", "a", "an", "in", "for", "to", "by", "on", "with", "at", "is",
}  # fmt: skip
_WORD = re.compile(r"[a-z0-9]+")
_AMPERSAND_ACRONYM = re.compile(r"\b[a-z](?:\s*&\s*[a-z])+\b")  # "l&t", "m & m"
_ACRONYM_BONUS = 3.0

# Match quality of a question word against a name word.
_EQUAL, _PREFIX, _STEM, _SPELLING = 1.0, 0.8, 0.7, 0.6


def tokens(text: str) -> list[str]:
    """Lower-case words, ``&`` read as ``and``, noise words dropped."""
    return [t for t in _WORD.findall(text.lower().replace("&", " and ")) if t not in _NOISE]


def acronym(text: str) -> str:
    """Initials of a multi-word name: 'Tata Consultancy Services Ltd.' → 'tcs'."""
    words = [t for t in tokens(text) if not t.isdigit()]
    return "".join(w[0] for w in words) if len(words) >= 2 else ""


def kind_words(kinds: list[str]) -> set[str]:
    """The type names and their plurals ("sector", "companies") — they name no entity."""
    words = set()
    for kind in kinds:
        for w in _WORD.findall(kind.lower()):
            words |= {w, w + "s", w + "es"}
            if w.endswith("y"):
                words.add(w[:-1] + "ies")
    return words


@dataclass
class NameEntry:
    """One entity in the catalog."""

    kind: str
    key: str
    name: str
    attrs: dict[str, str] = field(default_factory=dict)
    words: tuple[str, ...] = ()
    initials: str = ""


def build_matcher(entries: list[NameEntry]) -> dict:
    """Look-up tables for name matching, built once per index version.

    Keys: entries, by_word, by_initials, by_name, idf (word weight), by_first_letter.
    """
    by_word: dict[str, list[int]] = defaultdict(list)
    by_initials: dict[str, list[int]] = defaultdict(list)
    by_name: dict[str, list[NameEntry]] = defaultdict(list)
    for i, e in enumerate(entries):
        e.words = tuple(dict.fromkeys(tokens(e.name)))
        e.initials = acronym(e.name)
        for w in e.words:
            by_word[w].append(i)
        if len(e.initials) >= 2:
            by_initials[e.initials].append(i)
        by_name[" ".join(e.name.lower().split())].append(e)

    total = max(1, len(entries))
    by_first_letter: dict[str, list[str]] = defaultdict(list)
    for w in by_word:
        by_first_letter[w[0]].append(w)
    return {
        "entries": entries,
        "by_word": by_word,
        "by_initials": by_initials,
        "by_name": by_name,
        "idf": {w: math.log(1 + total / len(ids)) for w, ids in by_word.items()},  # rare words weigh more
        "by_first_letter": by_first_letter,
    }


def matcher_from_catalog(catalog: dict) -> dict:
    """Build the matcher from the name list the index build saves: [kind, key, name, attrs] per entity."""
    entries = [
        NameEntry(kind=str(e[0]), key=str(e[1]), name=str(e[2]), attrs=dict(e[3]) if len(e) > 3 else {})
        for e in catalog.get("entities", [])
    ]
    return build_matcher(entries)


def exact(m: dict, name: str) -> list[NameEntry]:
    """Entities whose full name equals ``name`` (case and spacing ignored)."""
    return list(m["by_name"].get(" ".join(name.lower().split()), ()))


def match(m: dict, query: str, top_k: dict[str, int]) -> list[tuple[NameEntry, float]]:
    """Best-matching entities per kind (``top_k`` = {kind: how many}), best first.

    For each word of the question, an entity gets the weight of its best
    matching word (match quality x word weight); the weights are added up and
    then scaled by how much of the name was matched. So "norton" ranks
    Grindwell Norton (1 of 2 words) above a long name that only shares one word.
    """
    scores: dict[int, float] = defaultdict(float)
    matched: dict[int, set[str]] = defaultdict(set)

    def acronym_score(i: int) -> float:
        return _ACRONYM_BONUS + max((m["idf"][w] for w in m["entries"][i].words), default=0)

    for letters in _AMPERSAND_ACRONYM.findall(query.lower()):
        for i in m["by_initials"].get(re.sub(r"[\s&]", "", letters), ()):
            scores[i] += acronym_score(i)
            matched[i].update(m["entries"][i].words)

    skip = kind_words(list(top_k))
    for q in dict.fromkeys(tokens(query)):
        if len(q) < 2 or q in skip:
            continue
        # Name words matching q, with their match quality.
        qualities = {q: _EQUAL} if q in m["by_word"] else {}
        for w in m["by_first_letter"].get(q[0], ()):
            if w == q:
                continue
            if len(q) >= 4 and len(w) >= 4 and (w.startswith(q) or q.startswith(w)):
                quality = _PREFIX
            elif len(q) >= 5 and len(w) >= 5 and len(os.path.commonprefix([q, w])) >= 5:
                quality = _STEM
            elif len(q) >= 5 and abs(len(q) - len(w)) <= 2 and SequenceMatcher(None, q, w).ratio() >= 0.8:
                quality = _SPELLING
            else:
                continue
            qualities[w] = max(qualities.get(w, 0), quality)

        best: dict[int, float] = {}
        for w, quality in qualities.items():
            weight = quality * m["idf"][w]
            for i in m["by_word"][w]:
                best[i] = max(best.get(i, 0.0), weight)
                matched[i].add(w)
        for i in m["by_initials"].get(q, ()):
            best[i] = max(best.get(i, 0.0), acronym_score(i))
            matched[i].update(m["entries"][i].words)  # an acronym names the whole entity
        for i, weight in best.items():
            scores[i] += weight

    # Scale by name coverage, then keep each kind's best (within half the top score).
    by_kind: dict[str, list[tuple[NameEntry, float]]] = defaultdict(list)
    for i, score in scores.items():
        e = m["entries"][i]
        coverage = len(matched[i]) / len(e.words) if e.words else 1.0
        by_kind[e.kind].append((e, score * (0.5 + 0.5 * min(1.0, coverage))))

    result: list[tuple[NameEntry, float]] = []
    for kind, items in by_kind.items():
        if kind not in top_k:
            continue
        items.sort(key=lambda item: (-item[1], len(item[0].name)))
        floor = max(0.3, 0.5 * items[0][1])
        result += [item for item in items if item[1] >= floor][: top_k[kind]]
    return result
