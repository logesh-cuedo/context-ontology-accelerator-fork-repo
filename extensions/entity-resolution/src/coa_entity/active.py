# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""The pointer that tells serve which index version to search, and where its name list is.

    SSM {ssm_prefix}/entities/_active/{namespace}
        {"index": "<collection>-entities-<ns>-v<version>",
         "names": "s3://<bucket>/entities/<ns>/v<version>.json",
         "version": <version>}

The index build writes the new index and name list first and this pointer
last, so serve switches to a new version only once it is complete. (Namespace
ids never start with "_", so the path cannot collide with a namespace config.)
"""

from __future__ import annotations

import contextlib
import json
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class ActivePointer:
    """The index version serve should search, and where its name list lives."""

    index: str
    names_uri: str
    version: int


def pointer_name(ssm_prefix: str, namespace: str) -> str:
    """``{ssm_prefix}/entities/_active/{namespace}``."""
    return f"{ssm_prefix.rstrip('/')}/entities/_active/{namespace}"


def read_pointer(ssm: Any, ssm_prefix: str, namespace: str) -> ActivePointer | None:
    """The namespace's active pointer, or None if no versioned build exists yet."""
    try:
        raw = ssm.get_parameter(Name=pointer_name(ssm_prefix, namespace))["Parameter"]["Value"]
    except ssm.exceptions.ParameterNotFound:
        return None
    data = json.loads(raw)
    return ActivePointer(index=data["index"], names_uri=data.get("names", ""), version=int(data.get("version", 0)))


def write_pointer(ssm: Any, ssm_prefix: str, namespace: str, pointer: ActivePointer) -> None:
    """Save ``pointer`` as the index version serve should search."""
    ssm.put_parameter(
        Name=pointer_name(ssm_prefix, namespace),
        Value=json.dumps({"index": pointer.index, "names": pointer.names_uri, "version": pointer.version}),
        Type="String",
        Overwrite=True,
    )


def delete_pointer(ssm: Any, ssm_prefix: str, namespace: str) -> None:
    """Remove the namespace's pointer (used when a namespace is deleted)."""
    with contextlib.suppress(ssm.exceptions.ParameterNotFound):
        ssm.delete_parameter(Name=pointer_name(ssm_prefix, namespace))
