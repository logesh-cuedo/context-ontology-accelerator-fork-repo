// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import * as fs from "fs";
import * as os from "os";
import * as path from "path";

import * as cdk from "aws-cdk-lib";
import { Template } from "aws-cdk-lib/assertions";

import { NetworkStack } from "../lib/stacks/foundation/network-stack";

/**
 * Two deployment flows share NetworkStack, and the one that previously went
 * wrong is the private-VPC path: importing a VPC still created six NEW
 * security groups inside it, leaving twelve in the account with the app
 * silently using its own and ignoring the ones the network team made.
 *
 * These tests pin both directions — a standard deployment still builds
 * everything, and a private-VPC deployment synthesizes a template a
 * locked-down account will actually accept.
 */

const ENV = { account: "123456789012", region: "us-east-1" };

/** The VPC id, supplied on the command line as `-c vpc_id=`. */
const PRIVATE_VPC_ID = "vpc-0abc123";

/** The config file: the DETAILS of that VPC, never its id. */
const PRIVATE_VPC_CONFIG = {
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

describe("standard deployment", () => {
  test("still creates its own VPC, endpoints and security groups", () => {
    const stack = new NetworkStack(new cdk.App(), "coa-dev-network", {
      env: ENV,
    });
    const template = Template.fromStack(stack);

    template.resourceCountIs("AWS::EC2::VPC", 1);
    expect(
      Object.keys(template.findResources("AWS::EC2::SecurityGroup")).length,
    ).toBeGreaterThanOrEqual(6);
    expect(
      Object.keys(template.findResources("AWS::EC2::VPCEndpoint")).length,
    ).toBeGreaterThan(15);
    template.resourceCountIs("AWS::ServiceDiscovery::PrivateDnsNamespace", 1);
  });
});

describe("private-VPC deployment", () => {
  let configPath: string;

  beforeAll(() => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "coa-pvt-vpc-"));
    configPath = path.join(dir, "config.json");
    fs.writeFileSync(configPath, JSON.stringify(PRIVATE_VPC_CONFIG));
    process.env.COA_PVT_VPC_CONFIG = configPath;
  });

  afterAll(() => {
    delete process.env.COA_PVT_VPC_CONFIG;
  });

  function synth(): Template {
    const app = new cdk.App({ context: { vpc_id: PRIVATE_VPC_ID } });
    return Template.fromStack(
      new NetworkStack(app, "coa-dev-network", { env: ENV }),
    );
  }

  test("creates nothing a locked-down account would refuse", () => {
    // The whole point of the private-VPC flow. If any of these appear, the
    // deploy fails on iam:CreateRole or ec2:CreateSecurityGroup.
    const template = synth();
    expect(
      Object.keys(template.findResources("AWS::EC2::SecurityGroup")),
    ).toEqual([]);
    expect(Object.keys(template.findResources("AWS::EC2::VPC"))).toEqual([]);
    expect(
      Object.keys(template.findResources("AWS::EC2::VPCEndpoint")),
    ).toEqual([]);
    expect(Object.keys(template.findResources("AWS::IAM::Role"))).toEqual([]);
  });

  test("still creates the Cloud Map namespace", () => {
    // An application resource, not pre-created infrastructure: nothing in a
    // locked-down account forbids creating it, and the ontology API proxy
    // resolves the engine through it.
    synth().resourceCountIs("AWS::ServiceDiscovery::PrivateDnsNamespace", 1);
  });

  test("still publishes the SSM cross-app contract", () => {
    // Other CDK apps (today the Databricks connector) read these to attach
    // their own compute to this VPC, so skipping them would break an
    // integration that has nothing to do with security groups.
    synth().resourceCountIs("AWS::SSM::Parameter", 2);
  });

  test("exposes the pre-created AOSS endpoint id from config", () => {
    // StorageStack names this in the OpenSearch network policy's SourceVPCEs,
    // which is what confines the vector store to the VPC.
    //
    // Regression test. `aossVpcEndpointId` was assigned ONLY in the
    // create-the-VPC branch, so importing a VPC left it undefined and the
    // policy shipped as `"SourceVPCEs": [undefined]` — a rule granting
    // nothing. Dev masked it via AllowFromPublic (reachable, but PUBLIC);
    // every other environment could not reach the collection at all.
    const app = new cdk.App({ context: { vpc_id: PRIVATE_VPC_ID } });
    const stack = new NetworkStack(app, "coa-dev-network", { env: ENV });
    expect(stack.aossVpcEndpointId).toBe(
      PRIVATE_VPC_CONFIG.vpcEndpoints.aossData,
    );
  });
});
