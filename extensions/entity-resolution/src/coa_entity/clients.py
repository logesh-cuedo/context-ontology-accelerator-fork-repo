# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Plain (blocking) OpenSearch and Bedrock calls for the extension.

Serve's clients only offer ``async`` methods. Under them are ordinary blocking
calls; this class uses those directly, so the extension's code runs top to bottom
with no ``await``, and the model, region, timeouts and OpenSearch proxy stay the
ones serve configured.

Run these from a worker thread (``asyncio.to_thread``), never on serve's event loop.
"""

from __future__ import annotations

from typing import Any


class Clients:
    """embed / search / converse, each one blocking call."""

    def __init__(self, vector_client: Any, llm_client: Any):
        """Wrap serve's OpenSearchVectorClient and BedrockLLMClient."""
        self._vector = vector_client
        self._llm = llm_client

    def embed(self, text: str) -> list[float]:
        """Titan embedding of ``text`` (the same embedder serve uses)."""
        return self._llm._embedder.embed_query(text)

    def search(
        self, vector: list[float], *, index: str, top_k: int, entity_type: str, require_mapped: bool = False
    ) -> list[Any]:
        """k-NN search for documents of one ``entity_type``; returns serve's VectorHit objects."""
        from coa_serve.clients.opensearch import _SOURCE_FIELDS

        filters = [{"term": {"entity_type": entity_type}}]
        if require_mapped:
            filters.append({"exists": {"field": "data_source_id"}})
        raw = self._vector._aoss.knn_search(index, vector, top_k=top_k, filters=filters, source=_SOURCE_FIELDS)
        return [self._vector._to_hit(r) for r in raw]

    def converse(self, prompt: str, *, max_tokens: int, temperature: float, model_id: str | None) -> str:
        """One Bedrock Converse call; returns the reply text (all text blocks joined)."""
        kwargs = self._llm._build_converse_kwargs(
            prompt, max_tokens=max_tokens, temperature=temperature, model_id=model_id
        )
        response = self._llm._call_with_temperature_fallback(self._llm._get_client().converse, kwargs)
        blocks = response.get("output", {}).get("message", {}).get("content", [])
        return "".join(b["text"] for b in blocks if isinstance(b, dict) and "text" in b)
