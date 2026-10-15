// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import * as fs from "fs";
import * as os from "os";
import * as path from "path";

import * as cdk from "aws-cdk-lib";

import {
  loadPvtVpcConfig,
  loadPvtVpcConfigFile,
  pvtVpcRoleArn,
  readVpcIdFromContext,
  validate,
  VPC_ID_CONTEXT_KEY,
  type PvtVpcConfigFile,
} from "../lib/pvt-vpc-config";

/**
 * Two deployment flows share this codebase, selected by `-c vpc_id=` — which
 * was already how this codebase imports a VPC, so no second switch exists.
 *
 * The failure mode that matters is a HALF-filled config: it would import some
 * resources and create others, leaving duplicates behind in an account that
 * was supposed to forbid creation. These tests pin the all-or-nothing
 * contract, and pin that a standard deployment never reads the file at all.
 */

const TEST_VPC_ID = "vpc-0abc123";

/** A complete private-VPC config. No `vpc.id` — that comes from the CLI. */
function completeConfig(): PvtVpcConfigFile {
  return {
    account: "123456789012",
    region: "us-east-1",
    prefix: "coa",
    env: "dev",
    vpc: {
      cidr: "10.0.0.0/16",
      availabilityZones: ["us-east-1b", "us-east-1c"],
      privateSubnetIds: ["subnet-0a", "subnet-0b"],
      privateRouteTableIds: ["rtb-0a", "rtb-0b"],
    },
    securityGroups: {
      lambda: "sg-01",
      ecs: "sg-02",
      neptune: "sg-03",
      aossVpce: "sg-04",
      connector: "sg-05",
      discoveryOcsp: "sg-06",
      agentCore: "sg-07",
      mcp: "sg-08",
    },
    vpcEndpoints: { aossData: "vpce-0aoss" },
  };
}

function writeTempConfig(contents: string): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pvt-vpc-config-"));
  const file = path.join(dir, "config.json");
  fs.writeFileSync(file, contents);
  return file;
}

/** A construct tree carrying (or not carrying) `-c vpc_id=`. */
function scopeWithVpcId(vpcId?: string): cdk.Stack {
  const app = new cdk.App({
    context: vpcId === undefined ? {} : { [VPC_ID_CONTEXT_KEY]: vpcId },
  });
  return new cdk.Stack(app, "Stack");
}

describe("the switch is -c vpc_id=, not a field in the file", () => {
  test("no vpc_id means standard mode", () => {
    expect(loadPvtVpcConfig(scopeWithVpcId()).privateVpcMode).toBe(false);
  });

  test("standard mode never reads the config file", () => {
    // A developer who has never heard of private-VPC mode must be able to
    // synth no matter what the file contains — even if it is corrupt.
    const corrupt = writeTempConfig("{ not json at all");
    expect(() => loadPvtVpcConfig(scopeWithVpcId(), corrupt)).not.toThrow();
    expect(loadPvtVpcConfig(scopeWithVpcId(), corrupt).privateVpcMode).toBe(
      false,
    );
  });

  test("a blank vpc_id is treated as absent", () => {
    expect(loadPvtVpcConfig(scopeWithVpcId("   ")).privateVpcMode).toBe(false);
  });

  test("vpc_id selects private mode and is carried through", () => {
    const file = writeTempConfig(JSON.stringify(completeConfig()));
    const config = loadPvtVpcConfig(scopeWithVpcId(TEST_VPC_ID), file);
    expect(config.privateVpcMode).toBe(true);
    expect(config.vpcId).toBe(TEST_VPC_ID);
  });

  test("readVpcIdFromContext reads the documented key", () => {
    expect(readVpcIdFromContext(scopeWithVpcId(TEST_VPC_ID))).toBe(TEST_VPC_ID);
    expect(readVpcIdFromContext(scopeWithVpcId())).toBeUndefined();
  });

  test("no role ARNs are derived in standard mode", () => {
    expect(
      pvtVpcRoleArn({ privateVpcMode: false }, "authorizer-fn-role"),
    ).toBeUndefined();
  });
});

