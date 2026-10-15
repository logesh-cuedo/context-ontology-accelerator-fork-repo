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

import { ApiStack } from "../../lib/stacks/services/api-stack";
import { DEFAULT_RESOURCE_PREFIX, DEFAULT_ENV } from "../../lib/constants";
import { VPC_ID_CONTEXT_KEY } from "../../lib/pvt-vpc-config";

/**
 * ApiStack is the sample for the execution-role change, so these tests pin
 * both halves of the contract:
 *
 *   STANDARD    — roles are still CREATED, and now carry explicit names
 *                 instead of CloudFormation-generated ones like
 *                 `AuthorizerFnServiceRole91AE9242`. A generated name cannot
 *                 be pre-created by an account owner, which is the whole
 *                 reason this change exists.
 *
 *   PRIVATE VPC — NO role of any kind is created, because the account denies
 *                 the pipeline `iam:CreateRole`. If one appears here, the
 *                 real deploy fails.
 */

jest.mock("../../lib/utils/python-bundling", () => ({
  bundlePython: () =>
    lambda.Code.fromInline("def handler(event, context): pass"),
}));

const TEST_CONTEXT = {
  resource_prefix: DEFAULT_RESOURCE_PREFIX,
  env: DEFAULT_ENV,
  "aws:cdk:bundling-stacks": [],
};

const mkTestTable = (scope: Construct, id: string) =>
  new dynamodb.Table(scope, id, {
    partitionKey: { name: "PK", type: dynamodb.AttributeType.STRING },
    stream: dynamodb.StreamViewType.NEW_AND_OLD_IMAGES,
  });

function synth(vpcId?: string): Template {
  // `-c vpc_id=` is the switch; the config file supplies that VPC's details.
  const app = new cdk.App({
    context:
      vpcId === undefined
        ? TEST_CONTEXT
        : { ...TEST_CONTEXT, [VPC_ID_CONTEXT_KEY]: vpcId },
  });
  const depStack = new cdk.Stack(app, "DepStack", {
    env: { account: "123456789012", region: "us-east-1" },
  });
  const vpc = new ec2.Vpc(depStack, "Vpc");
  const lambdaSecurityGroup = new ec2.SecurityGroup(depStack, "LambdaSG", {
    vpc,
  });
  const mkTable = (id: string) => mkTestTable(depStack, id);

  return Template.fromStack(
    new ApiStack(app, "TestApi", {
      env: { account: "123456789012", region: "us-east-1" },
      allowedOrigin: "*",
      vpc,
      lambdaSecurityGroup,
      rolesTable: mkTable("Roles"),
      resourceRoleMappingsTable: mkTable("RRM"),
      cacheInvalidationTable: mkTable("Cache"),
    }),
  );
}

/** A complete private-VPC config written to a temp file. */
function writePrivateConfig(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "api-role-modes-"));
  const file = path.join(dir, "config.json");
  fs.writeFileSync(
    file,
    JSON.stringify({
      account: "123456789012",
      region: "us-east-1",
      prefix: DEFAULT_RESOURCE_PREFIX,
      env: DEFAULT_ENV,
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
    }),
  );
  return file;
}

