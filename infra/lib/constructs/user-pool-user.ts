// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import * as cdk from "aws-cdk-lib";
import * as cognito from "aws-cdk-lib/aws-cognito";
import * as cr from "aws-cdk-lib/custom-resources";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as lambdaNodejs from "aws-cdk-lib/aws-lambda-nodejs";
import * as path from "path";
import { Construct } from "constructs";

import { PvtVpcRoles } from "../pvt-vpc-roles";
import { createHash } from "node:crypto";
import { SCLConstruct } from "./scl-construct";
import { InitialCognitoUserAttributes } from "../types";

/**
 * Properties for {@link UserPoolUser}.
 *
 * Creates an initial admin user in a Cognito User Pool via a custom resource.
 * Cognito sends a temporary password to the user's email — no Secrets Manager.
 */
export interface UserPoolUserProps {
  /** The Cognito User Pool to create the admin user in. */
  readonly userPool: cognito.UserPool;
  /** Initial user details (username, email, group). */
  readonly userDetails: InitialCognitoUserAttributes;
}

/**
 * CDK construct that provisions an initial admin user in a Cognito User Pool.
 *
 * Creates a Lambda-backed custom resource that:
 * - Creates the user in Cognito with a temporary password (emailed to user)
 * - Creates an admin group and assigns the user to it
 *
 * The user must change their password on first login.
 * No Secrets Manager secret is created — credentials are delivered via email.
 */
export class UserPoolUser extends SCLConstruct {
  constructor(scope: Construct, id: string, props: UserPoolUserProps) {
    super(scope, id);

    // Standard mode creates these roles with explicit names; private-VPC mode
    // imports the pre-created ones. See lib/pvt-vpc-roles.ts.
    const roles = new PvtVpcRoles(this);

    const fn = new lambdaNodejs.NodejsFunction(this, "Lambda", {
      functionName: this.prefixed("admin-user-cr"),
      role: roles.forService("adminUserLambda", "lambda"),
      entry: path.join(__dirname, "../lambdas/admin-user-handler.ts"),
      handler: "handler",
      runtime: lambda.Runtime.NODEJS_22_X,
      timeout: cdk.Duration.minutes(1),
    });

    props.userPool.grant(
      fn,
      "cognito-idp:AdminCreateUser",
      "cognito-idp:AdminDeleteUser",
      "cognito-idp:AdminAddUserToGroup",
      "cognito-idp:CreateGroup",
      "cognito-idp:DeleteGroup",
    );
    const provider = new cr.Provider(this, "Provider", {
      // The framework Lambda needs its own role; cr.Provider creates one
      // CloudFormation names at deploy time otherwise.
      frameworkOnEventRole: roles.forService(
        "adminUserProviderFramework",
        "lambda",
      ),
      onEventHandler: fn,
    });

    const detailsHash = createHash("sha256")
      .update(
        `${props.userDetails.username}:${props.userDetails.email}:${props.userDetails.group}`,
      )
      .digest("hex");

    new cdk.CustomResource(this, "Resource", {
      serviceToken: provider.serviceToken,
      properties: {
        UserPoolId: props.userPool.userPoolId,
        Username: props.userDetails.username,
        Email: props.userDetails.email,
        Group: props.userDetails.group,
        ForceUpdate: detailsHash,
      },
    });
  }
}
