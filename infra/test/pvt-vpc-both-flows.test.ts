// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import * as fs from "fs";
import * as os from "os";
import * as path from "path";

import * as cdk from "aws-cdk-lib";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as lambda from "aws-cdk-lib/aws-lambda";
import { Template } from "aws-cdk-lib/assertions";
import type { Construct } from "constructs";

jest.mock("../lib/utils/python-bundling", () => ({
  bundlePython: () => lambda.Code.fromInline("def handler(e,c): pass"),
}));

import { ApiStack } from "../lib/stacks/services/api-stack";
import { AuthnzStack } from "../lib/stacks/foundation/authnz-stack";
import { DEFAULT_RESOURCE_PREFIX, DEFAULT_ENV } from "../lib/constants";
import { VPC_ID_CONTEXT_KEY } from "../lib/pvt-vpc-config";

/**
 * The end-to-end contract for the two deployment flows, asserted across more
 * than one stack because the gaps this file was written to catch were in
 * DIFFERENT stacks from the ones the per-stack mode tests cover.
 *
 *   STANDARD      — the app creates its own VPC, security groups, endpoints
 *                   and IAM roles, exactly as it always has.
 *
 *   PRIVATE VPC   — the account owner pre-created all of that, because the
 *                   pipeline is denied `iam:CreateRole`,
 *                   `ec2:CreateSecurityGroup` and `ec2:CreateVpcEndpoint`.
 *                   The app creates ONLY application resources.
 *
 * Two real gaps were found by exactly this comparison, both of which the
 * per-stack tests missed:
 *
 *   1. `api-stack` passed `vpc:` without `securityGroups:`, so CDK created an
 *      automatic security group PER VPC-attached function. Private mode
 *      imported six groups and then created two more it ignored.
 *
 *   2. `AwsCustomResource` emits an `AWS::IAM::Policy` per instance when given
 *      a `policy`, even when the role is supplied. Seven appeared in authnz.
 *
 * Both are the same class of bug: a resource type the account refuses,
 * created by a construct that was never audited because no test counted
 * resources across stacks.
 */

const ENV = { account: "123456789012", region: "us-east-1" };
const TEST_CONTEXT = {
  resource_prefix: DEFAULT_RESOURCE_PREFIX,
  env: DEFAULT_ENV,
  "aws:cdk:bundling-stacks": [],
};

/** Resource types a locked-down account denies the pipeline. */
const REFUSED_TYPES = [
  "AWS::IAM::Role",
  "AWS::IAM::Policy",
  "AWS::EC2::VPC",
  "AWS::EC2::SecurityGroup",
  "AWS::EC2::VPCEndpoint",
] as const;

/** Application resources, which BOTH flows must create identically. */
const APPLICATION_TYPES = [
  "AWS::Lambda::Function",
  "AWS::ApiGateway::RestApi",
  "AWS::DynamoDB::Table",
] as const;

function writePrivateConfig(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "both-flows-"));
  const file = path.join(dir, "config.json");
  fs.writeFileSync(
    file,
    JSON.stringify({
      account: ENV.account,
      region: ENV.region,
      prefix: DEFAULT_RESOURCE_PREFIX,
      env: DEFAULT_ENV,
      vpc: {
        id: "vpc-0abc123",
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
    }),
  );
  return file;
}

const mkTable = (scope: Construct, id: string) =>
  new dynamodb.Table(scope, id, {
    partitionKey: { name: "PK", type: dynamodb.AttributeType.STRING },
    stream: dynamodb.StreamViewType.NEW_AND_OLD_IMAGES,
  });

interface Tally {
  readonly refused: Record<string, number>;
  readonly application: Record<string, number>;
  /** `stack/logicalId` of every refused resource, for a useful failure. */
  readonly offenders: string[];
}

/**
 * Synthesize several stacks and count resources by class.
 *
 * The dependency stack (VPC, security group, tables) is excluded from the
 * tally: in a real private-VPC deployment those come from the config, and
 * counting the fixtures that stand in for them here would hide the result.
 */