describe("private-VPC mode requires a complete config", () => {
  test("a complete config has no validation problems", () => {
    expect(validate(completeConfig(), TEST_VPC_ID)).toEqual([]);
  });

  test("validation is skipped entirely without a vpc_id", () => {
    // Nothing to check in standard mode: the app creates its own resources.
    expect(validate({}, undefined)).toEqual([]);
  });

  test.each([
    ["account", (c: PvtVpcConfigFile) => ({ ...c, account: "" })],
    [
      "securityGroups.ecs",
      (c: PvtVpcConfigFile) => ({
        ...c,
        securityGroups: { ...c.securityGroups, ecs: "" },
      }),
    ],
    [
      "vpcEndpoints.aossData",
      (c: PvtVpcConfigFile) => ({ ...c, vpcEndpoints: { aossData: "" } }),
    ],
    [
      "vpc.privateRouteTableIds",
      (c: PvtVpcConfigFile) => ({
        ...c,
        vpc: { ...c.vpc, privateRouteTableIds: [] },
      }),
    ],
  ])("a blank %s is reported", (key, mutate) => {
    const problems = validate(mutate(completeConfig()), TEST_VPC_ID);
    expect(problems.join("\n")).toContain(key);
  });

  test("every problem is reported at once, not one per synth", () => {
    // An operator filling in 40 fields should not have to rerun the synth once
    // per mistake.
    const problems = validate(
      { ...completeConfig(), account: "", securityGroups: {} },
      TEST_VPC_ID,
    );
    expect(problems.length).toBeGreaterThan(5);
  });

  test("the three positional lists must be the same length", () => {
    // subnet[i] lives in zone[i] and uses route table[i]. CDK zips them and
    // silently drops extras, so a mismatch places subnets in the wrong zone
    // with no warning — and Neptune's "multi-AZ" group could end up single-AZ.
    const problems = validate(
      {
        ...completeConfig(),
        vpc: {
          cidr: "10.0.0.0/16",
          availabilityZones: ["us-east-1b"],
          privateSubnetIds: ["subnet-0a", "subnet-0b"],
          privateRouteTableIds: ["rtb-0a", "rtb-0b"],
        },
      },
      TEST_VPC_ID,
    );
    expect(problems.join("\n")).toContain("positional");
  });

  test("duplicate availability zones are rejected", () => {
    // Two subnets in the SAME zone satisfies "at least 2 subnets" while still
    // leaving Neptune single-AZ.
    const problems = validate(
      {
        ...completeConfig(),
        vpc: {
          cidr: "10.0.0.0/16",
          availabilityZones: ["us-east-1b", "us-east-1b"],
          privateSubnetIds: ["subnet-0a", "subnet-0b"],
          privateRouteTableIds: ["rtb-0a", "rtb-0b"],
        },
      },
      TEST_VPC_ID,
    );
    expect(problems.join("\n")).toContain("duplicates");
  });

  test.each(["vpc.cidr", "vpc.availabilityZones"])(
    "a missing %s is reported",
    (key) => {
      // Both are needed by fromVpcAttributes and cannot be derived from a
      // subnet id without an AWS call.
      const vpc = { ...completeConfig().vpc } as Record<string, unknown>;
      delete vpc[key.replace("vpc.", "")];
      const problems = validate({ ...completeConfig(), vpc }, TEST_VPC_ID);
      expect(problems.join("\n")).toContain(key);
    },
  );

  test("a single subnet is rejected - Neptune and AgentCore both need two AZs", () => {
    const problems = validate(
      {
        ...completeConfig(),
        vpc: {
          cidr: "10.0.0.0/16",
          availabilityZones: ["us-east-1b"],
          privateSubnetIds: ["subnet-0a"],
          privateRouteTableIds: ["rtb-0a"],
        },
      },
      TEST_VPC_ID,
    );
    expect(problems.join("\n")).toContain("at least 2 subnets");
  });

  test("loading an incomplete config throws, naming the missing fields", () => {
    const file = writeTempConfig(
      JSON.stringify({ ...completeConfig(), securityGroups: {} }),
    );
    expect(() => loadPvtVpcConfigFile(TEST_VPC_ID, file)).toThrow(
      /securityGroups\.lambda/,
    );
  });

  test("the error names the VPC being deployed into", () => {
    const file = writeTempConfig(
      JSON.stringify({ ...completeConfig(), account: "" }),
    );
    expect(() => loadPvtVpcConfigFile(TEST_VPC_ID, file)).toThrow(
      new RegExp(TEST_VPC_ID),
    );
  });

  test("the error explains how to get back to standard mode", () => {
    const file = writeTempConfig(
      JSON.stringify({ ...completeConfig(), account: "" }),
    );
    expect(() => loadPvtVpcConfigFile(TEST_VPC_ID, file)).toThrow(
      /drop the -c vpc_id= flag/,
    );
  });

  test("a missing file is an error once vpc_id is given", () => {
    // The opposite of standard mode, where a missing file is how the flow is
    // expressed. Here it would mean importing a VPC while CREATING the
    // security groups and roles inside it — the duplicate-resource state.
    const missing = path.join(os.tmpdir(), "definitely-not-here-config.json");
    expect(() => loadPvtVpcConfigFile(TEST_VPC_ID, missing)).toThrow(
      /does not exist/,
    );
  });
});

