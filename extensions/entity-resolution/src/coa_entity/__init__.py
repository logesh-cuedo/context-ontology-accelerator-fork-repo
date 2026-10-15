# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Generic Tier-2 entity resolution (extension — see extensions/entity-resolution/README.md).

Modules are imported individually on purpose: the index-build Lambda imports
``index_builder`` / ``config`` without pulling in serve (``coa_serve``).
"""