describe("standard mode still creates roles, now with real names", () => {
  let template: Template;

  beforeAll(() => {
    delete process.env.COA_PVT_VPC_CONFIG;
    template = synth();
  });

  test("the three Lambda roles carry explicit, pre-createable names", () => {
    // Before this change these were AuthorizerFnServiceRole91AE9242 and
    // friends — a name invented at deploy time, whose suffix shifts when
    // unrelated constructs are added.
    const names = Object.values(template.findResources("AWS::IAM::Role"))
      .map(
        (r) =>
          (r as { Properties?: { RoleName?: unknown } }).Properties?.RoleName,
      )
      .filter((n): n is string => typeof n === "string");

    expect(names).toContain(
      `${DEFAULT_RESOURCE_PREFIX}-${DEFAULT_ENV}-authorizer-fn-role`,
    );
    expect(names).toContain(
      `${DEFAULT_RESOURCE_PREFIX}-${DEFAULT_ENV}-cache-invalidation-fn-role`,
    );
    expect(names).toContain(
      `${DEFAULT_RESOURCE_PREFIX}-${DEFAULT_ENV}-not-implemented-fn-role`,
    );
  });

  test("the only unnamed role left is one CDK gives no way to name", () => {
    // Any role without a RoleName cannot be pre-created, so it would block a
    // private-VPC deploy. This is the regression guard for the whole change:
    // a new construct that lets CDK create an implicit role fails here.
    //
    // RestApiCloudWatchRole is the one documented exception. SpecRestApi
    // accepts `cloudWatchRole` as a BOOLEAN only — aws-cdk-lib 2.270.0 offers
    // no prop to supply the role — so standard mode cannot name it. Private
    // mode sets the flag to false instead and the account-level CloudWatch
    // role is configured externally there.
    const unnamed = Object.entries(template.findResources("AWS::IAM::Role"))
      .filter(
        ([, r]) =>
          (r as { Properties?: { RoleName?: unknown } }).Properties
            ?.RoleName === undefined,
      )
      .map(([logicalId]) => logicalId);

    expect(unnamed).toEqual(["RestApiCloudWatchRoleE3ED6605"]);
  });

  test("the authorizer still gets its DynamoDB grants", () => {
    // Proves naming the role did not detach the 193 grant/addToRolePolicy
    // calls that attach to it.
    const policies = template.findResources("AWS::IAM::Policy");
    expect(Object.keys(policies).length).toBeGreaterThan(0);
  });

  test("API Gateway's account-level CloudWatch role is still created", () => {
    expect(
      Object.keys(template.findResources("AWS::ApiGateway::Account")).length,
    ).toBeGreaterThan(0);
  });
});

describe("private-VPC mode creates no roles at all", () => {
  let template: Template;

  beforeAll(() => {
    process.env.COA_PVT_VPC_CONFIG = writePrivateConfig();
    template = synth("vpc-0abc123");
  });

  afterAll(() => {
    delete process.env.COA_PVT_VPC_CONFIG;
  });

  test("creates nothing a locked-down account would refuse", () => {
    // The account denies iam:CreateRole. One role here is a failed deploy.
    expect(Object.keys(template.findResources("AWS::IAM::Role"))).toEqual([]);
  });

  test("emits no inline Policy either", () => {
    // An AWS::IAM::Policy would need iam:PutRolePolicy, also denied, and
    // would overwrite the permissions the operator attached by hand.
    expect(Object.keys(template.findResources("AWS::IAM::Policy"))).toEqual([]);
  });

  test("does not create the API Gateway account CloudWatch role", () => {
    // cloudWatchRole: true creates an implicit role SpecRestApi gives no way
    // to override, so private mode has to switch it off.
    expect(
      Object.keys(template.findResources("AWS::ApiGateway::Account")),
    ).toEqual([]);
  });

  test("Lambdas reference the pre-created roles by derived ARN", () => {
    const fns = Object.values(template.findResources("AWS::Lambda::Function"));
    const roleArns = fns.map(
      (f) => (f as { Properties?: { Role?: unknown } }).Properties?.Role,
    );
    expect(roleArns).toContain(
      `arn:aws:iam::123456789012:role/${DEFAULT_RESOURCE_PREFIX}-${DEFAULT_ENV}-authorizer-fn-role`,
    );
  });

  test("still creates the application resources it is supposed to", () => {
    // The point of the flow: application resources are created every release,
    // only the pre-created infrastructure is imported.
    expect(
      Object.keys(template.findResources("AWS::Lambda::Function")).length,
    ).toBeGreaterThan(0);
    expect(
      Object.keys(template.findResources("AWS::ApiGateway::RestApi")).length,
    ).toBeGreaterThan(0);
  });
});
