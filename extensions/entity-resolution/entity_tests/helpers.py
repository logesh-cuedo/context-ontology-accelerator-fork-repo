# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Shared fixtures-as-functions for the extension tests."""

from __future__ import annotations

import json
from pathlib import Path

from coa_entity.config import EntityConfig, parse_config

SAMPLE = Path(__file__).resolve().parents[1] / "entities.sample.json"


def sample_config() -> EntityConfig:
    return parse_config(SAMPLE.read_text())


def sample_document() -> dict:
    return json.loads(SAMPLE.read_text())
