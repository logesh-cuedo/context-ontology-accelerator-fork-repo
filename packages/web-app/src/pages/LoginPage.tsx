// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import React, { useContext, useState } from "react";
import {
  AppLayout,
  Box,
  Button,
  Container,
  Flashbar,
  SpaceBetween,
  TextContent,
} from "@cloudscape-design/components";
import { RuntimeConfigContext } from "@components/RuntimeContext";
import { OIDCProvider } from "@auth";

/**
 * Federated provider to jump straight to, bypassing the Cognito hosted UI's
 * provider picker. Must match `oidcProviders[].name` in the deployment's SSM
 * config exactly — Cognito resolves `identity_provider` by that name, and a
 * mismatch is rejected at the authorize endpoint rather than falling back to
 * the hosted UI.
 */
const MICROSOFT_IDP_NAME = "Microsoft";

interface LoginPageProps {
  title: string;
}

export const LoginPage: React.FC<LoginPageProps> = ({ title }) => {
  const runtimeContext = useContext(RuntimeConfigContext);
  const [error, setError] = useState<string | null>(null);

  const handleSignIn = async (identityProvider?: string) => {
    if (!runtimeContext?.oidcConfig) return;
    try {
      setError(null);
      const provider = OIDCProvider.build(runtimeContext.oidcConfig);
      await provider.authenticate(identityProvider);
    } catch {
      setError("Sign in failed. Please try again.");
    }
  };

  return (
    <AppLayout
      navigationHide
      toolsHide
      contentType="cards"
      content={
        <SpaceBetween size="xxl" direction="vertical" alignItems="center">
          <TextContent>
            <Box variant="h1" textAlign="center" padding={{ top: "xxxl" }}>
              {title}
            </Box>
          </TextContent>
          {error && <Flashbar items={[{ content: error, type: "error" }]} />}
          <Container>
            <SpaceBetween size="s" direction="vertical">
              <Button
                fullWidth
                variant="primary"
                onClick={() => handleSignIn()}
              >
                Sign in
              </Button>
              <Button
                fullWidth
                variant="normal"
                onClick={() => handleSignIn(MICROSOFT_IDP_NAME)}
              >
                Sign in with Microsoft
              </Button>
            </SpaceBetween>
          </Container>
        </SpaceBetween>
      }
    />
  );
};
