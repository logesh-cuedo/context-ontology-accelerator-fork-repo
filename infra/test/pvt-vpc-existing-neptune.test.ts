// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import * as fs from "fs";
import * as os from "os";
import * as path from "path";

import * as cdk from "aws-cdk-lib";
import { Template } from "aws-cdk-lib/assertions";

import { NetworkStack } from "../lib/stacks/foundation/network-stack";
import { StorageStack } from "../lib/stacks/foundation/storage-stack";
import { resolveExistingNeptune } from "../lib/pvt-vpc-config";

/**
 * A client may already run a graph database. `existing.neptune` in the config
 * points the deployment at theirs instead of creating a second one.
 *
 * Two properties matter:
 *
 *   - it works in BOTH flows, because an existing cluster is possible whether
 *     or not the VPC was also pre-created;
 *   - a blank block changes nothing, because that is the shipped state of the
 *     config and every existing deployment relies on it.
 *
 * The expensive mistake it guards is `clusterResourceId`. Every IAM data-access
 * policy is `arn:aws:neptune-db:…:{clusterResourceId}/*`, so putting the
 * cluster NAME there yields a valid-looking ARN that matches nothing and denies
 * every request — at runtime, not at deploy.
 */

const ENV = { account: "123456789012", region: "us-east-1" };

const EXISTING = {
  clusterEndpoint: "acme-graph.cluster-cxyz987.us-east-1.neptune.amazonaws.com",
  port: "8182",
  clusterResourceId: "cluster-ABCD1234EFGH5678",
};

/** Write a config file; `neptune` is merged into `existing`. */
function writeConfig(neptune?: Record<string, string>): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "existing-neptune-"));
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
      },
      vpcEndpoints: { aossData: "vpce-0aoss" },
      ...(neptune ? { existing: { neptune } } : {}),
    }),
  );
  return file;
}

/** Synthesize StorageStack, optionally in private-VPC mode. */
function synth(options: { privateVpc?: boolean } = {}): Template {
  const app = new cdk.App({
    context: {
      resource_prefix: "coa",
      env: "dev",
      ...(options.privateVpc ? { vpc_id: "vpc-0abc123" } : {}),
    },
  });
  const network = new NetworkStack(app, "Network", { env: ENV });
  return Template.fromStack(
    new StorageStack(app, "Storage", { network, env: ENV }),
  );
}

const NEPTUNE_TYPES = [
  "AWS::Neptune::DBCluster",
  "AWS::Neptune::DBInstance",
  "AWS::Neptune::DBSubnetGroup",
] as const;

describe("no existing cluster configured", () => {
  afterEach(() => {
    delete process.env.COA_PVT_VPC_CONFIG;
  });

  test("standard mode creates its own Neptune", () => {
    delete process.env.COA_PVT_VPC_CONFIG;
    const template = synth();
    for (const type of NEPTUNE_TYPES) {
      template.resourceCountIs(type, 1);
    }
  });

  test("private-VPC mode also creates its own Neptune", () => {
    // Pre-creating the VPC says nothing about the database. Neptune is an
    // application resource the deployment owns unless told otherwise.
    process.env.COA_PVT_VPC_CONFIG = writeConfig();
    const template = synth({ privateVpc: true });
    for (const type of NEPTUNE_TYPES) {
      template.resourceCountIs(type, 1);
    }
  });

  test("a port-only block is treated as blank", () => {
    // The shipped template pre-fills port 8182 as a hint. Treating that as a
    // partially filled block would throw on every deployment, including the
    // standard flow that never reads this file.
    process.env.COA_PVT_VPC_CONFIG = writeConfig({
      clusterEndpoint: "",
      port: "8182",
      clusterResourceId: "",
    });
    expect(resolveExistingNeptune()).toBeUndefined();
    const template = synth();
    for (const type of NEPTUNE_TYPES) {
      template.resourceCountIs(type, 1);
    }
  });

  test("the committed config.json does not switch it on", () => {
    const committed = path.join(__dirname, "..", "pvt_vpc", "config.json");
    if (!fs.existsSync(committed)) {
      return;
    }
    expect(resolveExistingNeptune(undefined, committed)).toBeUndefined();
  });
});

