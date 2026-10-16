# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Entity config parsing and SSM lookup."""

from __future__ import annotations

import json
from unittest.mock import MagicMock

import pytest

from coa_entity.config import EntityConfigError, load_config, parse_config

from .helpers import sample_config, sample_document


@pytest.mark.unit
class TestParseConfig:
    def test_sample_parses(self):
        config = sample_config()
        assert config.kinds() == [("company", 10), ("sector", 5)]
        company = config.member_spec("company")
        assert company is not None
        assert company.columns == ["company_id", "company_name", "cd_sector", "cd_subsector"]
        assert config.sql_column("company") == "company_name"
        assert config.sql_column("sector") == "sector"
        assert config.group_spec("sector").filter_with_member

    def test_filter_column_defaults_to_name(self):
        doc = {"entities": [{"type": "product", "table": "products", "idColumn": "sku", "nameColumn": "title"}]}
        assert parse_config(doc).sql_column("product") == "title"

    @pytest.mark.parametrize(
        "mutate, message",
        [
            (lambda d: (d.pop("time", None), d.update(entities=[])), "at least one"),
            (lambda d: d["entities"][0].pop("table"), "table is required"),
            (lambda d: d["entities"][0].update(nameColumn="name; DROP"), "plain SQL identifier"),
            (lambda d: d["entities"][0]["groups"][0].update(type="company"), "defined twice"),
            (lambda d: d["entities"][0].update(type="Company Names"), "lower-case"),
        ],
    )
    def test_rejects_bad_documents(self, mutate, message):
        doc = sample_document()
        mutate(doc)
        with pytest.raises(EntityConfigError, match=message):
            parse_config(doc)

    def test_rejects_invalid_json(self):
        with pytest.raises(EntityConfigError, match="not valid JSON"):
            parse_config("{nope")


def _ssm(params: dict[str, str]) -> MagicMock:
    ssm = MagicMock()
    ssm.exceptions.ParameterNotFound = type("ParameterNotFound", (Exception,), {})

    def get_parameter(Name):  # noqa: N803 — boto3 kwarg name
        if Name not in params:
            raise ssm.exceptions.ParameterNotFound()
        return {"Parameter": {"Value": params[Name]}}

    ssm.get_parameter.side_effect = get_parameter
    return ssm


@pytest.mark.unit
class TestLoadConfig:
    def test_namespace_override_wins(self):
        override = {"entities": [{"type": "product", "table": "p", "idColumn": "id", "nameColumn": "n"}]}
        ssm = _ssm(
            {
                "/cuedo/entities/ns1": json.dumps(override),
                "/cuedo/entities/default": json.dumps(sample_document()),
            }
        )
        assert [k for k, _ in load_config(ssm, "/cuedo", "ns1").kinds()] == ["product"]
        assert [k for k, _ in load_config(ssm, "/cuedo", "ns2").kinds()] == ["company", "sector"]

    def test_none_without_any_parameter(self):
        assert load_config(_ssm({}), "/cuedo", "ns1") is None

    def test_malformed_parameter_raises(self):
        with pytest.raises(EntityConfigError):
            load_config(_ssm({"/cuedo/entities/default": "{}"}), "/cuedo", "ns1")


@pytest.mark.unit
class TestKindInfos:
    def test_companies_and_sectors_share_one_shape(self):
        company, sector = sample_config().kind_infos()
        assert (company.type, company.is_group, company.table, company.table_column, company.sql_column) == (
            "company", False, "sectors", "company_name", "company_name",
        )  # fmt: skip
        assert (sector.type, sector.is_group, sector.table, sector.table_column, sector.sql_column) == (
            "sector", True, "sectors", "cd_sector", "sector",
        )  # fmt: skip
        assert sector.parent == "company" and company.id_column == "company_id" and sector.id_column == ""


@pytest.mark.unit
class TestTimeBlock:
    def test_parsed(self):
        doc = sample_document() | {"time": {"column": "yyyymm", "fiscalYearEndMonth": 3}}
        t = parse_config(doc).time
        assert t is not None and (t.column, t.fiscal_year_end_month, t.format) == ("yyyymm", 3, "YYYYMM")

    def test_time_only_config_is_valid(self):
        assert parse_config({"time": {"column": "yyyymm"}}).entity_types == ()

    @pytest.mark.parametrize(
        "time, message",
        [({"column": "yyyymm", "fiscalYearEndMonth": 13}, "1-12"), ({"column": "x", "format": "DATE"}, "not supported"),
         ({}, "time.column is required")],
    )  # fmt: skip
    def test_rejects(self, time, message):
        with pytest.raises(EntityConfigError, match=message):
            parse_config(sample_document() | {"time": time})
