# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Tier-2 SQL authoring tool — ``generate_sql`` over an explicitly chosen table set.

Wraps the disciplined SQL writer (:class:`SQLGenerator`) as a Tier-2 function: a
caller picks the tables (via :class:`~coa_serve.tier2.tools.table_tools.TableCatalog`)
and this builds the SAME rich schema context the single-shot NL→SQL path builds
before delegating generation. Keeping generation behind this tool is what stops a
consumer — an agent, an MCP handler — from hand-writing SQL against a schema it
only partially inspected.

The optional ``feedback`` argument is the self-correction channel: the SQL writer
is a stateless temperature-0 function of (question, schema), so a re-generation
without the prior attempt returns byte-identical SQL. Passing the previous
statement and what executing it produced makes the writer REVISE instead.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import structlog

from ..nl_to_sql.sql_generator import SQLGenerator, _build_raw_context, _extract_table_names
from .table_tools import TableCatalog

logger = structlog.get_logger(__name__)


class UnknownTablesError(ValueError):
    """Raised when none of the requested tables have a retrieved schema.

    Signals a caller ordering error (generate before discover), not a backend
    failure: the fix is to search for the tables first.
    """

    def __init__(self, table_names: list[str]):
        """Record the unresolvable table names on the exception."""
        self.table_names = list(table_names)
        super().__init__(f"no known schema for tables {self.table_names}")


@dataclass(frozen=True)
class GeneratedSql:
    """Output of :meth:`SqlAuthoringTool.generate_sql`.

    Attributes:
        sql: The generated statement; empty when the writer produced none.
        confidence: The writer's self-reported confidence (0.0-1.0).
        tables_used: Tables whose schema reached the generation prompt.
        missing_tables: Requested names with no retrieved schema, ignored.
    """

    sql: str
    confidence: float = 0.0
    tables_used: list[str] = field(default_factory=list)
    missing_tables: list[str] = field(default_factory=list)


class SqlAuthoringTool:
    """Generate SQL from a question plus the schema of caller-chosen tables."""

    def __init__(
        self,
        sql_generator: SQLGenerator,
        catalog: TableCatalog,
        *,
        model_id: str | None = None,
        dialect: str | None = None,
        entities: str = "",  # cuedo-ext: entity-resolution prompt section
    ):
        """Bind the tool to the SQL writer and the catalog holding the schemas.

        Args:
            sql_generator: Retrieval-grounded LLM SQL generator (the writer).
            catalog: Catalog the chosen table names are resolved against.
            model_id: Optional per-request LLM model override.
            dialect: Optional SQL dialect override; ``None`` keeps the
                generator's configured default.
            entities: cuedo-ext — entity filters resolved for this request
                (extensions/entity-resolution); empty → none.
        """
        self._sql_generator = sql_generator
        self._catalog = catalog
        self._model_id = model_id
        self._dialect = dialect
        self._entities = entities  # cuedo-ext

    async def generate_sql(
        self,
        question: str,
        table_names: list[str],
        *,
        evidence: str = "",
        feedback: str = "",
    ) -> GeneratedSql:
        """Write a query for ``question`` using only ``table_names``' schema.

        Args:
            question: The natural-language question to answer.
            table_names: Tables to expose to the writer; names with no
                retrieved schema are ignored (reported as ``missing_tables``).
            evidence: Optional caller-supplied hints (already capped).
            feedback: Optional prior attempt + observation to revise from.

        Returns:
            The generated SQL and the tables it was written against.

        Raises:
            UnknownTablesError: If no requested table has a retrieved schema.
        """
        hits, missing = self._catalog.hits_for_tables(table_names)
        if not hits:
            raise UnknownTablesError(list(table_names or []))

        names = [_extract_table_names([hit])[0] for hit in hits if _extract_table_names([hit])]
        ddl_context = _build_raw_context(hits, names)
        sql, confidence = await self._sql_generator.generate_from_context(
            question,
            ddl_context,
            evidence=evidence,
            model_id=self._model_id,
            dialect=self._dialect,
            feedback=feedback,
            entities=self._entities,  # cuedo-ext
        )
        return GeneratedSql(sql=sql, confidence=confidence, tables_used=names, missing_tables=missing)
