# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Time-period resolution: "FY25", "Q3 FY25", "last 3 years" → an exact period filter.

Deterministic (no LLM) and driven by the entity config's ``time`` block::

    "time": {"column": "yyyymm", "format": "YYYYMM", "fiscalYearEndMonth": 3}

``column`` holds each row's period END. With ``fiscalYearEndMonth`` 3 (Indian
fiscal year), FY25 runs Apr 2024 – Mar 2025, so it resolves to
``yyyymm BETWEEN 202404 AND 202503`` — a window, so companies whose year ends in
another month are still included.

Recognised (case-insensitive):
  fiscal year     FY25, FY 25, FY'25, FY2025, FY24-25, FY 2024-25, fiscal year 2025
  fiscal quarter  Q3 FY25, Q3FY25, Q3 FY2024-25
  fiscal half     H1 FY25, H2 FY2025
  calendar year   CY2024, calendar year 2024
  month           March 2025, Mar 2025, Mar-25, 03/2025
  relative        latest / last / current / recent fiscal year (or "year"),
                  previous fiscal year, last N (fiscal) years, last N quarters
"""

from __future__ import annotations

import re
from dataclasses import dataclass

_MONTHS = {
    m: i
    for i, names in enumerate(
        [
            ("jan", "january"), ("feb", "february"), ("mar", "march"), ("apr", "april"), ("may",),
            ("jun", "june"), ("jul", "july"), ("aug", "august"), ("sep", "sept", "september"),
            ("oct", "october"), ("nov", "november"), ("dec", "december"),
        ],
        start=1,
    )
    for m in names
}  # fmt: skip
_MONTH_NAME = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
_WORDS = {"two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10}


@dataclass(frozen=True)
class TimeSpec:
    """How periods are stored: the period-end column and the fiscal-year end month."""

    column: str
    fiscal_year_end_month: int = 3
    format: str = "YYYYMM"


@dataclass(frozen=True)
class Period:
    """One resolved period: a label for the trace and the SQL condition to apply."""

    label: str
    condition: str


def _year(text: str) -> int:
    y = int(text)
    return y + 2000 if y < 100 else y


def _ym(year: int, month: int) -> int:
    return year * 100 + month


def _shift(year: int, month: int, months: int) -> tuple[int, int]:
    """(year, month) moved by ``months`` (may be negative)."""
    idx = year * 12 + (month - 1) + months
    return idx // 12, idx % 12 + 1


def _fy_window(fy_end_year: int, end_month: int) -> tuple[int, int]:
    """(start, end) YYYYMM of the fiscal year ending in ``end_month`` of ``fy_end_year``."""
    sy, sm = _shift(fy_end_year, end_month, -11)
    return _ym(sy, sm), _ym(fy_end_year, end_month)


def _fy_label(fy_end_year: int, end_month: int) -> str:
    start, end = _fy_window(fy_end_year, end_month)
    return (
        f"FY{fy_end_year % 100:02d} ({_MONTH_NAME[start % 100]} {start // 100} – {_MONTH_NAME[end % 100]} {end // 100})"
    )


_FY = re.compile(r"\b(?:fy|fiscal(?:\s+year)?)\s*['’-]?\s*(?:(\d{2}|\d{4})\s*[-/–]\s*)?(\d{2}|\d{4})\b", re.IGNORECASE)
_QFY = re.compile(
    r"\b(q[1-4]|h[12])\s*[-,]?\s*(?:of\s+)?(?:fy|fiscal(?:\s+year)?)\s*['’-]?\s*(?:(\d{2}|\d{4})\s*[-/–]\s*)?(\d{2}|\d{4})\b",
    re.IGNORECASE,
)
_CY = re.compile(r"\b(?:cy|calendar\s+year)\s*['’-]?\s*(\d{2}|\d{4})\b", re.IGNORECASE)
_MONTH_YEAR = re.compile(r"\b([a-z]{3,9})[\s\-'’]+(\d{2}|\d{4})\b", re.IGNORECASE)
_NUM_MONTH = re.compile(r"\b(0?[1-9]|1[0-2])/(\d{4})\b")
_LAST_N = re.compile(
    r"\b(?:last|past|previous|recent)\s+(\d+|two|three|four|five|six|seven|eight|nine|ten)\s+"
    r"(fiscal\s+years?|financial\s+years?|years?|quarters?)\b",
    re.IGNORECASE,
)
_LATEST = re.compile(
    r"\b(?:latest|last|current|recent|most\s+recent|this)\s+(?:fiscal\s+|financial\s+|full\s+)?year\b", re.IGNORECASE
)
_PREVIOUS = re.compile(r"\b(?:previous|prior|preceding)\s+(?:fiscal\s+|financial\s+)?year\b", re.IGNORECASE)


def resolve_periods(query: str, spec: TimeSpec) -> list[Period]:
    """Every time period the question names, as exact conditions on ``spec.column``."""
    col, m = spec.column, spec.fiscal_year_end_month
    text = query.replace("\nUser clarification:", " ")
    out: list[Period] = []
    consumed: list[tuple[int, int]] = []

    def take(match: re.Match) -> bool:
        span = match.span()
        if any(a < span[1] and span[0] < b for a, b in consumed):
            return False
        consumed.append(span)
        return True

    for mt in _QFY.finditer(text):
        if not take(mt):
            continue
        part, fy = mt.group(1).upper(), _year(mt.group(3))
        start_y, start_m = _shift(fy, m, -11)
        if part.startswith("Q"):
            k = int(part[1])
            qs = _shift(start_y, start_m, 3 * (k - 1))
            qe = _shift(qs[0], qs[1], 2)
            lo, hi = _ym(*qs), _ym(*qe)
            label = f"{part} FY{fy % 100:02d} ({_MONTH_NAME[qs[1]]}–{_MONTH_NAME[qe[1]]} {qe[0]})"
        else:
            h = int(part[1])
            hs = _shift(start_y, start_m, 6 * (h - 1))
            he = _shift(hs[0], hs[1], 5)
            lo, hi = _ym(*hs), _ym(*he)
            label = f"{part} FY{fy % 100:02d} ({_MONTH_NAME[hs[1]]} {hs[0]} – {_MONTH_NAME[he[1]]} {he[0]})"
        out.append(Period(label, f"{col} BETWEEN {lo} AND {hi}"))

    for mt in _FY.finditer(text):
        if not take(mt):
            continue
        fy = _year(mt.group(2))
        if mt.group(1):  # "FY 2024-25": the second year is the fiscal year's end
            first = _year(mt.group(1))
            fy = fy if fy > first else first + 1
        lo, hi = _fy_window(fy, m)
        out.append(Period(_fy_label(fy, m), f"{col} BETWEEN {lo} AND {hi}"))

    for mt in _CY.finditer(text):
        if take(mt):
            y = _year(mt.group(1))
            out.append(Period(f"calendar {y}", f"{col} BETWEEN {_ym(y, 1)} AND {_ym(y, 12)}"))

    for mt in _MONTH_YEAR.finditer(text):
        month = _MONTHS.get(mt.group(1).lower())
        if month and take(mt):
            y = _year(mt.group(2))
            out.append(Period(f"{_MONTH_NAME[month]} {y}", f"{col} = {_ym(y, month)}"))
    for mt in _NUM_MONTH.finditer(text):
        if take(mt):
            y, month = int(mt.group(2)), int(mt.group(1))
            out.append(Period(f"{_MONTH_NAME[month]} {y}", f"{col} = {_ym(y, month)}"))

    for mt in _LAST_N.finditer(text):
        if not take(mt):
            continue
        raw = mt.group(1).lower()
        n = int(raw) if raw.isdigit() else _WORDS[raw]
        if mt.group(2).lower().startswith("quarter"):
            out.append(
                Period(
                    f"last {n} quarters",
                    f"the {n} most recent quarter-end values of {col} present in the table "
                    f"({col} >= the {n}th-latest distinct {col})",
                )
            )
        else:
            out.append(
                Period(
                    f"last {n} fiscal years",
                    f"the {n} most recent fiscal years: {col} > (SELECT MAX({col}) FROM <same table>) - {n}00",
                )
            )

    if not out:
        for mt in _PREVIOUS.finditer(text):
            if take(mt):
                out.append(
                    Period(
                        "previous fiscal year",
                        f"the fiscal year before the latest: {col} BETWEEN (SELECT MAX({col}) FROM <same table>) - 199 "
                        f"AND (SELECT MAX({col}) FROM <same table>) - 100",
                    )
                )
        for mt in _LATEST.finditer(text):
            if take(mt):
                out.append(
                    Period(
                        "latest fiscal year",
                        f"each company's latest annual period: the row with the greatest {col} per company",
                    )
                )
    unique: dict[str, Period] = {}
    for p in out:
        unique.setdefault(p.condition, p)
    return list(unique.values())


def time_block(periods: list[Period], spec: TimeSpec) -> str:
    """SQL-prompt section stating the exact period filters to apply."""
    if not periods:
        return ""
    lines = [
        "## Time period (authoritative)",
        f"{spec.column} holds each row's period END as YYYYMM; fiscal years end in "
        f"{_MONTH_NAME[spec.fiscal_year_end_month]}. Apply exactly these filters — do not derive "
        "fiscal-year boundaries yourself. Within a window, a yearly table has one row per company "
        "per fiscal year; on a quarterly or monthly table, aggregate the rows in the window when the "
        "question asks for an annual figure.",
    ]
    lines += [f"- {p.label} → {p.condition}" for p in periods]
    return "\n".join(lines)
