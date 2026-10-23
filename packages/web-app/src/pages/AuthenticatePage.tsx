// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import React, { useContext, useEffect, useMemo, useRef, useState } from "react";
import {
  AppLayout,
  Box,
  SpaceBetween,
  TextContent,
} from "@cloudscape-design/components";
import { useSearchParams } from "react-router-dom";
import { RuntimeConfigContext } from "@components/RuntimeContext";
import { OIDCProvider } from "@auth";

interface AuthenticatePageProps {
  title: string;
}

export const AuthenticatePage: React.FC<AuthenticatePageProps> = ({
  title,
}) => {
  const [status, setStatus] = useState<"processing" | "success" | "failure">(
    "processing",
  );
  const [searchParams] = useSearchParams();
  const runtimeContext = useContext(RuntimeConfigContext);
  const provider = useMemo(
    () =>
      runtimeContext?.oidcConfig
        ? OIDCProvider.build(runtimeContext.oidcConfig)
        : undefined,
    [runtimeContext],
  );
  const called = useRef(false);

  useEffect(() => {
    if (called.current || !provider) return;
    called.current = true;

    // The IdP reports its own failures here rather than in `code`/`state`,
    // so read them before treating a missing code as a malformed callback.
    const idpError = searchParams.get("error");
    if (idpError) {
      console.error(
        `Sign-in failed at the identity provider: ${idpError}` +
          ` — ${searchParams.get("error_description") ?? "no description"}`,
      );
      setStatus("failure");
      return;
    }

    const code = searchParams.get("code");
    const state = searchParams.get("state");
    if (!code || !state) {
      console.error(
        "Sign-in callback carried neither an authorization code nor an error.",
      );
      setStatus("failure");
      return;
    }

    provider
      .authenticationCallback()
      .then((user) => {
        if (!user) {
          console.error("Token exchange returned no user.");
        }
        setStatus(user ? "success" : "failure");
      })
      .catch((err: unknown) => {
        // Logged, not swallowed: without this the page redirects to /login
        // with no message anywhere, and a misconfigured provider is
        // indistinguishable from a user who simply cancelled.
        console.error("Token exchange failed:", err);
        setStatus("failure");
      });
  }, [provider, searchParams]);

  useEffect(() => {
    if (status === "success") window.location.replace("/");
    else if (status === "failure") window.location.replace("/login");
  }, [status]);

  const message =
    status === "processing"
      ? "Authenticating with the configured Identity Provider..."
      : status === "success"
        ? "Authentication successful. Redirecting..."
        : "Authentication failed. Redirecting...";

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
          <TextContent>
            <Box variant="h5" textAlign="center" padding={{ top: "s" }}>
              {message}
            </Box>
          </TextContent>
        </SpaceBetween>
      }
    />
  );
};