describe("an existing cluster is configured", () => {
  afterEach(() => {
    delete process.env.COA_PVT_VPC_CONFIG;
  });

  test("creates no Neptune resources at all", () => {
    process.env.COA_PVT_VPC_CONFIG = writeConfig(EXISTING);
    const template = synth();
    for (const type of NEPTUNE_TYPES) {
      expect(Object.keys(template.findResources(type))).toEqual([]);
    }
  });

  test("works in private-VPC mode too", () => {
    process.env.COA_PVT_VPC_CONFIG = writeConfig(EXISTING);
    const template = synth({ privateVpc: true });
    for (const type of NEPTUNE_TYPES) {
      expect(Object.keys(template.findResources(type))).toEqual([]);
    }
  });

  test("publishes the configured endpoint, not a generated one", () => {
    process.env.COA_PVT_VPC_CONFIG = writeConfig(EXISTING);
    synth().hasOutput("NeptuneClusterEndpointOutput", {
      Value: EXISTING.clusterEndpoint,
    });
  });

  test("the IAM ARN is built from the resource id", () => {
    // What every downstream policy is scoped to. The `/*` suffix is part of
    // the contract: consumers append nothing.
    process.env.COA_PVT_VPC_CONFIG = writeConfig(EXISTING);
    const resolved = resolveExistingNeptune();
    expect(resolved?.clusterResourceId).toBe(EXISTING.clusterResourceId);
    expect(resolved?.clusterEndpoint).toBe(EXISTING.clusterEndpoint);
    expect(resolved?.port).toBe("8182");
  });
});

describe("a half-filled block is rejected at synth", () => {
  afterEach(() => {
    delete process.env.COA_PVT_VPC_CONFIG;
  });

  test("an endpoint with no resource id throws", () => {
    // Would leave every IAM policy pointing at nothing.
    process.env.COA_PVT_VPC_CONFIG = writeConfig({
      clusterEndpoint: EXISTING.clusterEndpoint,
      port: "8182",
      clusterResourceId: "",
    });
    expect(() => resolveExistingNeptune()).toThrow(
      /clusterResourceId is required/,
    );
  });

  test("a resource id with no endpoint throws", () => {
    process.env.COA_PVT_VPC_CONFIG = writeConfig({
      clusterEndpoint: "",
      port: "8182",
      clusterResourceId: EXISTING.clusterResourceId,
    });
    expect(() => resolveExistingNeptune()).toThrow(
      /clusterEndpoint is required/,
    );
  });

  test("the cluster NAME in place of the resource id throws", () => {
    // The mistake this validation exists for. `coa-dev-neptune` is a valid
    // cluster identifier and a useless ARN component.
    process.env.COA_PVT_VPC_CONFIG = writeConfig({
      ...EXISTING,
      clusterResourceId: "coa-dev-neptune",
    });
    expect(() => resolveExistingNeptune()).toThrow(/cluster RESOURCE id/);
  });

  test("the error shows how to find the real resource id", () => {
    process.env.COA_PVT_VPC_CONFIG = writeConfig({
      ...EXISTING,
      clusterResourceId: "coa-dev-neptune",
    });
    expect(() => resolveExistingNeptune()).toThrow(/describe-db-clusters/);
  });

  test("an endpoint carrying a scheme throws", () => {
    // The app builds `https://{endpoint}:{port}`, so a scheme here produces
    // `https://https://host:8182` and fails at first connection.
    process.env.COA_PVT_VPC_CONFIG = writeConfig({
      ...EXISTING,
      clusterEndpoint: `https://${EXISTING.clusterEndpoint}`,
    });
    expect(() => resolveExistingNeptune()).toThrow(/host only/);
  });

  test("an endpoint carrying a port throws", () => {
    process.env.COA_PVT_VPC_CONFIG = writeConfig({
      ...EXISTING,
      clusterEndpoint: `${EXISTING.clusterEndpoint}:8182`,
    });
    expect(() => resolveExistingNeptune()).toThrow(/host only/);
  });

  test("a non-numeric port throws", () => {
    process.env.COA_PVT_VPC_CONFIG = writeConfig({
      ...EXISTING,
      port: "eight-one-eight-two",
    });
    expect(() => resolveExistingNeptune()).toThrow(/must be a port number/);
  });

  test("every problem is reported at once", () => {
    process.env.COA_PVT_VPC_CONFIG = writeConfig({
      clusterEndpoint: "",
      port: "nope",
      clusterResourceId: "coa-dev-neptune",
    });
    let message = "";
    try {
      resolveExistingNeptune();
    } catch (err) {
      message = (err as Error).message;
    }
    expect(message).toContain("clusterEndpoint is required");
    expect(message).toContain("cluster RESOURCE id");
    expect(message).toContain("must be a port number");
  });
});
