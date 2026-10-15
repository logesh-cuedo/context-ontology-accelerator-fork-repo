#!/usr/bin/env node
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

/**
 * Write the permission manifest for a private-VPC deployment.
 *
 * ## Why this exists
 *
 * In a private-VPC deployment every IAM role is IMPORTED, and CDK silently
 * drops `addToRolePolicy` and `grant*` against an imported role. That is
 * correct — the operator attached those permissions when they created the
 * roles — but only if they attached ALL of them. If one statement is missing:
 *
 *   - the synth succeeds
 *   - the deploy succeeds
 *   - one service fails at runtime with access-denied, and nothing in the
 *     template says which or why
 *
 * `infra/pvt_vpc/ROLE-NAMES.md` names this exact failure: "A missing
 * permission does not fail the deployment — it fails later at runtime, which
 * is the harder failure to trace."
 *
 * This script turns that runtime mystery into a pre-deploy diff. It reads the
 * STANDARD-mode templates — where CDK does emit every policy — and writes out
 * each role's statements, so they can be compared against the IAM package
 * before anything is deployed.
 *
 * ## Usage
 *
 *   cdk synth                                   # standard mode, no vpc_id
 *   npx tsx bin/pvt-vpc-permissions.ts cdk.out  # writes the manifest
 *
 * The templates must come from a synth WITHOUT `-c vpc_id=`: a private-mode
 * synth emits no policies at all, which is the thing being compensated for.
 * The script refuses templates that contain no policies rather than writing an
 * empty manifest that would read as "nothing to attach".
 */

import * as fs from "fs";
import * as path from "path";

import { writePermissionManifest } from "../lib/pvt-vpc-roles";

const DEFAULT_TEMPLATE_DIR = "cdk.out";
const DEFAULT_OUT_FILE = "pvt_vpc/PERMISSIONS.generated.json";

function main(): void {
  const templateDir = process.argv[2] ?? DEFAULT_TEMPLATE_DIR;
  const outFile = process.argv[3] ?? DEFAULT_OUT_FILE;

  if (!fs.existsSync(templateDir)) {
    fail(
      `${templateDir} does not exist. Run \`cdk synth\` first, without ` +
        "-c vpc_id=, so the templates contain the policies this manifest " +
        "records.",
    );
  }

  const templates = fs
    .readdirSync(templateDir)
    .filter((f) => f.endsWith(".template.json"));
  if (templates.length === 0) {
    fail(
      `${templateDir} holds no *.template.json files. Run \`cdk synth\` ` +
        "first, without -c vpc_id=.",
    );
  }

  const count = writePermissionManifest(templateDir, outFile);

  if (count === 0) {
    // Almost certainly a private-mode synth: those emit no AWS::IAM::Policy
    // at all. Writing "0 statements" would read as "nothing to attach", which
    // is the opposite of the truth and exactly the mistake this guards.
    fail(
      [
        `No IAM policy statements found in ${templateDir}.`,
        "",
        "This usually means the templates came from a PRIVATE-VPC synth",
        "(-c vpc_id=...), which imports every role and therefore emits no",
        "policies — there is nothing to record.",
        "",
        "Re-synth without -c vpc_id= and run this again:",
        "  cdk synth",
        `  npx tsx bin/pvt-vpc-permissions.ts ${templateDir}`,
      ].join("\n"),
    );
  }

  const roleCount = Object.keys(
    (JSON.parse(fs.readFileSync(outFile, "utf-8")) as { roles: object }).roles,
  ).length;

  process.stdout.write(
    [
      `Wrote ${outFile}`,
      `  ${count} permission statements across ${roleCount} roles,`,
      `  read from ${templates.length} templates in ${templateDir}.`,
      "",
      "Diff this against the IAM package used to pre-create the roles. A",
      "statement here with no counterpart there fails at RUNTIME, not at",
      "deploy time.",
      "",
    ].join("\n"),
  );
}

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

// Only run when invoked directly, so the module stays importable by tests.
if (
  require.main === module ||
  process.argv[1]?.includes(path.basename(__filename))
) {
  main();
}
