# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Finds the companies / sectors a question is about, for Tier 2 (see README.md).

Import each module by itself: the index-build Lambda imports ``index_builder``
and ``config`` and must not load serve (``coa_serve``).
"""
