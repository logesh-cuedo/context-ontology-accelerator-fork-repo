# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Abstract base class for token authorization."""

from __future__ import annotations

import json
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import StrEnum
from typing import Any

import jwt
import requests
import structlog
from jwt.exceptions import PyJWTError

logger = structlog.get_logger(__name__)

_HTTP_TIMEOUT = 30


#: Claim carrying the groups a FEDERATED user brings from their own IdP.
#:
#: A user who signs in through a provider federated into the Cognito pool
#: (Entra ID, say) has no Cognito group membership — ``cognito:groups`` is
#: empty for them, because Cognito does not translate an external IdP's groups
#: into its own. The pool maps the IdP's group claim onto this custom
#: attribute instead (see the provider's ``attributeMapping`` in
#: infra/lib/stacks/foundation/idp-authentication-stack.ts), and Cognito then
#: mints it as a claim of this name. Reading it alongside ``cognito:groups``
#: is what lets a federated and a native user resolve roles identically.
FEDERATED_GROUP_CLAIM = "custom:idp_groups"


def extract_groups_claim(claims: dict[str, Any], group_claim_name: str = "groups") -> list[str]:
    """Normalize an IdP groups claim to list[str] (shared identity extraction).

    Accepts a list, or a comma/space-delimited string (IdPs differ). Used by the
    OIDC authorizer (control plane) and the serve WS TokenClaims so group
    parsing has exactly one implementation.
    """
    raw = claims.get(group_claim_name, [])
    if isinstance(raw, list):
        return [str(g) for g in raw]
    if isinstance(raw, str):
        return [g for g in raw.replace(",", " ").split() if g]
    return []


def merge_group_claims(claims: dict[str, Any], *claim_names: str) -> list[str]:
    """Collect groups from several claims, de-duplicated, order preserved.

    Order matters only in that it is stable: a role resolved from either claim
    is the same role, but a caller logging or caching the list should not see
    it reshuffle between tokens.
    """
    merged: list[str] = []
    for name in claim_names:
        merged.extend(extract_groups_claim(claims, name))
    return list(dict.fromkeys(merged))


class TokenType(StrEnum):
    """Type of bearer token presented by the caller."""

    JWT = "JWT"
    AGENT_ACCESS_TOKEN = "AGENT_ACCESS_TOKEN"


@dataclass(frozen=True)
class TokenValidationResult:
    """Result of validating and decoding a bearer token."""

    principal_id: str  # email — used for role lookups
    sub: str  # JWT sub claim — for audit/logging
    email: str
    groups: list[str]
    token_type: TokenType
    claims: dict[str, Any] = field(default_factory=dict)
    agent_identity: str | None = None


