// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import { vi, describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import React from "react";
import { LoginPage } from "../../../src/pages/LoginPage";
import { RuntimeConfigContext } from "../../../src/components/RuntimeContext";

const mockAuthenticate = vi.fn();

vi.mock("../../../src/auth", () => ({
  OIDCProvider: {
    build: () => ({ authenticate: mockAuthenticate }),
  },
}));

const runtimeConfig = {
  region: "us-east-1",
  authority: "https://cognito.example.com",
  clientId: "test-client",
  apiEndpoint: "https://api.example.com",
  oidcConfig: {
    authority: "https://cognito.example.com",
    clientId: "test-client",
  },
};

describe("LoginPage", () => {
  it("renders the title and sign-in button", () => {
    render(
      <RuntimeConfigContext.Provider value={runtimeConfig}>
        <LoginPage title="My App" />
      </RuntimeConfigContext.Provider>,
    );

    expect(screen.getByText("My App")).toBeInTheDocument();
    // Exact names: /sign in/i also matches "Sign in with Microsoft".
    expect(
      screen.getByRole("button", { name: "Sign in" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Sign in with Microsoft" }),
    ).toBeInTheDocument();
  });

  it("calls authenticate on button click", async () => {
    mockAuthenticate.mockResolvedValue(undefined);
    const user = userEvent.setup();

    render(
      <RuntimeConfigContext.Provider value={runtimeConfig}>
        <LoginPage title="My App" />
      </RuntimeConfigContext.Provider>,
    );

    await user.click(screen.getByRole("button", { name: "Sign in" }));
    expect(mockAuthenticate).toHaveBeenCalledWith(undefined);
  });

  it("passes the provider name when signing in with Microsoft", async () => {
    // The name is what Cognito resolves `identity_provider` by, so it has to
    // reach authenticate() verbatim — a bare authenticate() would land the
    // user on the hosted UI's picker instead of Microsoft.
    mockAuthenticate.mockResolvedValue(undefined);
    const user = userEvent.setup();

    render(
      <RuntimeConfigContext.Provider value={runtimeConfig}>
        <LoginPage title="My App" />
      </RuntimeConfigContext.Provider>,
    );

    await user.click(
      screen.getByRole("button", { name: "Sign in with Microsoft" }),
    );
    expect(mockAuthenticate).toHaveBeenCalledWith("Microsoft");
  });
});
