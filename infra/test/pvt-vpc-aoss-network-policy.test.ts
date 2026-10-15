// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import * as fs from "fs";
import * as os from "os";
import * as path from "path";

import * as cdk from "aws-cdk-lib";
import { Template } from "aws-cdk-lib/assertions";

import { NetworkStack } from "../lib/stacks/foundation/network-stack";
import { StorageStack } from "../lib/stacks/foundation/storage-stack";
import { VPC_ID_CONTEXT_KEY } from "../lib/pvt-vpc-config";

/**
 * The OpenSearch Serverless network policy is what confines the vector store
 * to the VPC, and it has two independent ways of going wrong.
 *
 * 1. `SourceVPCEs` must name the AOSS data-plane endpoint. An empty entry is
 *    not a synth error — it ships as `[undefined]`, a rule granting nothing.
 *
 * 2. `AllowFromPublic: true` is ADDITIVE. It does not replace the SourceVPCEs
 *    rule, it opens a second door beside it, so a policy can look correct
 *    while the collection is reachable from the internet.
 *
 * The dev exemption for (2) exists so integration tests can reach the
 * collection from a laptop. But `env` is "dev" in a private-VPC deployment too
 * — it is part of every resource name — so keying the exemption on the env
 * alone handed a locked-down account a PUBLIC vector store.
 */

const ENV = { account: "123456789012", region: "us-east-1" };
const PRIVATE_VPC_ID = "vpc-0abc123";
const AOSS_ENDPOINT = "vpce-0aossdata";

function writeConfig(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "aoss-policy-"));
  const file = path.join(dir, "config.json");
  fs.writeFileSync(
    file,
    JSON.stringify({
      account: ENV.account,
      region: ENV.region,
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
      vpcEndpoints: { aossData: AOSS_ENDPOINT },
    }),
  );
  return file;
}

interface NetworkRule {
  readonly SourceVPCEs?: string[];
  readonly AllowFromPublic?: boolean;
}

/** The parsed network policy for a given deployment. */
function networkPolicy(context: Record<string, unknown>): NetworkRule[] {
  const app = new cdk.App({ context: { resource_prefix: "coa", ...context } });
  const network = new NetworkStack(app, "Network", { env: ENV });
  const storage = new StorageStack(app, "Storage", { network, env: ENV });

  const policies = Template.fromStack(storage).findResources(
    "AWS::OpenSearchServerless::SecurityPolicy",
  );
  const net = Object.values(policies).find(
    (p) =>
      (p as { Properties?: { Type?: string } }).Properties?.Type === "network",
  ) as { Properties: { Policy: unknown } };

  // In private mode the endpoint id is a literal from config, so `Policy` is a
  // JSON string. In standard mode it is a CloudFormation token for the
  // endpoint CDK just created, so `Policy` comes back as an `Fn::Join`
  // structure instead. Both have to be read, because the point of these tests
  // is to compare the two flows.
  const policy = net.Properties.Policy;
  if (typeof policy === "string") {
    return JSON.parse(policy) as NetworkRule[];
  }
  // Flatten the Fn::Join back into the policy text. Each embedded token
  // (Fn::ImportValue for the endpoint CDK created in NetworkStack) sits INSIDE
  // the JSON string, between the quotes CDK already emitted, so it is replaced
  // with a bare placeholder rather than a quoted one. These assertions only
  // ask whether a rule exists and how many endpoints it names, never the id.
  return JSON.parse(flattenJoin(policy)) as NetworkRule[];
}

/**
 * Render an `Fn::Join` back into a single string, substituting a placeholder
 * for any unresolved token so the result is parseable JSON.
 */
function flattenJoin(value: unknown): string {
  if (typeof value === "string") {
    return value;
  }
  const join = (value as { "Fn::Join"?: [string, unknown[]] })["Fn::Join"];
  if (join) {
    const [separator, parts] = join;
    return parts.map(flattenJoin).join(separator);
  }
  // An unresolved token — Fn::ImportValue, Ref, Fn::GetAtt. It appears where a
  // literal endpoint id would, already inside quotes in the surrounding JSON.
  return "<token>";
}

describe("private-VPC deployment", () => {
  let rules: NetworkRule[];

  beforeAll(() => {
    process.env.COA_PVT_VPC_CONFIG = writeConfig();
    rules = networkPolicy({ [VPC_ID_CONTEXT_KEY]: PRIVATE_VPC_ID, env: "dev" });
  });

  afterAll(() => {
    delete process.env.COA_PVT_VPC_CONFIG;
  });

  test("the vector store is NOT public, even though env is dev", () => {
    // The regression. `env: "dev"` is normal in a private-VPC deployment, so
    // the dev exemption must key on the FLOW, not the env name. Before this,
    // a locked-down account got a publicly reachable vector store.
    expect(rules.some((r) => r.AllowFromPublic)).toBe(false);
  });

  test("access is confined to the pre-created AOSS endpoint", () => {
    const sources = rules.flatMap((r) => r.SourceVPCEs ?? []);
    expect(sources).toEqual([AOSS_ENDPOINT]);
  });

  test("no rule carries an undefined endpoint", () => {
    // `[undefined]` serialises to `[null]` and grants nothing, with the first
    // symptom at runtime. StorageStack now fails the synth instead.
    const sources = rules.flatMap((r) => r.SourceVPCEs ?? []);
    expect(sources).not.toContain(null);
    expect(sources.every((s) => typeof s === "string" && s.length > 0)).toBe(
      true,
    );
  });

  test("exactly one rule, so there is no second door", () => {
    expect(rules).toHaveLength(1);
  });
});

describe("standard deployment is unchanged", () => {
  beforeAll(() => {
    delete process.env.COA_PVT_VPC_CONFIG;
  });

  test("dev still allows public access for laptop integration tests", () => {
    // The exemption is deliberate in the standard flow and must survive: the
    // CICD pipeline and developer laptops reach the collection directly.
    const rules = networkPolicy({ env: "dev" });
    expect(rules.some((r) => r.AllowFromPublic)).toBe(true);
  });

  test("dev still also confines the VPC rule to its own endpoint", () => {
    const rules = networkPolicy({ env: "dev" });
    const sources = rules.flatMap((r) => r.SourceVPCEs ?? []);
    expect(sources).toHaveLength(1);
  });

  test("prod is VPC-only, with no public rule", () => {
    const rules = networkPolicy({ env: "prod" });
    expect(rules.some((r) => r.AllowFromPublic)).toBe(false);
    expect(rules).toHaveLength(1);
  });

  test("tst and demo are VPC-only too", () => {
    for (const env of ["tst", "demo"]) {
      const rules = networkPolicy({ env });
      expect(rules.some((r) => r.AllowFromPublic)).toBe(false);
    }
  });
});
