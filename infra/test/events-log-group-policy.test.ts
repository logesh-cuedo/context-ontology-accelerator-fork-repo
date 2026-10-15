// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import * as cdk from "aws-cdk-lib";
import * as events from "aws-cdk-lib/aws-events";
import * as targets from "aws-cdk-lib/aws-events-targets";
import * as logs from "aws-cdk-lib/aws-logs";
import { Template } from "aws-cdk-lib/assertions";

import {
  EVENTS_LOG_GROUP_POLICY_ID_PREFIX,
  grantEventsDeliveryToLogGroup,
} from "../lib/utils/events-log-group-policy";

/**
 * `targets.CloudWatchLogGroup` grants EventBridge delivery with an
 * `AwsCustomResource`, which drags in a Lambda and an IAM role whose name CDK
 * derives at deploy time. A locked-down account denies `iam:CreateRole`, and an
 * un-named role cannot be pre-created and imported, so those were the last
 * resources blocking a private-VPC deployment.
 *
 * The helper writes `AWS::Logs::ResourcePolicy` instead and relies on a CDK
 * internal to suppress the custom resource:
 *
 *     this.logGroup.node.tryFindChild(resourcePolicyId) || new LogGroupResourcePolicy(...)
 *
 * These tests pin that behaviour. If a CDK upgrade renames the probed child id
 * or stops probing, the IAM resources come back — and this file fails rather
 * than a deployment failing in a customer's account.
 */

const ENV = { account: "123456789012", region: "us-east-1" };

function fixture() {
  const stack = new cdk.Stack(new cdk.App(), "S", { env: ENV });
  const logGroup = new logs.LogGroup(stack, "LG", {
    logGroupName: "/aws/events/coa-dev-thing",
  });
  const rule = new events.Rule(stack, "R", {
    eventPattern: { source: ["aws.ecs"] },
  });
  return { stack, logGroup, rule };
}

describe("the IAM resources the helper exists to avoid", () => {
  test("CDK's own target creates a role, a policy and a Lambda", () => {
    // The baseline. If this ever stops being true the helper is obsolete.
    const { stack, logGroup, rule } = fixture();
    rule.addTarget(new targets.CloudWatchLogGroup(logGroup));
    const template = Template.fromStack(stack);
    template.resourceCountIs("AWS::IAM::Role", 1);
    template.resourceCountIs("AWS::IAM::Policy", 1);
    template.resourceCountIs("AWS::Lambda::Function", 1);
    template.resourceCountIs("AWS::Logs::ResourcePolicy", 0);
  });

  test("with the helper there is no role, no policy and no Lambda", () => {
    const { stack, logGroup, rule } = fixture();
    grantEventsDeliveryToLogGroup(rule, logGroup, "coa-dev-thing-events");
    rule.addTarget(new targets.CloudWatchLogGroup(logGroup));
    const template = Template.fromStack(stack);
    template.resourceCountIs("AWS::IAM::Role", 0);
    template.resourceCountIs("AWS::IAM::Policy", 0);
    template.resourceCountIs("AWS::Lambda::Function", 0);
    template.resourceCountIs("AWS::Logs::ResourcePolicy", 1);
  });
});

describe("the rule still works", () => {
  test("the target is attached", () => {
    // The whole point: the monitoring is kept, only the delivery mechanism for
    // the resource policy changes.
    const { stack, logGroup, rule } = fixture();
    grantEventsDeliveryToLogGroup(rule, logGroup, "coa-dev-thing-events");
    rule.addTarget(new targets.CloudWatchLogGroup(logGroup));
    const rules = Template.fromStack(stack).findResources("AWS::Events::Rule");
    const only = Object.values(rules)[0] as {
      Properties: { Targets?: unknown[] };
    };
    expect(only.Properties.Targets).toHaveLength(1);
  });

  test("the policy names the events principal and the log streams", () => {
    const { stack, logGroup, rule } = fixture();
    grantEventsDeliveryToLogGroup(rule, logGroup, "coa-dev-thing-events");
    rule.addTarget(new targets.CloudWatchLogGroup(logGroup));

    const found = Template.fromStack(stack).findResources(
      "AWS::Logs::ResourcePolicy",
    );
    const props = (
      Object.values(found)[0] as {
        Properties: { PolicyName: string; PolicyDocument: unknown };
      }
    ).Properties;
    expect(props.PolicyName).toBe("coa-dev-thing-events");

    const doc = JSON.stringify(props.PolicyDocument);
    expect(doc).toContain("events.amazonaws.com");
    expect(doc).toContain("logs:PutLogEvents");
    expect(doc).toContain("logs:CreateLogStream");
    // `:*` matters — PutLogEvents targets a stream inside the group, not the
    // group itself, so a policy scoped to the bare ARN grants nothing.
    expect(doc).toContain(":*");
  });
});

describe("two rules sharing one log group", () => {
  test("each gets its own policy, because the id comes from the rule", () => {
    // sources-stack has exactly this shape: one audit log group, a write rule
    // and a batch-delete rule. A shared id would collide at synth.
    const stack = new cdk.Stack(new cdk.App(), "S", { env: ENV });
    const logGroup = new logs.LogGroup(stack, "LG", {
      logGroupName: "/aws/events/coa-dev-audit",
    });
    const first = new events.Rule(stack, "First", {
      eventPattern: { source: ["aws.ssm"] },
    });
    const second = new events.Rule(stack, "Second", {
      eventPattern: { source: ["aws.ssm"] },
    });
    const target = new targets.CloudWatchLogGroup(logGroup);

    grantEventsDeliveryToLogGroup(first, logGroup, "coa-dev-audit-write");
    first.addTarget(target);
    grantEventsDeliveryToLogGroup(second, logGroup, "coa-dev-audit-delete");
    second.addTarget(target);

    const template = Template.fromStack(stack);
    template.resourceCountIs("AWS::Logs::ResourcePolicy", 2);
    template.resourceCountIs("AWS::IAM::Role", 0);
  });

  test("calling twice for the same rule is a no-op", () => {
    const { stack, logGroup, rule } = fixture();
    const a = grantEventsDeliveryToLogGroup(rule, logGroup, "coa-dev-x");
    const b = grantEventsDeliveryToLogGroup(rule, logGroup, "coa-dev-x");
    expect(b).toBe(a);
    Template.fromStack(stack).resourceCountIs("AWS::Logs::ResourcePolicy", 1);
  });
});

describe("the CDK internal this depends on", () => {
  test("the child id prefix is the one CloudWatchLogGroup probes for", () => {
    // Mirrors `EventsLogGroupPolicy${Names.nodeUniqueId(rule.node)}` in
    // aws-events-targets/lib/log-group.js. Changed upstream => the helper
    // silently stops suppressing the custom resource.
    const { logGroup, rule } = fixture();
    grantEventsDeliveryToLogGroup(rule, logGroup, "coa-dev-thing-events");
    const expectedId = `${EVENTS_LOG_GROUP_POLICY_ID_PREFIX}${cdk.Names.nodeUniqueId(
      rule.node,
    )}`;
    expect(logGroup.node.tryFindChild(expectedId)).toBeDefined();
  });

  test("the helper must be called before addTarget", () => {
    // Calling it after means CDK has already created its own; the count then
    // shows both. Documented so the ordering is not treated as cosmetic.
    const { stack, logGroup, rule } = fixture();
    rule.addTarget(new targets.CloudWatchLogGroup(logGroup));
    grantEventsDeliveryToLogGroup(rule, logGroup, "coa-dev-too-late");
    const template = Template.fromStack(stack);
    template.resourceCountIs("AWS::IAM::Role", 1);
  });
});
