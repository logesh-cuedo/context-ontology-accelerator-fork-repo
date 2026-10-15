// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import * as cdk from "aws-cdk-lib";
import * as events from "aws-cdk-lib/aws-events";
import * as logs from "aws-cdk-lib/aws-logs";

/**
 * Let an EventBridge rule deliver to a log group using plain CloudFormation.
 *
 * ## Why this exists
 *
 * EventBridge cannot write to a log group without a RESOURCE policy on that
 * log group, and `targets.CloudWatchLogGroup` creates one the expensive way:
 * an `AwsCustomResource` that calls `logs:putResourcePolicy` from a Lambda.
 * That Lambda needs an execution role, so one rule costs
 *
 *   - 1 × AWS::Lambda::Function
 *   - 1 × AWS::IAM::Role      (CDK-generated name, so un-pre-createable)
 *   - 1 × AWS::IAM::Policy    (one per rule)
 *
 * A locked-down account denies `iam:CreateRole`, and because CDK derives that
 * role's name at deploy time there is no name an operator could pre-create and
 * the stack could import. Three rules across two stacks produced the last five
 * resources blocking a private-VPC deployment.
 *
 * `AWS::Logs::ResourcePolicy` is a real CloudFormation resource type, so none
 * of that machinery is needed: CloudFormation writes the policy directly.
 *
 * ## How the custom resource is suppressed
 *
 * `CloudWatchLogGroup.bind()` begins with
 *
 *     this.logGroup.node.tryFindChild(resourcePolicyId) || new LogGroupResourcePolicy(...)
 *
 * where `resourcePolicyId` is `EventsLogGroupPolicy${Names.nodeUniqueId(rule.node)}`.
 * Occupying that child id with the native resource means CDK finds a child,
 * skips its own, and still wires the rule's target normally.
 *
 * This leans on a CDK internal, so {@link EVENTS_LOG_GROUP_POLICY_ID_PREFIX}
 * and the behaviour are pinned by `test/events-log-group-policy.test.ts`. If a
 * CDK upgrade changes the id, that test fails and the IAM resources reappear —
 * loudly, rather than silently at deploy time in a locked-down account.
 *
 * Identical in both deployment flows: there is no role in either, so nothing
 * has to be pre-created and no behaviour differs between them.
 */

/** The child-id prefix `CloudWatchLogGroup.bind()` probes for. */
export const EVENTS_LOG_GROUP_POLICY_ID_PREFIX = "EventsLogGroupPolicy";

/**
 * Add the resource policy an EventBridge rule needs to write to `logGroup`,
 * as `AWS::Logs::ResourcePolicy` rather than a custom resource.
 *
 * Call this BEFORE attaching the target — `addTarget` is what probes for the
 * child. A rule whose target is passed in its own props has already bound by
 * the time the constructor returns, so such a rule must be rewritten to use
 * `addTarget` for this to take effect.
 *
 * Safe to call once per (rule, log group) pair. Two rules sharing one log
 * group each get their own policy, because the id is derived from the rule.
 *
 * @param rule       the rule that will deliver to `logGroup`
 * @param logGroup   the destination log group
 * @param policyName physical name of the resource policy; must be unique in
 *                   the account and region
 */
export function grantEventsDeliveryToLogGroup(
  rule: events.Rule,
  logGroup: logs.ILogGroup,
  policyName: string,
): logs.CfnResourcePolicy {
  const childId = `${EVENTS_LOG_GROUP_POLICY_ID_PREFIX}${cdk.Names.nodeUniqueId(
    rule.node,
  )}`;

  const existing = logGroup.node.tryFindChild(childId);
  if (existing) {
    return existing as logs.CfnResourcePolicy;
  }

  return new logs.CfnResourcePolicy(logGroup, childId, {
    policyName,
    // `logs:CreateLogStream` and `logs:PutLogEvents` are exactly what CDK's
    // own custom resource grants — keep them in step.
    policyDocument: JSON.stringify({
      Version: "2012-10-17",
      Statement: [
        {
          Effect: "Allow",
          Principal: { Service: "events.amazonaws.com" },
          Action: ["logs:CreateLogStream", "logs:PutLogEvents"],
          // The log group itself and its streams: PutLogEvents targets a
          // stream, so the `:*` suffix is required.
          Resource: `${logGroup.logGroupArn}:*`,
        },
      ],
    }),
  });
}
