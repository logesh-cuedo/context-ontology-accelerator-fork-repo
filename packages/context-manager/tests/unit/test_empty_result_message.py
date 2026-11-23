"""cuedo-ext: a Tier-2 query with no rows is answered with a sentence, not a bare empty table."""

from coa_serve.response_assembler import NO_ROWS_MESSAGE, ResponseAssembler
from coa_serve.tier2.nl_to_sql.sql_generator import NLtoSQLResult, _build_system_prompt, _extract_empty_message
from coa_serve.tier2.nl_to_sql.strategy import _ext_cache_entry, _ext_cached_result
from coa_serve.trace import TraceCollector

REPLY = (
    "```sql\nSELECT 1\n```\nConfidence: 0.9\nDirection: x=na\n"
    "Empty result: No results: Q2 FY27 (Jul-Sep 2026) results are not in the data yet.\n"
)


def _assemble(rows: list[dict], empty_message: str) -> object:
    return ResponseAssembler().assemble_nl_to_sql(
        rows=rows,
        columns=list(rows[0]) if rows else [],
        sql_used="SELECT 1",
        confidence=0.9,
        retrieved_tables=[],
        expanded_tables=[],
        trace=TraceCollector(),
        namespace="ns",
        empty_message=empty_message,
    )


def test_system_prompt_asks_for_the_sentence():
    assert "Empty result:" in _build_system_prompt("athena")


def test_sentence_is_read_from_the_reply():
    assert _extract_empty_message(REPLY) == "No results: Q2 FY27 (Jul-Sep 2026) results are not in the data yet."
    assert _extract_empty_message("**Empty result:** No company met the test.") == "No company met the test."
    assert _extract_empty_message("```sql\nSELECT 1\n```\nConfidence: 0.9") == ""


def test_no_rows_returns_the_sentence():
    result = _assemble([], "No company met the 20% PAT growth test for Q3 FY26.")
    assert result.synthesized_answer == "No company met the 20% PAT growth test for Q3 FY26."
    assert result.result_rows == []


def test_no_rows_without_a_sentence_uses_the_default():
    assert _assemble([], "").synthesized_answer == NO_ROWS_MESSAGE


def test_rows_returned_means_no_sentence():
    assert _assemble([{"a": 1}], "No company met the test.").synthesized_answer is None


def test_sentence_survives_the_cache():
    entry = _ext_cache_entry("SELECT 1", 0.9, NLtoSQLResult(sql="SELECT 1", empty_message="Nothing matched."))
    assert entry["empty_message"] == "Nothing matched."
    assert _ext_cached_result(entry).empty_message == "Nothing matched."
    assert _ext_cached_result({"sql": "SELECT 1"}).empty_message == ""
