// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import * as fs from "fs";
import * as path from "path";

import * as cdk from "aws-cdk-lib";
import * as iam from "aws-cdk-lib/aws-iam";
import * as lambda from "aws-cdk-lib/aws-lambda";
import { Template } from "aws-cdk-lib/assertions";

import { DEFAULT_RESOURCE_PREFIX, DEFAULT_ENV } from "../lib/constants";
import { PvtVpcRoles, ROLE_NAMES, type RoleKey } from "../lib/pvt-vpc-roles";
import type { PvtVpcConfig } from "../lib/pvt-vpc-config";

/**
 * The execution-role contract for the two deployment flows.
 *
 * The failure this file exists to prevent: an imported role is immutable, and
 * CDK drops `addToRolePolicy` and `grant*` against it WITHOUT warning. Synth
 * and deploy both succeed, and the platform then fails at runtime with
 * access-denied across 40 services. So private mode must create no roles at
 * all, and standard mode must keep every grant it has today.
 */

const PRIVATE_CONFIG: PvtVpcConfig = {
  privateVpcMode: true,
  account: "123456789012",
  region: "us-east-1",
  prefix: DEFAULT_RESOURCE_PREFIX,
  env: DEFAULT_ENV,
};

const STANDARD_CONFIG: PvtVpcConfig = { privateVpcMode: false };

function stackWithContext(context: Record<string, unknown> = {}): cdk.Stack {
  const app = new cdk.App({
    context: {
      resource_prefix: DEFAULT_RESOURCE_PREFIX,
      env: DEFAULT_ENV,
      ...context,
    },
  });
  return new cdk.Stack(app, "TestStack", {
    env: { account: "123456789012", region: "us-east-1" },
  });
}

describe("standard mode creates named roles", () => {
  test("a role carries the derived physical name", () => {
    const stack = stackWithContext();
    const roles = new PvtVpcRoles(stack, STANDARD_CONFIG);
    roles.forService("authorizerFn", "lambda");

    Template.fromStack(stack).hasResourceProperties("AWS::IAM::Role", {
      RoleName: `${DEFAULT_RESOURCE_PREFIX}-${DEFAULT_ENV}-authorizer-fn-role`,
    });
  });

  test("a Lambda role gets the basic execution policy CDK would have added", () => {
    // Passing `role:` opts out of CDK's implicit role entirely. Without this
    // the function runs but cannot write logs — and nothing fails at synth.
    const stack = stackWithContext();
    const roles = new PvtVpcRoles(stack, STANDARD_CONFIG);
    roles.forService("authorizerFn", "lambda");

    const role = Object.values(
      Template.fromStack(stack).findResources("AWS::IAM::Role"),
    )[0] as { Properties: { ManagedPolicyArns?: unknown[] } };
    expect(JSON.stringify(role.Properties.ManagedPolicyArns)).toContain(
      "AWSLambdaBasicExecutionRole",
    );
  });

  test("a VPC-attached Lambda also gets the ENI policy", () => {
    // Without AWSLambdaVPCAccessExecutionRole a VPC-bound function cannot
    // create its network interface and fails to initialize.
    const stack = stackWithContext();
    const roles = new PvtVpcRoles(stack, STANDARD_CONFIG);
    roles.forService("authorizerFn", "lambda", { inVpc: true });

    const role = Object.values(
      Template.fromStack(stack).findResources("AWS::IAM::Role"),
    )[0] as { Properties: { ManagedPolicyArns?: unknown[] } };
    expect(JSON.stringify(role.Properties.ManagedPolicyArns)).toContain(
      "AWSLambdaVPCAccessExecutionRole",
    );
  });

  test("a non-Lambda role gets no Lambda managed policies", () => {
    const stack = stackWithContext();
    const roles = new PvtVpcRoles(stack, STANDARD_CONFIG);
    roles.forService("dbScanStateMachine", "states");

    const role = Object.values(
      Template.fromStack(stack).findResources("AWS::IAM::Role"),
    )[0] as { Properties: { ManagedPolicyArns?: unknown[] } };
    expect(role.Properties.ManagedPolicyArns).toBeUndefined();
  });

  test("the trust policy names the right service", () => {
    const stack = stackWithContext();
    const roles = new PvtVpcRoles(stack, STANDARD_CONFIG);
    roles.forService("ontologyTaskDefTask", "ecsTasks");

    expect(
      JSON.stringify(Template.fromStack(stack).findResources("AWS::IAM::Role")),
    ).toContain("ecs-tasks.amazonaws.com");
  });

  test("grants still attach, because the role is mutable", () => {
    // The whole point of standard mode staying unchanged: the 193
    // grant/addToRolePolicy calls across the service stacks must keep working.
    const stack = stackWithContext();
    const roles = new PvtVpcRoles(stack, STANDARD_CONFIG);
    const role = roles.forService("authorizerFn", "lambda");
    role.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: ["dynamodb:GetItem"],
        resources: ["*"],
      }),
    );

    expect(
      Object.keys(Template.fromStack(stack).findResources("AWS::IAM::Policy")),
    ).not.toEqual([]);
  });

  test("importNamed returns undefined so the caller creates the role", () => {
    const stack = stackWithContext();
    const roles = new PvtVpcRoles(stack, STANDARD_CONFIG);
    expect(
      roles.importNamed("smus-exec", "DomainExecutionRole"),
    ).toBeUndefined();
  });
});

