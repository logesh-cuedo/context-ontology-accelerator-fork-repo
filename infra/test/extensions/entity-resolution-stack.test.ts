// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

/** cuedo-ext: entity-resolution extension stack. */
import * as cdk from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Match, Template } from "aws-cdk-lib/assertions";
import { DEFAULT_ENV, DEFAULT_RESOURCE_PREFIX } from "../../lib/constants";
import { EntityResolutionStack } from "../../lib/stacks/extensions/entity-resolution-stack";

function createStack(context: Record<string, unknown> = {}): Template {
  const app = new cdk.App({
    context: {
      resource_prefix: DEFAULT_RESOURCE_PREFIX,
      env: DEFAULT_ENV,
      "aws:cdk:bundling-stacks": [],
      ...context,
    },
  });
  const env = { account: "123456789012", region: "us-east-1" };
  const dep = new cdk.Stack(app, "Dep", { env });
  const vpc = new ec2.Vpc(dep, "Vpc", { maxAzs: 2 });
  const stack = new EntityResolutionStack(app, "TestEntityExt", {
    env,
    vpc,
    lambdaSecurityGroup: new ec2.SecurityGroup(dep, "LambdaSG", { vpc }),
  });
  return Template.fromStack(stack);
}

function accessPolicies(template: Template): string[] {
  return Object.values(
    template.findResources("AWS::OpenSearchServerless::AccessPolicy"),
  ).map((p) => JSON.stringify(p));
}

describe("EntityResolutionStack", () => {
  let template: Template;
  beforeAll(() => {
    template = createStack();
  });

  it("deploys the index Lambda with a 15-minute budget", () => {
    template.hasResourceProperties("AWS::Lambda::Function", {
      Handler: "coa_entity.lambda_handler.handler",
      Timeout: 900,
      Environment: {
        Variables: Match.objectLike({ SSM_PREFIX: Match.anyValue() }),
      },
    });
  });

  it("builds on ontology.published and sweeps daily", () => {
    template.hasResourceProperties("AWS::Events::Rule", {
      EventPattern: Match.objectLike({ "detail-type": ["ontology.published"] }),
    });
    template.hasResourceProperties("AWS::Events::Rule", {
      ScheduleExpression: "rate(1 day)",
    });
  });

  it("reads only the entity config and serve's model config from SSM", () => {
    const statements = JSON.stringify(
      template.findResources("AWS::IAM::Policy"),
    );
    expect(statements).toContain("/entities/*");
    expect(statements).toContain("/config");
  });

  it("limits AOSS writes to entity indexes, with new policy names", () => {
    const policies = accessPolicies(template);
    expect(policies).toHaveLength(1);
    expect(policies[0]).toContain("entity-ext-lambda");
    expect(policies[0]).toContain("-entities-*");
    expect(policies[0]).not.toContain("entity-index-writer");
  });

  it("adds operator write access only when aoss_writer_principal_arns is set", () => {
    const policies = accessPolicies(
      createStack({
        aoss_writer_principal_arns: "arn:aws:iam::123456789012:user/ops",
      }),
    );
    expect(policies).toHaveLength(2);
    expect(policies.join()).toContain("arn:aws:iam::123456789012:user/ops");
  });
});
