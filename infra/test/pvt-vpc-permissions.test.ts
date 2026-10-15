// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import * as fs from "fs";
import * as os from "os";
import * as path from "path";

import * as cdk from "aws-cdk-lib";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as lambda from "aws-cdk-lib/aws-lambda";
import type { Construct } from "constructs";

jest.mock("../lib/utils/python-bundling", () => ({
  bundlePython: () => lambda.Code.fromInline("def handler(e,c): pass"),
}));

import { ApiStack } from "../lib/stacks/services/api-stack";
import { writePermissionManifest } from "../lib/pvt-vpc-roles";
import { DEFAULT_RESOURCE_PREFIX, DEFAULT_ENV } from "../lib/constants";

/**
 * The permission manifest is the safety net for the one failure a private-VPC
 * deployment cannot otherwise catch.
 *
 * Every IAM role there is imported, and CDK silently drops `addToRolePolicy`
 * and `grant*` against an imported role. That is correct — the operator
 * attached those permissions when creating the roles — but only if they
 * attached ALL of them. Miss one and the synth passes, the deploy passes, and
 * one service fails at runtime with access-denied and no explanation.
 *
 * So the manifest records what STANDARD mode attaches, keyed by the role name
 * the operator actually created, for diffing before deploy.
 */

const ENV = { account: "123456789012", region: "us-east-1" };

const mkTable = (scope: Construct, id: string) =>
  new dynamodb.Table(scope, id, {
    partitionKey: { name: "PK", type: dynamodb.AttributeType.STRING },
    stream: dynamodb.StreamViewType.NEW_AND_OLD_IMAGES,
  });

interface Manifest {
  readonly statementCount: number;
  readonly roles: Record<string, unknown[]>;
  readonly note: string[];
}

/** Synthesize a standard-mode stack and build its manifest. */
function buildManifest(): { manifest: Manifest; count: number; dir: string } {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pvt-vpc-perms-"));
  const app = new cdk.App({
    context: {
      resource_prefix: DEFAULT_RESOURCE_PREFIX,
      env: DEFAULT_ENV,
      "aws:cdk:bundling-stacks": [],
    },
    outdir: dir,
  });
  const dep = new cdk.Stack(app, "Dep", { env: ENV });
  const vpc = new ec2.Vpc(dep, "Vpc");
  const lambdaSecurityGroup = new ec2.SecurityGroup(dep, "LambdaSG", { vpc });
  new ApiStack(app, `${DEFAULT_RESOURCE_PREFIX}-${DEFAULT_ENV}-api`, {
    env: ENV,
    allowedOrigin: "*",
    vpc,
    lambdaSecurityGroup,
    rolesTable: mkTable(dep, "Roles"),
    resourceRoleMappingsTable: mkTable(dep, "RRM"),
    cacheInvalidationTable: mkTable(dep, "Cache"),
  });
  app.synth();

  const outFile = path.join(dir, "PERMISSIONS.json");
  const count = writePermissionManifest(dir, outFile);
  return {
    manifest: JSON.parse(fs.readFileSync(outFile, "utf-8")) as Manifest,
    count,
    dir,
  };
}

describe("the permission manifest", () => {
  let manifest: Manifest;
  let count: number;

  beforeAll(() => {
    delete process.env.COA_PVT_VPC_CONFIG;
    ({ manifest, count } = buildManifest());
  });

  test("records the statements standard mode attaches", () => {
    expect(count).toBeGreaterThan(0);
    expect(manifest.statementCount).toBe(count);
  });

  test("is keyed by the ROLE NAME the operator pre-creates", () => {
    // Not by CDK's logical id, which appears nowhere in an IAM package. A
    // manifest an operator cannot map to their own roles is not diffable, and
    // diffing is the only thing it is for.
    const keys = Object.keys(manifest.roles);
    expect(keys.length).toBeGreaterThan(0);
    for (const key of keys) {
      expect(key).toContain(`${DEFAULT_RESOURCE_PREFIX}-${DEFAULT_ENV}-`);
    }
  });

  test("names the roles from ROLE_NAMES, not generated ids", () => {
    const keys = Object.keys(manifest.roles).join("\n");
    expect(keys).toContain(
      `${DEFAULT_RESOURCE_PREFIX}-${DEFAULT_ENV}-authorizer-fn-role`,
    );
    expect(keys).toContain(
      `${DEFAULT_RESOURCE_PREFIX}-${DEFAULT_ENV}-cache-invalidation-fn-role`,
    );
  });

  test("no key is a CloudFormation-generated logical id", () => {
    // `AuthorizerFnServiceRoleDefaultPolicy7504E436` is what this looked like
    // before role names were pinned — unmappable to anything an operator has.
    for (const key of Object.keys(manifest.roles)) {
      expect(key).not.toMatch(/ServiceRole[0-9A-F]{8}/);
      expect(key).not.toMatch(/DefaultPolicy[0-9A-F]{8}/);
    }
  });

  test("carries the actual policy statements", () => {
    const statements = Object.values(manifest.roles).flat() as {
      Action?: unknown;
      Effect?: string;
    }[];
    expect(statements.length).toBe(count);
    // Every statement must be recognizable as IAM, or the diff is worthless.
    for (const statement of statements) {
      expect(statement.Action).toBeDefined();
      expect(statement.Effect).toBeDefined();
    }
  });

  test("explains what it is for, inside the file", () => {
    // The file outlives this conversation and will be read by someone who was
    // not here, so the warning travels with the data.
    expect(manifest.note.join(" ")).toMatch(/runtime/);
  });

  test("a missing template directory yields no manifest rather than crashing", () => {
    const missing = path.join(os.tmpdir(), "definitely-not-a-cdk-out-dir");
    expect(
      writePermissionManifest(missing, path.join(os.tmpdir(), "x.json")),
    ).toBe(0);
  });

  test("statements for one role are merged, not overwritten", () => {
    // A role can carry an inline policy AND one or more attached
    // AWS::IAM::Policy resources. Keying by role name makes those collide, so
    // the manifest appends; assigning would silently drop whichever came
    // first and under-report what the operator must attach.
    const total = Object.values(manifest.roles).reduce(
      (sum, statements) => sum + statements.length,
      0,
    );
    expect(total).toBe(count);
  });
});
