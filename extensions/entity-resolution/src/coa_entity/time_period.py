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
_NUMBER_WORDS = {"two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10}

_FISCAL = r"(?:fy|fiscal(?:\s+year)?)\s*['’-]?\s*(?:(\d{2}|\d{4})\s*[-/–]\s*)?(\d{2}|\d{4})"
_PART_OF_YEAR = re.compile(r"\b(q[1-4]|h[12])\s*[-,]?\s*(?:of\s+)?" + _FISCAL + r"\b", re.IGNORECASE)
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
                elif pattern is _FISCAL_YEAR:
                    fy = _full_year(m.group(2))  # the calendar year it ends in ("FY 2024-25" ends in 2025)
                    if m.group(1):
                        begin = _full_year(m.group(1))
                        fy = fy if fy > begin else begin + 1
                    first = _add_months(fy, end_month, -11)
                    period = Period(
                        f"FY{fy % 100:02d} ({MONTH_NAMES[first[1]]} {first[0]} – {MONTH_NAMES[end_month]} {fy})",
                        f"{col} BETWEEN {_yyyymm(*first)} AND {_yyyymm(fy, end_month)}",
                    )
                elif pattern is _CALENDAR_YEAR:
                    year = _full_year(m.group(1))
                    period = Period(f"calendar {year}", f"{col} BETWEEN {_yyyymm(year, 1)} AND {_yyyymm(year, 12)}")
                elif pattern is _MONTH_YEAR:
                    month = _MONTH_NUMBER.get(m.group(1).lower())
                    if not month:
                        continue  # e.g. "sales 2024": the first word is not a month
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
                        )
                    else:
                        period = Period(
                            f"last {n} fiscal years", f"the {n} most recent fiscal years: {col} > {latest} - {n}00"
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
    explicit = [_PART_OF_YEAR, _FISCAL_YEAR, _CALENDAR_YEAR, _MONTH_YEAR, _NUMERIC_MONTH, _LAST_N]
    periods = scan(explicit) or scan([_PREVIOUS_YEAR, _LATEST_YEAR])
    unique: dict[str, Period] = {}
    for p in periods:
        unique.setdefault(p.condition, p)  # the same filter named twice is listed once
    return list(unique.values())


def time_block(periods: list[Period], spec: TimeSpec) -> str:
    """The SQL prompt text that lists the exact period filters to use."""
    if not periods:
        return ""
    lines = [
        "## Time period (authoritative)",
        f"{spec.column} holds each row's period END as YYYYMM; fiscal years end in "
        f"{MONTH_NAMES[spec.fiscal_year_end_month]}. Apply exactly these filters — do not derive "
        "fiscal-year boundaries yourself. Within a window, a yearly table has one row per company "
        "per fiscal year; on a quarterly or monthly table, aggregate the rows in the window when the "
        "question asks for an annual figure.",
    ]
    lines += [f"- {p.label} → {p.condition}" for p in periods]
    return "\n".join(lines)