describe("malformed config is an error, never a silent fallback", () => {
  test("invalid JSON throws", () => {
    const file = writeTempConfig("{ not json");
    expect(() => loadPvtVpcConfigFile(TEST_VPC_ID, file)).toThrow(
      /not valid JSON/,
    );
  });

  test("a JSON array throws", () => {
    const file = writeTempConfig("[]");
    expect(() => loadPvtVpcConfigFile(TEST_VPC_ID, file)).toThrow(
      /must contain a JSON object/,
    );
  });
});

describe("role ARNs are derived, not configured", () => {
  test("an ARN is built from account, prefix and env", () => {
    const file = writeTempConfig(JSON.stringify(completeConfig()));
    const config = loadPvtVpcConfigFile(TEST_VPC_ID, file);
    expect(pvtVpcRoleArn(config, "authorizer-fn-role")).toBe(
      "arn:aws:iam::123456789012:role/coa-dev-authorizer-fn-role",
    );
  });

  test("prefix and env flow through to every derived name", () => {
    const file = writeTempConfig(
      JSON.stringify({ ...completeConfig(), prefix: "scl", env: "prod" }),
    );
    const config = loadPvtVpcConfigFile(TEST_VPC_ID, file);
    expect(pvtVpcRoleArn(config, "sources-api-role")).toBe(
      "arn:aws:iam::123456789012:role/scl-prod-sources-api-role",
    );
  });
});

describe("the committed config.json template", () => {
  test("parses, and is reported as incomplete rather than crashing", () => {
    // The shipped template has every field blank. Loading it with a vpc_id
    // must produce the field-by-field error, not a parse failure or a silent
    // standard-mode fallback.
    const committed = path.join(__dirname, "..", "pvt_vpc", "config.json");
    if (!fs.existsSync(committed)) {
      return;
    }
    expect(() => loadPvtVpcConfigFile(TEST_VPC_ID, committed)).toThrow(
      /is incomplete for a private-VPC deployment/,
    );
  });

  test("is ignored entirely in standard mode", () => {
    const committed = path.join(__dirname, "..", "pvt_vpc", "config.json");
    if (!fs.existsSync(committed)) {
      return;
    }
    expect(loadPvtVpcConfig(scopeWithVpcId(), committed).privateVpcMode).toBe(
      false,
    );
  });
});
