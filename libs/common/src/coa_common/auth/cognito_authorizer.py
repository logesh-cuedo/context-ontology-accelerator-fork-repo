# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Cognito-specific token authorizer."""

from __future__ import annotations

from typing import Any

from coa_common.auth.token_authorizer import (
    FEDERATED_GROUP_CLAIM,
    TokenAuthorizer,
    merge_group_claims,
)


class CognitoTokenAuthorizer(TokenAuthorizer):
    """Validates JWTs issued by Amazon Cognito User Pools.

    Cognito tokens use ``cognito:groups`` for group membership.

    Parameters
    ----------
    user_pool_id:
        The Cognito User Pool ID (e.g. ``us-east-1_ABC123``).
    region:
        AWS region where the user pool is deployed. **Required**.
    client_id:
        Optional app client ID for audience validation.
    """

    def __init__(
        self,
        *,
        user_pool_id: str,
        region: str,
        client_id: str | None = None,
    ) -> None:
        """Derive the Cognito issuer and JWKS URI from the pool coordinates.

        Args:
            user_pool_id: The Cognito User Pool ID (e.g. ``us-east-1_ABC123``).
            region: AWS region where the user pool is deployed.
            client_id: Optional app client ID for audience validation.
        """
        issuer = f"https://cognito-idp.{region}.amazonaws.com/{user_pool_id}"
        jwks_uri = f"{issuer}/.well-known/jwks.json"
        super().__init__(issuer=issuer, audience=client_id, jwks_uri=jwks_uri)

    def _extract_email(self, claims: dict[str, Any]) -> str:
        """Extract email — falls back to username for access tokens."""
        return str(claims.get("email") or claims.get("username", ""))

    def _extract_groups(self, claims: dict[str, Any]) -> list[str]:
        """Merge the pool's own groups with those a federated user brings.

        Native users carry ``cognito:groups``; users federated from an external
        IdP carry ``FEDERATED_GROUP_CLAIM`` instead and have no Cognito group
        at all. Reading both means neither kind needs a manual group assignment
        before their grants resolve.
        """
        return merge_group_claims(claims, "cognito:groups", FEDERATED_GROUP_CLAIM)