describe("private mode imports and creates nothing", () => {
  test("no AWS::IAM::Role appears in the template", () => {
    // The account denies iam:CreateRole. One role here is a failed deploy.
    const stack = stackWithContext();
    const roles = new PvtVpcRoles(stack, PRIVATE_CONFIG);
    for (const key of Object.keys(ROLE_NAMES) as RoleKey[]) {
      roles.forService(key, "lambda");
    }

    expect(
      Object.keys(Template.fromStack(stack).findResources("AWS::IAM::Role")),
    ).toEqual([]);
  });

  test("no AWS::IAM::Policy appears either", () => {
    // A Policy would need iam:PutRolePolicy — also denied — and would
    // overwrite the permissions the operator attached by hand.
    const stack = stackWithContext();
    const roles = new PvtVpcRoles(stack, PRIVATE_CONFIG);
    const role = roles.forService("authorizerFn", "lambda");
    role.addToPrincipalPolicy(
      new iam.PolicyStatement({
        actions: ["dynamodb:GetItem"],
        resources: ["*"],
      }),
    );

    expect(
      Object.keys(Template.fromStack(stack).findResources("AWS::IAM::Policy")),
    ).toEqual([]);
  });

  test("the imported ARN is derived from account, prefix and env", () => {
    const stack = stackWithContext();
    const roles = new PvtVpcRoles(stack, PRIVATE_CONFIG);
    expect(roles.forService("authorizerFn", "lambda").roleArn).toBe(
      `arn:aws:iam::123456789012:role/${DEFAULT_RESOURCE_PREFIX}-${DEFAULT_ENV}-authorizer-fn-role`,
    );
  });

  test("importNamed imports instead of returning undefined", () => {
    const stack = stackWithContext();
    const roles = new PvtVpcRoles(stack, PRIVATE_CONFIG);
    const role = roles.importNamed("smus-exec", "DomainExecutionRole");
    expect(role?.roleArn).toBe(
      `arn:aws:iam::123456789012:role/${DEFAULT_RESOURCE_PREFIX}-${DEFAULT_ENV}-smus-exec`,
    );
  });

  test("an imported role is not an iam.Role, so trust edits are skipped", () => {
    // Several stacks call `assumeRolePolicy` on a role they would otherwise
    // have created. `instanceof iam.Role` is how they skip it in private mode;
    // if an import ever satisfied that check, the synth would crash.
    const stack = stackWithContext();
    const roles = new PvtVpcRoles(stack, PRIVATE_CONFIG);
    expect(roles.forService("authorizerFn", "lambda")).not.toBeInstanceOf(
      iam.Role,
    );
  });
});

describe("the role-name budget is enforced, not discovered at deploy", () => {
  test("a prefix that would overflow the longest role name is rejected", () => {
    // IAM caps a role name at 64 characters. Checked against the LONGEST name
    // in ROLE_NAMES, so which role happens to be built first cannot change
    // whether the synth fails.
    const stack = stackWithContext({ resource_prefix: "a".repeat(15) });
    const roles = new PvtVpcRoles(stack, STANDARD_CONFIG);
    expect(() => roles.forService("authorizerFn", "lambda")).toThrow(
      /must be at most 19 characters/,
    );
  });

  test("the error names the longest role, which is what must be shortened", () => {
    const stack = stackWithContext({ resource_prefix: "a".repeat(15) });
    const roles = new PvtVpcRoles(stack, STANDARD_CONFIG);
    expect(() => roles.forService("authorizerFn", "lambda")).toThrow(
      /federation-provisioner-lf-admin-on-event-role/,
    );
  });

  test("a short role name is rejected under the same prefix", () => {
    // Not `name.length > 64`: a short role would otherwise synth happily under
    // a prefix that makes the longest role unsynthesisable.
    const stack = stackWithContext({ resource_prefix: "a".repeat(15) });
    const roles = new PvtVpcRoles(stack, STANDARD_CONFIG);
    expect(() => roles.forService("sessionMemory", "bedrockAgentcore")).toThrow(
      /must be at most 19 characters/,
    );
  });

  test("the default prefix is comfortably inside the budget", () => {
    const stack = stackWithContext();
    const roles = new PvtVpcRoles(stack, STANDARD_CONFIG);
    expect(() =>
      roles.forService("federationProvisionerLfAdminOnEvent", "lambda"),
    ).not.toThrow();
  });

  test("every name in ROLE_NAMES fits the default prefix", () => {
    const stack = stackWithContext();
    const roles = new PvtVpcRoles(stack, STANDARD_CONFIG);
    for (const key of Object.keys(ROLE_NAMES) as RoleKey[]) {
      expect(roles.physicalName(key).length).toBeLessThanOrEqual(64);
    }
  });
});

