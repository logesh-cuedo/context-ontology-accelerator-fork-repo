# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Entity configuration: which tables and columns hold the entities to resolve.

Nothing in this package names a table or column — everything comes from a JSON
document in SSM Parameter Store:

    {ssm_prefix}/entities/{namespace_id}   per-namespace override (optional)
    {ssm_prefix}/entities/default          used when there is no override

No parameter → the feature is off for that namespace (index build and serve
step both skip). Example (``entities.sample.json``)::

    {
      "entities": [
        {
          "type": "company",
          "table": "sectors",
          "idColumn": "company_id",
          "nameColumn": "company_name",
          "filterColumn": "company_name",
          "describeColumns": ["cd_sector"],
          "acronyms": true,
          "topK": 10,
          "groups": [
            {"type": "sector", "column": "cd_sector", "childColumn": "cd_subsector",
             "filterColumn": "sector", "filterWithMember": true, "topK": 5}
          ]
        }
      ]
    }

``type``            label used in the index, the clarification and the SQL hint
``table``           table holding one row per entity (any of the namespace's databases)
``database``        optional — pin the database instead of searching the sources
``idColumn`` / ``nameColumn``  unique key and display name
``filterColumn``    column the SQL writer filters on in fact tables (default nameColumn)
``describeColumns`` extra columns shown next to the name in options and documents
``acronyms``        also index initials ("Tata Consultancy Services" → TCS)
``groups``          columns whose distinct values are entities too (e.g. sector);
                    ``childColumn`` lists their members' sub-values in the document;
                    ``filterColumn`` is the column's name in the fact tables;
                    ``filterWithMember`` also filters on the picked entity's group
                    value (company → its sector) in tables that have filterColumn
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from typing import Any

DEFAULT_PARAMETER = "default"
_IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
_TYPE = re.compile(r"^[a-z][a-z0-9_-]{0,31}$")


class EntityConfigError(ValueError):
    """The entity configuration document is malformed."""


@dataclass(frozen=True)
class GroupSpec:
    """A column whose distinct values are themselves entities (e.g. a sector)."""

    type: str
    column: str
    child_column: str = ""
    filter_column: str = ""
    top_k: int = 5
    filter_with_member: bool = False

    @property
    def sql_column(self) -> str:
        """Column the SQL writer filters on for this group's values."""
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
        """Column the SQL writer filters on for these entities' names."""
        return self.filter_column or self.name_column

    @property
    def columns(self) -> list[str]:
        """Every column the index build reads, id and name first, no duplicates."""
        cols = [self.id_column, self.name_column, *self.describe_columns]
        for g in self.groups:
            cols += [g.column] + ([g.child_column] if g.child_column else [])
        return list(dict.fromkeys(cols))


@dataclass(frozen=True)
class EntityConfig:
    """All entity types configured for a namespace."""

    entity_types: tuple[EntityTypeSpec, ...] = field(default_factory=tuple)

    def kinds(self) -> list[tuple[str, int]]:
        """(entity_type, top_k) for every searchable kind — members then groups."""
        out: list[tuple[str, int]] = []
        for spec in self.entity_types:
            out.append((spec.type, spec.top_k))
            out += [(g.type, g.top_k) for g in spec.groups]
        return out

    def member_spec(self, kind: str) -> EntityTypeSpec | None:
        """The entity type named ``kind``, or None if ``kind`` is a group or unknown."""
        return next((s for s in self.entity_types if s.type == kind), None)

    def group_spec(self, kind: str) -> GroupSpec | None:
        """The group named ``kind``, or None if ``kind`` is an entity type or unknown."""
        return next((g for s in self.entity_types for g in s.groups if g.type == kind), None)

    def sql_column(self, kind: str) -> str:
        """Filter column for any configured kind (entity type or group); '' if unknown."""
        member = self.member_spec(kind)
        if member is not None:
            return member.sql_column
        group = self.group_spec(kind)
        return group.sql_column if group is not None else ""


def _ident(value: Any, what: str, *, required: bool = True) -> str:
    text = str(value or "").strip()
    if not text:
        if required:
            raise EntityConfigError(f"{what} is required")
        return ""
    if not _IDENT.match(text):
        raise EntityConfigError(f"{what} must be a plain SQL identifier, got {text!r}")
    return text


def _kind(value: Any, what: str) -> str:
    text = str(value or "").strip().lower()
    if not _TYPE.match(text):
        raise EntityConfigError(f"{what} must be a short lower-case name, got {value!r}")
    return text


def _top_k(value: Any, default: int) -> int:
    try:
        return max(1, min(50, int(value if value is not None else default)))
    except (TypeError, ValueError) as exc:
        raise EntityConfigError(f"topK must be an integer, got {value!r}") from exc


def parse_config(document: str | dict) -> EntityConfig:
    """Validate a config document (JSON text or already-parsed) into an EntityConfig."""
    try:
        raw = json.loads(document) if isinstance(document, str) else document
    except ValueError as exc:
        raise EntityConfigError(f"not valid JSON: {exc}") from exc
    if not isinstance(raw, dict) or not isinstance(raw.get("entities"), list) or not raw["entities"]:
        raise EntityConfigError('expected {"entities": [ ... ]} with at least one entry')

    specs: list[EntityTypeSpec] = []
    seen: set[str] = set()
    for i, entry in enumerate(raw["entities"]):
        if not isinstance(entry, dict):
            raise EntityConfigError(f"entities[{i}] must be an object")
        where = f"entities[{i}]"
        groups: list[GroupSpec] = []
        for j, g in enumerate(entry.get("groups") or []):
            if not isinstance(g, dict):
                raise EntityConfigError(f"{where}.groups[{j}] must be an object")
            groups.append(
                GroupSpec(
                    type=_kind(g.get("type"), f"{where}.groups[{j}].type"),
                    column=_ident(g.get("column"), f"{where}.groups[{j}].column"),
                    child_column=_ident(g.get("childColumn"), f"{where}.groups[{j}].childColumn", required=False),
                    filter_column=_ident(g.get("filterColumn"), f"{where}.groups[{j}].filterColumn", required=False),
                    top_k=_top_k(g.get("topK"), 5),
                    filter_with_member=bool(g.get("filterWithMember", False)),
                )
            )
        spec = EntityTypeSpec(
            type=_kind(entry.get("type"), f"{where}.type"),
            table=_ident(entry.get("table"), f"{where}.table"),
            database=_ident(entry.get("database"), f"{where}.database", required=False),
            id_column=_ident(entry.get("idColumn"), f"{where}.idColumn"),
            name_column=_ident(entry.get("nameColumn"), f"{where}.nameColumn"),
            filter_column=_ident(entry.get("filterColumn"), f"{where}.filterColumn", required=False),
            describe_columns=tuple(_ident(c, f"{where}.describeColumns[]") for c in entry.get("describeColumns") or []),
            acronyms=bool(entry.get("acronyms", False)),
            top_k=_top_k(entry.get("topK"), 10),
            groups=tuple(groups),
        )
        for kind in [spec.type, *(g.type for g in spec.groups)]:
            if kind in seen:
                raise EntityConfigError(f"entity type {kind!r} is defined twice")
            seen.add(kind)
        specs.append(spec)
    return EntityConfig(entity_types=tuple(specs))


def parameter_name(ssm_prefix: str, key: str) -> str:
    """``{ssm_prefix}/entities/{key}`` — key is a namespace id or ``default``."""
    return f"{ssm_prefix.rstrip('/')}/entities/{key}"


def load_config(ssm: Any, ssm_prefix: str, namespace: str) -> EntityConfig | None:
    """The namespace's override, else the default; None when neither exists.

    Raises EntityConfigError when a parameter exists but is malformed, so a typo
    is reported instead of silently switching the feature off.
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
