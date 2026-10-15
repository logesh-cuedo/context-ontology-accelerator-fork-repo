// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import * as path from "path";
import * as cdk from "aws-cdk-lib";
import * as iam from "aws-cdk-lib/aws-iam";
import * as lambda from "aws-cdk-lib/aws-lambda";
import { Provider } from "aws-cdk-lib/custom-resources";
import { Construct } from "constructs";

import { PvtVpcRoles } from "../pvt-vpc-roles";

export interface LakeFormationAdminProps {
  /** SSM parameter name holding the IAM role ARN to register as an LF data-lake admin. */
  readonly roleArnSsmParameterName: string;
  /**
   * The role ARN the SSM parameter resolves to.
   *
   * Passed as a custom-resource property purely so a change to the *value*
   * produces a property diff. With only the parameter *name* as a property, a
   * deployment that repointed the parameter at a different role left the custom
   * resource untouched (no diff → no Update → the new role never registered);
   * the handler still reads the authoritative value from SSM at runtime.
   */
  readonly roleArn: string;
}

/**
 * Non-destructively registers an IAM role as a Lake Formation data-lake admin.
 *
 * Reads the role ARN from SSM, fetches the current settings
 * (`GetDataLakeSettings`), appends the role to `DataLakeAdmins` if absent, and
 * writes the full settings back (`PutDataLakeSettings`) — preserving existing
 * admins and other settings. Removes the role on stack deletion (best-effort).
 *
 * NOTE: `PutDataLakeSettings` is authorized by the IAM permission granted below,
 * NOT by the caller's own membership in `DataLakeAdmins`. This works unattended on
 * any account, greenfield or with admins already present, and needs no
 * out-of-band bootstrap. An earlier version of this comment claimed the caller
 * had to be a data-lake admin itself; that was verified false by direct test (a
 * non-admin role with only the two `*DataLakeSettings` permissions modified the
 * admin list on an account with four existing admins). An `AccessDeniedException`
 * here means the IAM action is denied — look for an SCP or permission boundary.
 */
export class LakeFormationAdmin extends Construct {
  /**
   * Execution role of the onEvent Lambda — the principal that calls
   * `PutDataLakeSettings`. It needs the IAM action (granted below), not
   * data-lake admin membership.
   */
  public readonly adminLambdaRole: iam.IRole;

  constructor(scope: Construct, id: string, props: LakeFormationAdminProps) {
    super(scope, id);

    // Standard mode creates these roles with explicit names; private-VPC mode
    // imports the pre-created ones. See lib/pvt-vpc-roles.ts.
    const roles = new PvtVpcRoles(this);

    const onEvent = new lambda.Function(this, "OnEvent", {
      role: roles.forService("lakeformationAdminOnEvent", "lambda"),
      runtime: lambda.Runtime.PYTHON_3_12,
      handler: "index.handler",
      timeout: cdk.Duration.minutes(2),
      code: lambda.Code.fromAsset(
        path.join(__dirname, "../lambdas/lakeformation-admin"),
      ),
    });
    this.adminLambdaRole = onEvent.role!;

    // LF settings APIs do not support resource-level scoping.
    onEvent.addToRolePolicy(
      new iam.PolicyStatement({
        actions: [
          "lakeformation:GetDataLakeSettings",
          "lakeformation:PutDataLakeSettings",
        ],
        resources: ["*"],
      }),
    );
    onEvent.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["ssm:GetParameter"],
        resources: [
          cdk.Stack.of(this).formatArn({
            service: "ssm",
            resource: "parameter",
            resourceName: props.roleArnSsmParameterName.replace(/^\//, ""),
          }),
        ],
      }),
    );

    const provider = new Provider(this, "Provider", {
      onEventHandler: onEvent,
      // The framework Lambda needs its own role; Provider creates one
      // CloudFormation names at deploy time otherwise.
      frameworkOnEventRole: roles.forService(
        "lakeformationAdminFramework",
        "lambda",
      ),
    });
    new cdk.CustomResource(this, "Resource", {
      serviceToken: provider.serviceToken,
      properties: {
        RoleArnSsmParameterName: props.roleArnSsmParameterName,
        // Value-carrying property so repointing the parameter triggers an
        // Update — see LakeFormationAdminProps.roleArn. The handler reads the
        // authoritative ARN from SSM; this is only a change detector.
        RoleArn: props.roleArn,
      },
    });
  }
}
