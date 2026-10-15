# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Name matching over a namespace's entity names — the complement to vector search.

Vector search finds entities by meaning but misses partial names ("norton" →
Grindwell Norton Ltd.) and broad category words ("automobile" → every
automobile sector). This matcher scores names by the words they share with the
question, weighting rare words (``norton``) above common ones (``ltd``,
``india``) with an IDF taken from the names themselves, so it works for any
entity type without a domain word list.

A query word matches a name word when it is:
  - equal                                  (``bajaj`` ↔ ``bajaj``)
  - the name's acronym                     (``tcs`` ↔ Tata Consultancy Services)
  - a prefix of ≥4 letters, either way      (``auto`` ↔ ``automobile``)
  - a shared stem of ≥5 letters             (``automotive`` ↔ ``automobile``)
  - a close spelling, ≥5 letters            (``bajai`` ↔ ``bajaj``, ``grindell`` ↔ ``grindwell``)
"""

from __future__ import annotations

import math
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


def tokens(text: str) -> list[str]:
    """Lower-case alphanumeric words, ``&`` read as ``and``, noise words dropped."""
    return [t for t in _WORD.findall(text.lower().replace("&", " and ")) if t not in _NOISE]


def acronym(text: str) -> str:
    """Initials of a multi-word name: 'Tata Consultancy Services Ltd.' → 'tcs'."""
    words = [t for t in tokens(text) if not t.isdigit()]
    return "".join(w[0] for w in words) if len(words) >= 2 else ""


def _norm_name(name: str) -> str:
    return " ".join(name.lower().split())


def kind_words(kinds: list[str]) -> set[str]:
    """The configured type names and their plurals — "sector", "companies" name no entity."""
    out: set[str] = set()
    for k in kinds:
        for w in _WORD.findall(k.lower()):
            out |= {w, w + "s", w + "es"}
            if w.endswith("y"):
                out.add(w[:-1] + "ies")
    return out


def _common_prefix(a: str, b: str) -> int:
    n = 0
    for x, y in zip(a, b, strict=False):
        if x != y:
            break
        n += 1
    return n


@dataclass
class NameEntry:
    """One entity in the catalog: kind, key, display name, attributes."""

    kind: str
    key: str
    name: str
    attrs: dict[str, str] = field(default_factory=dict)
    words: tuple[str, ...] = ()
    initials: str = ""


class NameMatcher:
    """Score entity names against a question; build once per index version."""

    def __init__(self, entries: list[NameEntry]):
        """Index ``entries`` by word (IDF is computed from the names themselves)."""
        self.entries = entries
        self._by_word: dict[str, list[int]] = defaultdict(list)
        for i, e in enumerate(entries):
            e.words = tuple(dict.fromkeys(tokens(e.name)))
            e.initials = acronym(e.name)
            for w in e.words:
                self._by_word[w].append(i)
        n = max(1, len(entries))
        self._idf = {w: math.log(1 + n / len(ix)) for w, ix in self._by_word.items()}
        self._vocab_by_first: dict[str, list[str]] = defaultdict(list)
        for w in self._by_word:
            self._vocab_by_first[w[0]].append(w)
        self._by_initials: dict[str, list[int]] = defaultdict(list)
        for i, e in enumerate(entries):
            if len(e.initials) >= 2:
                self._by_initials[e.initials].append(i)
        self._by_name: dict[str, list[NameEntry]] = defaultdict(list)
        for e in entries:
            self._by_name[_norm_name(e.name)].append(e)

    def exact(self, name: str) -> list[NameEntry]:
        """Entities whose full name equals ``name`` (case and spacing ignored)."""
        return list(self._by_name.get(_norm_name(name), ()))

    @classmethod
    def from_catalog(cls, catalog: dict) -> NameMatcher:
        """Build from the ``names`` JSON written by the index build."""
        return cls(
            [
                NameEntry(kind=str(e[0]), key=str(e[1]), name=str(e[2]), attrs=dict(e[3]) if len(e) > 3 else {})
                for e in catalog.get("entities", [])
            ]
        )

    def _word_matches(self, q: str) -> list[tuple[str, float]]:
        """Name words matching query word ``q``, each with a match-quality factor."""
        out: dict[str, float] = {}
        if q in self._by_word:
            out[q] = 1.0
        for w in self._vocab_by_first.get(q[0], ()):
            if w == q:
                continue
            if len(q) >= 4 and len(w) >= 4 and (w.startswith(q) or q.startswith(w)):
                out[w] = max(out.get(w, 0), 0.8)
            elif len(q) >= 5 and len(w) >= 5 and _common_prefix(q, w) >= 5:
                out[w] = max(out.get(w, 0), 0.7)
            elif len(q) >= 5 and abs(len(q) - len(w)) <= 2 and SequenceMatcher(None, q, w).ratio() >= 0.8:
                out[w] = max(out.get(w, 0), 0.6)
        return list(out.items())

    def match(self, query: str, top_k: dict[str, int]) -> list[tuple[NameEntry, float]]:
        """Best-matching entities per kind (``top_k`` = {kind: limit}), best first.

        A name's score is the IDF-weighted sum of its best word match per query
        word, scaled by how much of the name the question covers — so
        "norton" ranks Grindwell Norton (1 of 2 words) above a long index name
        that happens to share one word.
        """
        skip = kind_words(list(top_k))
        scores: dict[int, float] = defaultdict(float)
        matched_words: dict[int, set[str]] = defaultdict(set)
        # "L&T", "M&M": letters joined by "&" are an acronym ("lt", "mm").
        for amp in re.findall(r"\b[a-z](?:\s*&\s*[a-z])+\b", query.lower()):
            for i in self._by_initials.get(re.sub(r"[\s&]", "", amp), ()):
                scores[i] += 3.0 + max((self._idf[w] for w in self.entries[i].words), default=0)
                matched_words[i].update(self.entries[i].words)
        for q in dict.fromkeys(tokens(query)):
            if len(q) < 2 or q in skip:
                continue
            best: dict[int, float] = {}
            for w, quality in self._word_matches(q):
                weight = quality * self._idf[w]
                for i in self._by_word[w]:
                    if weight > best.get(i, 0.0):
                        best[i] = weight
                    matched_words[i].add(w)
            if len(q) >= 2:
                for i in self._by_initials.get(q, ()):
                    # An acronym names the whole entity, so it covers every word.
                    best[i] = max(best.get(i, 0.0), 3.0 + max((self._idf[w] for w in self.entries[i].words), default=0))
                    matched_words[i].update(self.entries[i].words)
            for i, v in best.items():
                scores[i] += v

        by_kind: dict[str, list[tuple[NameEntry, float]]] = defaultdict(list)
        for i, s in scores.items():
            e = self.entries[i]
            coverage = len(matched_words[i]) / max(1, len(e.words)) if e.words else 1.0
            by_kind[e.kind].append((e, s * (0.5 + 0.5 * min(1.0, coverage))))
        out: list[tuple[NameEntry, float]] = []
        for kind, items in by_kind.items():
            if kind not in top_k:
                continue
            items.sort(key=lambda x: (-x[1], len(x[0].name)))
            floor = max(0.3, 0.5 * items[0][1])
            out += [x for x in items if x[1] >= floor][: top_k[kind]]
        return out