function tally(vpcId?: string): Tally {
  // `-c vpc_id=` is the switch that selects a private-VPC deployment; the
  // config file supplies that VPC's subnets, security groups and endpoints.
  const app = new cdk.App({
    context:
      vpcId === undefined
        ? TEST_CONTEXT
        : { ...TEST_CONTEXT, [VPC_ID_CONTEXT_KEY]: vpcId },
  });
  const dep = new cdk.Stack(app, "Dep", { env: ENV });
  const vpc = new ec2.Vpc(dep, "Vpc");
  const lambdaSecurityGroup = new ec2.SecurityGroup(dep, "LambdaSG", { vpc });

  const stacks: cdk.Stack[] = [
    new ApiStack(app, "Api", {
      env: ENV,
      allowedOrigin: "*",
      vpc,
      lambdaSecurityGroup,
      rolesTable: mkTable(dep, "Roles"),
      resourceRoleMappingsTable: mkTable(dep, "RRM"),
      cacheInvalidationTable: mkTable(dep, "Cache"),
    }),
    new AuthnzStack(app, "Authnz", { env: ENV }),
  ];

  const refused: Record<string, number> = {};
  const application: Record<string, number> = {};
  const offenders: string[] = [];

  for (const stack of stacks) {
    const template = Template.fromStack(stack);
    for (const type of REFUSED_TYPES) {
      const found = template.findResources(type);
      refused[type] = (refused[type] ?? 0) + Object.keys(found).length;
      for (const logicalId of Object.keys(found)) {
        offenders.push(`${stack.stackName}/${type}/${logicalId}`);
      }
    }
    for (const type of APPLICATION_TYPES) {
      application[type] =
        (application[type] ?? 0) +
        Object.keys(template.findResources(type)).length;
    }
  }
  return { refused, application, offenders };
}

describe("both deployment flows", () => {
  let standard: Tally;
  let privateVpc: Tally;

  beforeAll(() => {
    delete process.env.COA_PVT_VPC_CONFIG;
    standard = tally();

    process.env.COA_PVT_VPC_CONFIG = writePrivateConfig();
    privateVpc = tally("vpc-0abc123");
    delete process.env.COA_PVT_VPC_CONFIG;
  });

  afterAll(() => {
    delete process.env.COA_PVT_VPC_CONFIG;
  });

  describe("standard mode still builds its own infrastructure", () => {
    test("creates IAM roles", () => {
      expect(standard.refused["AWS::IAM::Role"]).toBeGreaterThan(0);
    });

    test("creates IAM policies, so grants still attach", () => {
      // The 193 grant/addToRolePolicy calls across the service stacks have to
      // keep working for a deployment that creates its own roles.
      expect(standard.refused["AWS::IAM::Policy"]).toBeGreaterThan(0);
    });
  });

  describe("private mode creates nothing the account would refuse", () => {
    test.each(REFUSED_TYPES)("zero %s", (type) => {
      expect(privateVpc.refused[type]).toBe(0);
    });

    test("names every offending resource when it regresses", () => {
      // The assertion that actually matters, phrased so a failure says WHICH
      // construct reintroduced a refused resource rather than just a count.
      expect(privateVpc.offenders).toEqual([]);
    });
  });

  describe("the application deploys identically in both flows", () => {
    test.each(APPLICATION_TYPES)("same number of %s", (type) => {
      // Private mode imports infrastructure; it does not deploy less of the
      // application. A difference here means an application resource was
      // skipped along with the infrastructure.
      expect(privateVpc.application[type]).toBe(standard.application[type]);
    });

    test("and actually creates some", () => {
      // Guards against both tallies being zero, which would make the equality
      // above pass while nothing deployed at all.
      for (const type of APPLICATION_TYPES) {
        expect(privateVpc.application[type]).toBeGreaterThan(0);
      }
    });
  });
});