class TokenAuthorizer(ABC):
    """ABC for token validation. Subclass for Cognito or generic OIDC.

    Parameters
    ----------
    issuer:
        The expected ``iss`` claim value.
    audience:
        The expected ``aud`` claim value. If ``None``, audience is not verified.
    jwks_uri:
        Explicit JWKS endpoint. If ``None``, discovered via OIDC well-known.
    jwks_cache_ttl:
        Seconds to cache the JWKS key set (default 300 = 5 min).
    """

    def __init__(
        self,
        *,
        issuer: str,
        audience: str | None = None,
        jwks_uri: str | None = None,
        jwks_cache_ttl: int = 300,
    ) -> None:
        """Store issuer/audience config and initialize the JWKS cache.

        Args:
            issuer: The expected ``iss`` claim value.
            audience: The expected ``aud`` claim value; if ``None``, audience is not verified.
            jwks_uri: Explicit JWKS endpoint; if ``None``, discovered via OIDC well-known.
            jwks_cache_ttl: Seconds to cache the JWKS key set (default 300 = 5 min).
        """
        self._issuer = issuer.rstrip("/")
        self._audience = audience
        self._configured_jwks_uri = jwks_uri
        self._jwks_cache_ttl = jwks_cache_ttl

        self._jwks: dict[str, Any] | None = None
        self._jwks_last_updated: float = 0
        self._discovered_jwks_uri: str | None = None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def validate(self, authorization_header: str) -> TokenValidationResult:
        """Validate a ``Bearer <token>`` header and return structured claims.

        Raises ``ValueError`` if the token is missing, malformed, expired,
        or has an invalid signature.
        """
        claims = self.verify_claims(authorization_header)
        return self._build_result(claims)

    def verify_claims(self, authorization_header: str) -> dict[str, Any]:
        """Verify a ``Bearer <token>`` header's signature/issuer/audience/expiry and return raw claims.

        Returned claims skip the ``email`` requirement ``validate`` imposes.
        Use this instead of :meth:`validate` when the caller's identity model
        is not email-keyed (``validate``'s ``TokenValidationResult`` always
        requires ``email`` — the control-plane authorizer's principal model).
        The cryptographic verification performed is identical to ``validate``;
        only the post-verification claim requirements differ.

        Raises ``ValueError`` if the token is missing, malformed, expired,
        or has an invalid signature.
        """
        token = self._extract_bearer_token(authorization_header)
        return self._verify_and_decode(token)

    def extract_groups(self, claims: dict[str, Any]) -> list[str]:
        """Public entry point for the IdP-specific group-claim extraction.

        Delegates to the same :meth:`_extract_groups` hook subclasses
        implement for :meth:`validate`, so callers using :meth:`verify_claims`
        (email-agnostic identity models) get identical group/role resolution
        without duplicating the Cognito-vs-generic-OIDC claim-name handling.
        """
        return self._extract_groups(claims)

    # ------------------------------------------------------------------
    # Template-method hooks for subclasses
    # ------------------------------------------------------------------

    @abstractmethod
    def _extract_groups(self, claims: dict[str, Any]) -> list[str]:
        """Extract group memberships from decoded JWT claims."""

    def _extract_email(self, claims: dict[str, Any]) -> str:
        """Extract email from claims. Override if the claim name differs."""
        return str(claims.get("email", ""))

    def _get_token_type(self, claims: dict[str, Any]) -> TokenType:  # noqa: ARG002
        """Determine the token type. Override for agent access token support.

        Future: inspect claims to distinguish agent delegation tokens from
        standard JWTs and return ``TokenType.AGENT_ACCESS_TOKEN`` when the
        token represents a delegated agent identity.
        """
        return TokenType.JWT

    def _get_agent_identity(self, claims: dict[str, Any]) -> str | None:  # noqa: ARG002
        """Extract the agent workload identity for audit logging.

        Future: when agent access tokens are supported, extract the agent's
        ARN or identifier from the token claims so it can be logged alongside
        the delegating user's authorization decision.
        """
        return None

    # ------------------------------------------------------------------
    # JWKS helpers
    # ------------------------------------------------------------------

    def _get_jwks_uri(self) -> str:
        if self._configured_jwks_uri:
            return self._configured_jwks_uri
        if self._discovered_jwks_uri:
            return self._discovered_jwks_uri

        discovery_url = f"{self._issuer}/.well-known/openid-configuration"
        try:
            resp = requests.get(discovery_url, timeout=_HTTP_TIMEOUT)
            resp.raise_for_status()
            config = resp.json()
            discovered_issuer = config.get("issuer", "").rstrip("/")
            if discovered_issuer != self._issuer:
                raise ValueError(f"Issuer mismatch: expected {self._issuer}, got {discovered_issuer}")
            jwks_uri = config.get("jwks_uri")
            if not jwks_uri:
                raise ValueError("OIDC discovery missing jwks_uri")
            self._discovered_jwks_uri = jwks_uri
            return jwks_uri
        except requests.RequestException:
            logger.exception("Failed to fetch OIDC discovery document", url=discovery_url)
            raise

    def _get_jwks(self) -> dict[str, Any]:
        now = time.time()
        if self._jwks and (now - self._jwks_last_updated) < self._jwks_cache_ttl:
            return self._jwks
        jwks_url = self._get_jwks_uri()
        try:
            resp = requests.get(jwks_url, timeout=_HTTP_TIMEOUT)
            resp.raise_for_status()
            self._jwks = resp.json()
            self._jwks_last_updated = now
            return self._jwks  # type: ignore[return-value]
        except requests.RequestException:
            logger.exception("Failed to fetch JWKS", url=jwks_url)
            raise

    def _get_public_key(self, kid: str) -> Any:
        jwks = self._get_jwks()
        key = next((k for k in jwks.get("keys", []) if k.get("kid") == kid), None)
        if not key:
            raise ValueError(f"Key ID {kid} not found in JWKS")
        return jwt.api_jwk.PyJWK.from_json(json.dumps(key)).key

    # ------------------------------------------------------------------
    # Core verification
    # ------------------------------------------------------------------

    def _verify_and_decode(self, token: str) -> dict[str, Any]:
        try:
            header = jwt.get_unverified_header(token)
            kid = header.get("kid")
            if not kid:
                raise ValueError("No kid in token header")

            public_key = self._get_public_key(kid)

            decode_opts: dict[str, Any] = {"verify_exp": True, "verify_iss": True}
            kwargs: dict[str, Any] = {
                "algorithms": ["RS256"],
                "options": decode_opts,
                "issuer": self._issuer,
                "leeway": 30,
            }
            if self._audience:
                # Cognito access tokens have client_id but no aud claim.
                # Decode without aud verification first, then check manually.
                decode_opts["verify_aud"] = False
            else:
                decode_opts["verify_aud"] = False

            claims = jwt.decode(token, public_key, **kwargs)

            if self._audience:
                aud = claims.get("aud") or claims.get("client_id")
                aud_list = [aud] if isinstance(aud, str) else (aud or [])
                if self._audience not in aud_list:
                    raise ValueError(f"Token audience mismatch: expected {self._audience}, got {aud}")

            return claims
        except PyJWTError as exc:
            logger.warning("JWT validation failed", error=str(exc))
            raise ValueError(f"Invalid token: {exc}") from exc

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _extract_bearer_token(authorization_header: str) -> str:
        if not authorization_header or not authorization_header.startswith("Bearer "):
            raise ValueError("Missing or malformed Authorization header")
        parts = authorization_header.split(" ", maxsplit=1)
        if len(parts) < 2 or not parts[1]:  # noqa: PLR2004
            raise ValueError("Bearer token is empty")
        return parts[1]

    def _build_result(self, claims: dict[str, Any]) -> TokenValidationResult:
        email = self._extract_email(claims)
        if not email:
            raise ValueError("Token missing required email claim")
        return TokenValidationResult(
            principal_id=email,
            sub=str(claims.get("sub", "")),
            email=email,
            groups=self._extract_groups(claims),
            token_type=self._get_token_type(claims),
            claims=claims,
            agent_identity=self._get_agent_identity(claims),
        )