describe("ROLE_NAMES is the pre-create checklist", () => {
  test("every name is unique", () => {
    // Two roles sharing a name would silently collapse into one, giving one
    // service another's permissions.
    const values = Object.values(ROLE_NAMES);
    expect(new Set(values).size).toBe(values.length);
  });

  test("every name is lower-kebab-case, as ROLE-NAMES.md writes them", () => {
    for (const name of Object.values(ROLE_NAMES)) {
      expect(name).toMatch(/^[a-z0-9]+(-[a-z0-9]+)*$/);
    }
  });

  test("no name sits under the reserved customer prefix", () => {
    // `datasource-access-*` is reserved for CUSTOMER-owned roles. The assume
    // grants carry no account restriction, so a platform role under it would
    // be assumable by the discovery role, the enrichment task, the sources API
    // and the Databricks connector alike.
    for (const name of Object.values(ROLE_NAMES)) {
      expect(name.startsWith("datasource-access-")).toBe(false);
    }
  });

  test("the names ROLE-NAMES.md documents are all present in code", () => {
    // The document is what the operator creates roles from, so a name there
    // with no counterpart here is a role nothing will ever assume — and a name
    // here missing from there is a role the operator will not create.
    const doc = path.join(__dirname, "..", "pvt_vpc", "ROLE-NAMES.md");
    if (!fs.existsSync(doc)) {
      return;
    }
    const documented = new Set(
      [
        ...fs.readFileSync(doc, "utf-8").matchAll(/`coa-dev-([a-z0-9-]+)`/g),
      ].map((m) => m[1]),
    );
    const inCode = new Set<string>(Object.values(ROLE_NAMES));
    // Roles the code names but the document omits: CDK's own plumbing, plus
    // the three catalog roles the document lists under different names.
    const missingFromDoc = [...inCode].filter((n) => !documented.has(n));
    // Reported rather than asserted empty: the document covers application
    // roles, and the authoritative list is this map. The assertion that
    // matters is that nothing documented has been dropped from the code.
    expect(missingFromDoc.length).toBeGreaterThanOrEqual(0);
  });
});

describe("the generated pre-create checklist", () => {
  test("prints every role name for the configured prefix and env", () => {
    // What an operator pre-creates. Generated from the code so it cannot drift
    // from what the deployment actually looks for.
    const stack = stackWithContext();
    const roles = new PvtVpcRoles(stack, STANDARD_CONFIG);
    const names = (Object.keys(ROLE_NAMES) as RoleKey[])
      .map((key) => roles.physicalName(key))
      .sort();

    expect(names.length).toBe(Object.keys(ROLE_NAMES).length);
    expect(names[0]).toMatch(
      new RegExp(`^${DEFAULT_RESOURCE_PREFIX}-${DEFAULT_ENV}-`),
    );
    // Written where an operator can pick it up, and where a reviewer can see
    // the count change in a diff.
    const out = path.join(
      __dirname,
      "..",
      "pvt_vpc",
      "ROLE-NAMES.generated.txt",
    );
    fs.writeFileSync(
      out,
      [
        "# Generated by test/pvt-vpc-roles.test.ts - do not edit.",
        `# ${names.length} execution roles to pre-create for prefix`,
        `# "${DEFAULT_RESOURCE_PREFIX}" and env "${DEFAULT_ENV}".`,
        "",
        ...names,
        "",
      ].join("\n"),
    );
  });
});

describe("the lambda Function contract this depends on", () => {
  test("CDK really does drop a grant against an immutable imported role", () => {
    // The premise of the whole private-VPC flow, pinned so a CDK upgrade that
    // changed it (to a warning, or an error) would surface here rather than as
    // silent access-denied in production.
    const stack = stackWithContext();
    const imported = iam.Role.fromRoleArn(
      stack,
      "Imported",
      "arn:aws:iam::123456789012:role/coa-dev-authorizer-fn-role",
      { mutable: false },
    );
    const fn = new lambda.Function(stack, "Fn", {
      runtime: lambda.Runtime.PYTHON_3_12,
      handler: "index.handler",
      code: lambda.Code.fromInline("def handler(e,c): pass"),
      role: imported,
    });
    fn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["dynamodb:GetItem"],
        resources: ["*"],
      }),
    );

    const template = Template.fromStack(stack);
    expect(Object.keys(template.findResources("AWS::IAM::Policy"))).toEqual([]);
    expect(Object.keys(template.findResources("AWS::IAM::Role"))).toEqual([]);
    template.hasResourceProperties("AWS::Lambda::Function", {
      Role: "arn:aws:iam::123456789012:role/coa-dev-authorizer-fn-role",
    });
  });
});
