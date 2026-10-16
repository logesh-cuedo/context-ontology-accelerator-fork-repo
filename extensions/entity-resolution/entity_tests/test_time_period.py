# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Time periods: fiscal years/quarters/halves, calendar years, months, relative."""

from __future__ import annotations

import pytest

from coa_entity.time_period import TimeSpec, resolve_periods, time_block

SPEC = TimeSpec(column="yyyymm", fiscal_year_end_month=3)


def conds(query: str, spec: TimeSpec = SPEC) -> list[str]:
    return [p.condition for p in resolve_periods(query, spec)]


@pytest.mark.unit
class TestFiscalYears:
    @pytest.mark.parametrize(
        "q", ["net sales in FY25", "FY 25 sales", "FY'25", "fy2025", "FY 2024-25", "FY24-25", "FY2024-2025",
              "fiscal year 2025 sales"],
    )  # fmt: skip
    def test_fy25_is_apr24_to_mar25(self, q):
        assert conds(q) == ["yyyymm BETWEEN 202404 AND 202503"]

    def test_label(self):
        assert resolve_periods("FY25", SPEC)[0].label == "FY25 (Apr 2024 – Mar 2025)"

    def test_december_year_end(self):
        assert conds("FY25", TimeSpec("period", fiscal_year_end_month=12)) == ["period BETWEEN 202501 AND 202512"]

    def test_two_years(self):
        assert conds("compare FY24 and FY25") == [
            "yyyymm BETWEEN 202304 AND 202403",
            "yyyymm BETWEEN 202404 AND 202503",
        ]


@pytest.mark.unit
class TestPartsAndOthers:
    @pytest.mark.parametrize(
        "q, cond",
        [
            ("Q1 FY25", "yyyymm BETWEEN 202404 AND 202406"),
            ("Q3FY25 sales", "yyyymm BETWEEN 202410 AND 202412"),
            ("Q4 FY 2024-25", "yyyymm BETWEEN 202501 AND 202503"),
            ("H1 FY25", "yyyymm BETWEEN 202404 AND 202409"),
            ("H2 FY25", "yyyymm BETWEEN 202410 AND 202503"),
            ("revenue in CY2024", "yyyymm BETWEEN 202401 AND 202412"),
            ("sales for March 2025", "yyyymm = 202503"),
            ("net sales Mar-24", "yyyymm = 202403"),
            ("sales 03/2025", "yyyymm = 202503"),
        ],
    )
    def test_period(self, q, cond):
        assert conds(q) == [cond]

    def test_quarter_is_not_also_read_as_a_year(self):
        assert len(resolve_periods("Q3 FY25 pat", SPEC)) == 1

    def test_relative(self):
        assert "- 500" in conds("trend for the last 5 years")[0]
        assert "- 300" in conds("last three fiscal years")[0]
        assert "greatest yyyymm per company" in conds("latest year pat of tcs")[0]
        assert "- 199" in conds("previous fiscal year revenue")[0]

    def test_no_period(self):
        assert conds("top 3 pharma companies by net sales") == []

    def test_clarification_reply_is_read_too(self):
        assert conds("pharma net sales\nUser clarification: FY25") == ["yyyymm BETWEEN 202404 AND 202503"]


@pytest.mark.unit
def test_block():
    block = time_block(resolve_periods("FY25", SPEC), SPEC)
    assert block.startswith("## Time period (authoritative)")
    assert "fiscal years end in Mar" in block
    assert "- FY25 (Apr 2024 – Mar 2025) → yyyymm BETWEEN 202404 AND 202503" in block
