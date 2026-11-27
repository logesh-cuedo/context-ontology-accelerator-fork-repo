# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Turn "FY25", "Q3 FY25", "last 3 years" etc. into an exact period filter.

Plain rules (regular expressions), set up by the ``time`` block of the entity config::

    "time": {"column": "yyyymm", "format": "YYYYMM", "fiscalYearEndMonth": 3}

``column`` holds each row's period END. With ``fiscalYearEndMonth`` 3 (Indian
fiscal year), FY25 runs from Apr 2024 to Mar 2025, so it becomes
``yyyymm BETWEEN 202404 AND 202503``. A range is used so that companies whose
year ends in another month are still included.

Understood (upper or lower case):
  fiscal year     FY25, FY 25, FY'25, FY2025, FY24-25, FY 2024-25, fiscal year 2025
  fiscal quarter  Q3 FY25, Q3FY25, Q3 FY2024-25
  fiscal half     H1 FY25, H2 FY2025
  calendar year   CY2024, calendar year 2024
  month           March 2025, Mar 2025, Mar-25, 03/2025
  relative        last N (fiscal) years, last N quarters; and only when nothing
                  else matched: previous fiscal year, latest / last / current year
"""

from __future__ import annotations

import re
from dataclasses import dataclass

MONTH_NAMES = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
_MONTH_NUMBER = {
    "jan": 1, "january": 1, "feb": 2, "february": 2, "mar": 3, "march": 3, "apr": 4, "april": 4,
    "may": 5, "jun": 6, "june": 6, "jul": 7, "july": 7, "aug": 8, "august": 8,
    "sep": 9, "sept": 9, "september": 9, "oct": 10, "october": 10, "nov": 11, "november": 11,
    "dec": 12, "december": 12,
}  # fmt: skip
# How far back a period may be carried; matches the entity carry's history window.
_CARRY_TURNS = 3
# Words that turn the periods after them into ones to EXCLUDE ("... but not in FY25").
# The block says "apply exactly these filters", so a period listed there is one the
# answer is restricted TO. An excluded period emitted the same way inverts the
# question — "grew in FY22-24 but NOT in FY25" came back filtered to FY25.
_NEGATION = re.compile(
    r"\b(?:but\s+not|not\s+in|except|excluding|other\s+than"
    r"|did\s*n[o\']?t|have\s*n[o\']?t|has\s*n[o\']?t|were\s*n[o\']?t|was\s*n[o\']?t|failed\s+to)\b",
    re.IGNORECASE,
)
# Where an exclusion ENDS: "have not grown in FY24, but did in FY25" — the period after
# the contrast is one the answer must HAVE. Without it every period after the negation
# was excluded, so FY25 was ruled out by the very question that asks for it.
_CONTRAST = re.compile(r"\b(?:but\s+(?:did|does|do|has|have|had|was|were|is|are)|yet)\b", re.IGNORECASE)
# A month named with a day is a calendar DAY, not a month: "January 15, 2020" read "15"
# as the year 2015, and "1st April 2020" became a whole-month filter on a daily table.
# Days are left to the SQL writer, which filters them on the table's date column.
_DAY_BEFORE = re.compile(r"\b\d{1,2}(?:st|nd|rd|th)?\s+(?:of\s+)?$", re.IGNORECASE)
_DAY_AFTER = re.compile(r"\s*(?:st|nd|rd|th)?\s*,?\s*\d{4}\b", re.IGNORECASE)
_NUMBER_WORDS = {"two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10}

_FISCAL = r"(?:fy|fiscal(?:\s+year)?)\s*['’-]?\s*(?:(\d{2}|\d{4})\s*[-/–]\s*)?(\d{2}|\d{4})"
_PART_OF_YEAR = re.compile(r"\b(q[1-4]|h[12])\s*[-,]?\s*(?:of\s+)?" + _FISCAL + r"\b", re.IGNORECASE)
# Months-to-date from the fiscal year start: 9MFY26 is Apr–Dec 2025, the first nine
# months of FY26. Analysts write these constantly ("9MFY26", "3M FY26"), and without
# them the span was dropped from the question entirely — a filter the user asked for
# simply did not reach the SQL.
_MONTHS_TO_DATE = re.compile(r"\b(3|6|9|12)\s*m\s*[-,]?\s*(?:of\s+)?" + _FISCAL + r"\b", re.IGNORECASE)
_FISCAL_YEAR = re.compile(r"\b" + _FISCAL + r"\b", re.IGNORECASE)
_CALENDAR_YEAR = re.compile(r"\b(?:cy|calendar\s+year)\s*['’-]?\s*(\d{2}|\d{4})\b", re.IGNORECASE)
_MONTH_YEAR = re.compile(r"\b([a-z]{3,9})[\s\-'’]+(\d{2}|\d{4})\b", re.IGNORECASE)
_NUMERIC_MONTH = re.compile(r"\b(0?[1-9]|1[0-2])/(\d{4})\b")
_LAST_N = re.compile(
    r"\b(?:last|past|previous|recent)\s+(\d+|two|three|four|five|six|seven|eight|nine|ten)\s+"
    r"(fiscal\s+years?|financial\s+years?|years?|quarters?)\b",
    re.IGNORECASE,
)
_PREVIOUS_YEAR = re.compile(r"\b(?:previous|prior|preceding)\s+(?:fiscal\s+|financial\s+)?year\b", re.IGNORECASE)
_LATEST_YEAR = re.compile(
    r"\b(?:latest|last|current|recent|most\s+recent|this)\s+(?:fiscal\s+|financial\s+|full\s+)?year\b", re.IGNORECASE
)
# A question asking across time names no period this module can pin, but it is NOT a
# question without one: carrying the previous turn's single year into it filters a
# multi-year answer down to that one year ("show the trend" after an FY25 question
# charted a single point). These spans say "every period", so the carry stands down
# and the SQL writer is left unconstrained, which is what the question asks for.
_SPANS_TIME = re.compile(
    r"\b(?:all\s+(?:years|periods|time|quarters)|every\s+(?:year|quarter|period)|full\s+history"
    r"|over\s+the\s+years|year[\s-]on[\s-]year|yoy|q[\s-]?o[\s-]?q|cagr|trend|trends|history"
    r"|growth\s+over|since\s+\d{2,4}|from\s+\d{4}|between\s+\d{4})\b",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class TimeSpec:
    """How periods are stored: the period-end column and the month fiscal years end in."""

    column: str
    fiscal_year_end_month: int = 3
    format: str = "YYYYMM"


@dataclass(frozen=True)
class Period:
    """One period: a label for the trace, and the SQL condition to use."""

    label: str
    condition: str
    relative: bool = False  # counted back from the latest data ("last 8 quarters")


# ── date helpers (a month is a (year, month) pair; YYYYMM = year * 100 + month) ──


def _full_year(text: str) -> int:
    year = int(text)
    return year + 2000 if year < 100 else year


def _yyyymm(year: int, month: int) -> int:
    return year * 100 + month


def _add_months(year: int, month: int, months: int) -> tuple[int, int]:
    index = year * 12 + (month - 1) + months
    return index // 12, index % 12 + 1


def resolve_periods(query: str, spec: TimeSpec) -> list[Period]:
    """Every time period in the question, as exact conditions on ``spec.column``."""
    text = query.replace("\nUser clarification:", " ")
    col, end_month = spec.column, spec.fiscal_year_end_month
    latest = f"(SELECT MAX({col}) FROM <same table>)"
    used_spans: list[tuple[int, int]] = []

    def scan(patterns: list[re.Pattern]) -> list[Period]:
        """Periods found by ``patterns``, in order. Text already used by one period is skipped."""
        found = []
        for pattern in patterns:
            for m in pattern.finditer(text):
                start, end = m.span()
                if any(a < end and start < b for a, b in used_spans):
                    continue
                if pattern is _PART_OF_YEAR:  # Q1–Q4 or H1/H2 of a fiscal year
                    part, fy = m.group(1).upper(), _full_year(m.group(3))
                    length = 3 if part.startswith("Q") else 6
                    first = _add_months(*_add_months(fy, end_month, -11), length * (int(part[1]) - 1))
                    last = _add_months(*first, length - 1)
                    if length == 3:
                        label = f"{part} FY{fy % 100:02d} ({MONTH_NAMES[first[1]]}–{MONTH_NAMES[last[1]]} {last[0]})"
                    else:
                        label = (
                            f"{part} FY{fy % 100:02d} "
                            f"({MONTH_NAMES[first[1]]} {first[0]} – {MONTH_NAMES[last[1]]} {last[0]})"
                        )
                    period = Period(label, f"{col} BETWEEN {_yyyymm(*first)} AND {_yyyymm(*last)}")
                elif pattern is _MONTHS_TO_DATE:
                    months, fy = int(m.group(1)), _full_year(m.group(3))
                    first = _add_months(fy, end_month, -11)  # the fiscal year's first month
                    last = _add_months(*first, months - 1)
                    period = Period(
                        f"{months}M FY{fy % 100:02d} "
                        f"({MONTH_NAMES[first[1]]} {first[0]} – {MONTH_NAMES[last[1]]} {last[0]})",
                        f"{col} BETWEEN {_yyyymm(*first)} AND {_yyyymm(*last)}",
                    )
                elif pattern is _FISCAL_YEAR:
                    fy = _full_year(m.group(2))  # the calendar year it ends in ("FY 2024-25" ends in 2025)
                    if m.group(1):
                        begin = _full_year(m.group(1))
                        fy = fy if fy > begin else begin + 1
                    first = _add_months(fy, end_month, -11)
                    # The END month alone, not the twelve months it covers. The column
                    # marks where a period ENDS, so one row per period sits inside a
                    # fiscal year's span: the quarterly rows of FY25 end 202406, 202409,
                    # 202412 and 202503, and a BETWEEN over the whole year selected all
                    # four alongside the yearly row — "net sales in FY25" against a
                    # quarterly table summed the year roughly twice. A quarter's own
                    # window is narrow enough that no other period ends inside it, which
                    # is why only the year was wrong. The label still names the span,
                    # because that is what the user asked for.
                    period = Period(
                        f"FY{fy % 100:02d} ({MONTH_NAMES[first[1]]} {first[0]} – {MONTH_NAMES[end_month]} {fy})",
                        f"{col} = {_yyyymm(fy, end_month)}",
                    )
                elif pattern is _CALENDAR_YEAR:
                    year = _full_year(m.group(1))
                    period = Period(f"calendar {year}", f"{col} BETWEEN {_yyyymm(year, 1)} AND {_yyyymm(year, 12)}")
                elif pattern is _MONTH_YEAR:
                    month = _MONTH_NUMBER.get(m.group(1).lower())
                    if not month:
                        continue  # e.g. "sales 2024": the first word is not a month
                    if _DAY_BEFORE.search(text[:start]) or (len(m.group(2)) == 2 and _DAY_AFTER.match(text, end)):
                        continue  # a calendar day, see _DAY_BEFORE
                    year = _full_year(m.group(2))
                    period = Period(f"{MONTH_NAMES[month]} {year}", f"{col} = {_yyyymm(year, month)}")
                elif pattern is _NUMERIC_MONTH:
                    year, month = int(m.group(2)), int(m.group(1))
                    period = Period(f"{MONTH_NAMES[month]} {year}", f"{col} = {_yyyymm(year, month)}")
                elif pattern is _LAST_N:
                    word = m.group(1).lower()
                    n = int(word) if word.isdigit() else _NUMBER_WORDS[word]
                    if m.group(2).lower().startswith("quarter"):
                        period = Period(
                            f"last {n} quarters",
                            f"the {n} most recent quarter-end values of {col} present in the table "
                            f"({col} >= the {n}th-latest distinct {col})",
                            relative=True,
                        )
                    else:
                        period = Period(
                            f"last {n} fiscal years",
                            f"the {n} most recent fiscal years: {col} > {latest} - {n}00",
                            relative=True,
                        )
                elif pattern is _PREVIOUS_YEAR:
                    period = Period(
                        "previous fiscal year",
                        f"the fiscal year before the latest: {col} BETWEEN {latest} - 199 AND {latest} - 100",
                    )
                else:  # _LATEST_YEAR
                    period = Period(
                        "latest fiscal year",
                        f"each company's latest annual period: the row with the greatest {col} per company",
                    )
                used_spans.append((start, end))
                found.append(period)
        return found

    # "previous year" / "latest year" are used only when no exact period was named.
    explicit = [_PART_OF_YEAR, _MONTHS_TO_DATE, _FISCAL_YEAR, _CALENDAR_YEAR, _MONTH_YEAR, _NUMERIC_MONTH, _LAST_N]
    periods = scan(explicit) or scan([_PREVIOUS_YEAR, _LATEST_YEAR])
    unique: dict[str, Period] = {}
    for p in periods:
        unique.setdefault(p.condition, p)  # the same filter named twice is listed once
    return list(unique.values())


def negated_from(query: str) -> int:
    """Character offset where an exclusion starts ("but not in FY25"), or -1."""
    m = _NEGATION.search(query)
    return m.start() if m else -1


def time_block(periods: list[Period], spec: TimeSpec, excluded: list[Period] | None = None) -> str:
    """The SQL prompt text that lists the exact period filters to use.

    ``excluded`` are periods the question ruled OUT. They are named separately rather
    than dropped: the writer still needs their dates to test that the condition does
    not hold there, and listing them beside the included ones would invert the question.
    """
    if not periods and not excluded:
        return ""
    lines = [
        "## Time period (authoritative)",
        f"{spec.column} holds each row's period END as YYYYMM; fiscal years end in "
        f"{MONTH_NAMES[spec.fiscal_year_end_month]}. Apply exactly these filters as written — do not "
        "widen them, and do not derive the period boundaries yourself. A filter naming one month "
        "selects that period's single row; a range selects the periods ending inside it, which on a "
        "quarterly table is several rows to aggregate when the question asks for one figure.",
    ]
    lines += [f"- {p.label} → {p.condition}" for p in periods]
    if excluded:
        lines.append(
            "The question EXCLUDES the periods below: the condition must NOT hold in them. "
            "Do not restrict the answer to these — test them and reject the rows that match."
        )
        lines += [f"- NOT {p.label} → {p.condition}" for p in excluded]
    return "\n".join(lines)


def split_periods(query: str, spec: TimeSpec) -> tuple[list[Period], list[Period]]:
    """The question's periods as (required, excluded), split at "but not" / "except".

    Resolving the whole question at once cannot tell the two apart, so an excluded
    period arrived as one to filter ON and the answer came back about the very period
    the user ruled out.
    """
    cut = negated_from(query)
    if cut < 0:
        return resolve_periods(query, spec), []
    back = _CONTRAST.search(query, cut + 1)  # "..., but did in FY25": required again
    stop = back.start() if back else len(query)
    required = resolve_periods(query[:cut] + " " + query[stop:], spec)
    keys = {p.condition for p in required}
    # A relative window is not excluded: in "not grown in the last eight quarters, but
    # did in the latest quarter" the eight are counted back from the latest quarter,
    # which this module cannot see, and excluding the 8 latest would rule out the very
    # quarter the question asks for. It is left to the SQL writer, which has the question.
    negated = resolve_periods(query[cut:stop], spec)
    excluded = [p for p in negated if p.condition not in keys and not p.relative]
    return required, excluded


def carried_period(query: str, history: list[dict[str, str]] | None, spec: TimeSpec) -> list[Period]:
    """The question's own periods, else the ones the last question named.

    A follow-up says "that year" or "and the margin?" and names no period of its
    own. Nothing downstream can recover the one it means: Tier 2 is given the
    question alone, so the SQL writer resolves "that year" against TODAY and
    answers about the current fiscal year instead of the one on screen — measured
    as FY26 for a conversation about FY25.

    Read from the earlier QUESTION, not from the answer: the period is in the
    words the user wrote, and re-reading our own reply would carry back whatever
    period the SQL happened to use. Only a question that names no period carries;
    one that names its own is about that period, whatever came before.

    A question that asks ACROSS time ("show the trend", "all years", "yoy") names no
    single period either, but carrying one into it is worse than carrying nothing: it
    cuts a multi-year answer down to the one year the previous question asked about.
    Those stand down and leave the window to the SQL writer.
    """
    if own := split_periods(query, spec)[0]:
        return own
    # It names periods, but split_periods ruled them out or left them to the writer
    # ("not ... in the last eight quarters, but did in the latest quarter"). Reading the
    # whole question again would bring them back as periods to filter ON.
    if resolve_periods(query, spec):
        return []
    if _SPANS_TIME.search(query):
        return []
    if _NEGATION.search(query):  # "but not in FY25" alone: the exclusion is the question
        return []
    asked = [t for t in (history or []) if t.get("role") == "user"]
    # The same window the entity carry uses. Without it the walk runs to the start of
    # the conversation and a period named twenty turns ago — long since moved on from —
    # is applied to the question on screen.
    for turn in reversed(asked[-_CARRY_TURNS:]):
        # Only what the earlier question was ABOUT. Reading it whole carried its
        # exclusions back as periods to filter on — "growth in FY24 but not FY25"
        # made a follow-up answer about FY25, the year ruled out.
        earlier, _ = split_periods(str(turn.get("content") or ""), spec)
        if earlier:
            return earlier
    return []
