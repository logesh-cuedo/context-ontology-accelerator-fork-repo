# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Entity config: which tables and columns hold the companies, sectors, etc.

The configuration is a JSON document in SSM Parameter Store:

    {ssm_prefix}/entities/{namespace_id}   per-namespace override (optional)
    {ssm_prefix}/entities/default          used when there is no override

No parameter means the feature is off for that namespace. Example: see
``entities.sample.json``. Fields of one entity type:

``type``            name of this kind, e.g. company (used in the index, questions to the user and the SQL prompt)
``table``           table holding one row per entity
``database``        optional: use this database instead of searching the namespace's sources
``idColumn`` / ``nameColumn``  unique key and display name
``filterColumn``    column to filter on in the data tables (default: nameColumn)
``describeColumns`` extra columns shown next to the name
``acronyms``        also save the short form ("Tata Consultancy Services" is TCS)
``topK``            how many results the search returns
``groups``          columns whose values are searchable too (e.g. sector):
                    ``column``, ``childColumn``, ``filterColumn``, ``filterWithMember``
                    (picking a company also filters on its sector), ``topK``

An optional ``time`` block describes the period column (see ``time_period``). It is
still accepted but no longer used: serve does not add time periods to the SQL prompt.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from typing import Any

from .time_period import TimeSpec

DEFAULT_PARAMETER = "default"
_IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
_TYPE_NAME = re.compile(r"^[a-z][a-z0-9_-]{0,31}$")


class EntityConfigError(ValueError):
    """The entity config is not valid."""


@dataclass(frozen=True)
class GroupSpec:
    """A column whose values are searchable too (e.g. a sector)."""

    type: str
    column: str
    child_column: str = ""
    filter_column: str = ""
    top_k: int = 5
    filter_with_member: bool = False

    @property
    def sql_column(self) -> str:
        """The column to filter on in the data tables."""
        return self.filter_column or self.column


@dataclass(frozen=True)
class EntityTypeSpec:
    """One kind of entity read from one table (e.g. companies)."""

    type: str
    table: str
    id_column: str
    name_column: str
    filter_column: str = ""
    database: str = ""
    describe_columns: tuple[str, ...] = ()
    acronyms: bool = False
    top_k: int = 10
    groups: tuple[GroupSpec, ...] = ()

    @property
    def sql_column(self) -> str:
        """The column to filter on in the data tables."""
        return self.filter_column or self.name_column

    @property
    def columns(self) -> list[str]:
        """Every column the index build reads, id and name first, no duplicates."""
        cols = [self.id_column, self.name_column, *self.describe_columns]
        for g in self.groups:
            cols.append(g.column)
            if g.child_column:
                cols.append(g.child_column)
        return list(dict.fromkeys(cols))


@dataclass(frozen=True)
class KindInfo:
    """One searchable kind. Companies and sectors both use this same shape."""

    type: str
    is_group: bool
    table: str  # the entity table it is read from (e.g. sectors)
    table_column: str  # its name column in that table (company_name / cd_sector)
    sql_column: str  # the column to filter on in data tables (company_name / sector)
    id_column: str  # "" for a group: the value itself is the id
    top_k: int
    parent: str = ""  # group only: the entity type whose table holds it


@dataclass(frozen=True)
class EntityConfig:
    """All entity types (and the optional time block) configured for a namespace."""

    entity_types: tuple[EntityTypeSpec, ...] = ()
    time: TimeSpec | None = None

    def kind_infos(self) -> list[KindInfo]:
        """Every searchable kind: each entity type, followed by its groups."""
        kinds = []
        for spec in self.entity_types:
            kinds.append(
                KindInfo(spec.type, False, spec.table, spec.name_column, spec.sql_column, spec.id_column, spec.top_k)
            )
            for g in spec.groups:
                kinds.append(KindInfo(g.type, True, spec.table, g.column, g.sql_column, "", g.top_k, spec.type))
        return kinds

    def kinds(self) -> list[tuple[str, int]]:
        """(type, top_k) for every searchable kind."""
        return [(k.type, k.top_k) for k in self.kind_infos()]

    def kind(self, name: str) -> KindInfo | None:
        """The kind called ``name``, or None."""
        return next((k for k in self.kind_infos() if k.type == name), None)

    def member_spec(self, name: str) -> EntityTypeSpec | None:
        """The entity type called ``name`` (None for a group or unknown name)."""
        return next((s for s in self.entity_types if s.type == name), None)

    def group_spec(self, name: str) -> GroupSpec | None:
        """The group called ``name`` (None for an entity type or unknown name)."""
        return next((g for s in self.entity_types for g in s.groups if g.type == name), None)

    def sql_column(self, name: str) -> str:
        """The filter column of any kind; "" if unknown."""
        kind = self.kind(name)
        return kind.sql_column if kind else ""


# ── parsing ──────────────────────────────────────────────────────────────


def _identifier(value: Any, where: str, required: bool = True) -> str:
    text = str(value or "").strip()
    if not text:
        if required:
            raise EntityConfigError(f"{where} is required")
        return ""
    if not _IDENTIFIER.match(text):
        raise EntityConfigError(f"{where} must be a plain SQL identifier, got {text!r}")
    return text


