"""Period resolution in the entity extension: days, exclusions and contrasts."""

import pytest
from coa_entity.time_period import TimeSpec, carried_period, split_periods

SPEC = TimeSpec(column="yyyymm", fiscal_year_end_month=3)


def labels(query: str) -> tuple[list[str], list[str]]:
    required, excluded = split_periods(query, SPEC)
    return [p.label for p in required], [p.label for p in excluded]


@pytest.mark.parametrize(
    "query",
    [
        "median P/E as on end of yesterday, and January 15, 2020",  # "15" is the day, not 2015
        "total market cap as on 1st April 2020",
        "market cap on April 1, 2020",
    ],
)
def test_a_calendar_day_is_not_a_month(query):
    assert labels(query) == ([], [])


def test_a_month_and_year_is_still_a_month():
    assert labels("net sales in January 2020") == (["Jan 2020"], [])
    assert labels("PAT in Jan-25") == (["Jan 2025"], [])


def test_periods_after_but_not_are_excluded():
    required, excluded = labels("20% revenue growth in FY22, FY23, FY24, but not in FY25 and 9MFY26?")
    assert [r[:4] for r in required] == ["FY22", "FY23", "FY24"]
    assert sorted(e[:7] for e in excluded) == ["9M FY26", "FY25 (A"]


def test_a_contrast_ends_the_exclusion():
    required, excluded = labels("companies that did not grow in FY24, but did grow in FY25")
    assert [r[:4] for r in required] == ["FY25"]
    assert [e[:4] for e in excluded] == ["FY24"]


def test_a_relative_window_is_never_excluded():
    # The eight quarters are counted back from the latest one, which the question requires.
    query = (
        "companies which have not delivered 20% PAT growth in the last eight quarters, but did in the latest quarter"
    )
    assert labels(query) == ([], [])


def test_the_carry_never_brings_back_a_period_the_split_left_out():
    query = (
        "companies which have not delivered 20% PAT growth in the last eight quarters, but did in the latest quarter"
    )
    history = [{"role": "user", "content": "net sales in FY25"}]
    assert carried_period(query, history, SPEC) == []


def test_the_carry_still_fills_a_follow_up_with_no_period():
    history = [{"role": "user", "content": "net sales of TCS in FY25"}]
    assert [p.label[:4] for p in carried_period("and the PAT?", history, SPEC)] == ["FY25"]
