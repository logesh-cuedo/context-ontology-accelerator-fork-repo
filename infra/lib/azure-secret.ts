// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import * as fs from "fs";

import { fromRoot } from "./paths";

/** Default location of the Azure secret file, relative to the monorepo root. */
export const AZURE_SECRET_CONFIG_PATH = "infra/azure.secret.config";

/**
 * Shape of `azure.secret.config`.
 *
 * One key today. It is an object rather than a bare string so a second Entra
 * credential can be added without changing how the file is read.
 */
interface AzureSecretConfig {
  /** Client secret of the Entra ID app registration, from Azure. */
  readonly microsoftClientSecret?: string;
}

/**
 * The Entra ID client secret, or undefined when none is configured.
 *
 * Two sources, env var first:
 *
 *   1. `MICROSOFT_CLIENT_SECRET` — CI, and anyone who prefers not to put the
 *      secret on disk at all.
 *   2. `infra/azure.secret.config` — a JSON file holding
 *      `{"microsoftClientSecret": "..."}`.
 *
 * Returning undefined is a supported outcome, not a failure: the auth stack
 * skips the Microsoft provider entirely and warns, so a deploy stays possible
 * for anyone without the secret to hand.
 *
 * THE FILE IS NOT GITIGNORED. It is tracked so the key's shape is visible in
 * the repo, which means a real secret left in it WILL be committed, and a
 * secret in git history outlives its deletion from the working tree. Clear the
 * value before every commit, and rotate in Azure if one ever lands in history.
 */
export function resolveMicrosoftClientSecret(): string | undefined {
  const fromEnv = process.env.MICROSOFT_CLIENT_SECRET?.trim();
  if (fromEnv) return fromEnv;

  const file = process.env.COA_AZURE_SECRET_CONFIG ?? fromRoot(AZURE_SECRET_CONFIG_PATH);
  if (!fs.existsSync(file)) return undefined;

  let parsed: AzureSecretConfig;
  try {
    parsed = JSON.parse(fs.readFileSync(file, "utf-8")) as AzureSecretConfig;
  } catch (err) {
    // Loud: a malformed file is a typo in a value someone meant to supply,
    // and silently treating it as "no secret" would ship a deployment whose
    // only symptom is a missing Microsoft button.
    throw new Error(
      `${AZURE_SECRET_CONFIG_PATH} is not valid JSON (${
        err instanceof Error ? err.message : String(err)
      }). Fix the file, or delete it to deploy without Microsoft sign-in.`,
    );
  }

  const secret = parsed.microsoftClientSecret?.trim();
  return secret ? secret : undefined;
}