def _type_name(value: Any, where: str) -> str:
    text = str(value or "").strip().lower()
    if not _TYPE_NAME.match(text):
        raise EntityConfigError(f"{where} must be a short lower-case name, got {value!r}")
    return text


def _top_k(value: Any, default: int) -> int:
    try:
        number = int(value if value is not None else default)
    except (TypeError, ValueError) as exc:
        raise EntityConfigError(f"topK must be an integer, got {value!r}") from exc
    return max(1, min(50, number))


def _object(value: Any, where: str) -> dict:
    if not isinstance(value, dict):
        raise EntityConfigError(f"{where} must be an object")
    return value


def parse_config(document: str | dict) -> EntityConfig:
    """Check a config (JSON text or a dict) and turn it into an EntityConfig."""
    try:
        raw = json.loads(document) if isinstance(document, str) else document
    except ValueError as exc:
        raise EntityConfigError(f"not valid JSON: {exc}") from exc
    if not isinstance(raw, dict):
        raise EntityConfigError('expected {"entities": [ ... ], "time": { ... }}')

    # The optional time block: {"column", "format": "YYYYMM", "fiscalYearEndMonth": 1-12}.
    time = None
    block = raw.get("time")
    if block is not None:
        _object(block, "time")
        fmt = str(block.get("format") or "YYYYMM").upper()
        if fmt != "YYYYMM":
            raise EntityConfigError(f"time.format {fmt!r} is not supported (only YYYYMM)")
        try:
            end_month = int(block.get("fiscalYearEndMonth", 12))
        except (TypeError, ValueError) as exc:
            raise EntityConfigError("time.fiscalYearEndMonth must be 1-12") from exc
        if not 1 <= end_month <= 12:
            raise EntityConfigError("time.fiscalYearEndMonth must be 1-12")
        time = TimeSpec(
            column=_identifier(block.get("column"), "time.column"), fiscal_year_end_month=end_month, format=fmt
        )

    entities = raw.get("entities") if raw.get("entities") is not None else []
    if not isinstance(entities, list) or (not entities and time is None):
        raise EntityConfigError('expected {"entities": [ ... ]} with at least one entry (or a "time" block)')

    specs = []
    for i, e in enumerate(entities):
        where = f"entities[{i}]"
        _object(e, where)
        groups = []
        for j, g in enumerate(e.get("groups") or []):
            gw = f"{where}.groups[{j}]"
            _object(g, gw)
            groups.append(
                GroupSpec(
                    type=_type_name(g.get("type"), f"{gw}.type"),
                    column=_identifier(g.get("column"), f"{gw}.column"),
                    child_column=_identifier(g.get("childColumn"), f"{gw}.childColumn", required=False),
                    filter_column=_identifier(g.get("filterColumn"), f"{gw}.filterColumn", required=False),
                    top_k=_top_k(g.get("topK"), 5),
                    filter_with_member=bool(g.get("filterWithMember", False)),
                )
            )
        specs.append(
            EntityTypeSpec(
                type=_type_name(e.get("type"), f"{where}.type"),
                table=_identifier(e.get("table"), f"{where}.table"),
                database=_identifier(e.get("database"), f"{where}.database", required=False),
                id_column=_identifier(e.get("idColumn"), f"{where}.idColumn"),
                name_column=_identifier(e.get("nameColumn"), f"{where}.nameColumn"),
                filter_column=_identifier(e.get("filterColumn"), f"{where}.filterColumn", required=False),
                describe_columns=tuple(
                    _identifier(c, f"{where}.describeColumns[]") for c in e.get("describeColumns") or []
                ),
                acronyms=bool(e.get("acronyms", False)),
                top_k=_top_k(e.get("topK"), 10),
                groups=tuple(groups),
            )
        )

    names = [k.type for k in EntityConfig(tuple(specs)).kind_infos()]
    for name in names:
        if names.count(name) > 1:
            raise EntityConfigError(f"entity type {name!r} is defined twice")
    return EntityConfig(tuple(specs), time)


# ── loading from SSM ─────────────────────────────────────────────────────


def parameter_name(ssm_prefix: str, key: str) -> str:
    """``{ssm_prefix}/entities/{key}``, where key is a namespace id or ``default``."""
    return f"{ssm_prefix.rstrip('/')}/entities/{key}"


def load_config(ssm: Any, ssm_prefix: str, namespace: str) -> EntityConfig | None:
    """The namespace's override, else the default; None when neither exists.

    A parameter that exists but is not valid raises EntityConfigError, so a typo
    is reported instead of quietly turning the feature off.
    """
    for key in (namespace, DEFAULT_PARAMETER):
        if not key:
            continue
        try:
            value = ssm.get_parameter(Name=parameter_name(ssm_prefix, key))["Parameter"]["Value"]
        except ssm.exceptions.ParameterNotFound:
            continue
        return parse_config(value)
    return None
