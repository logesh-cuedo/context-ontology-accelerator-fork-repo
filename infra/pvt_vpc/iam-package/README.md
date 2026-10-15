# IAM to create

**For:** the AWS account owner / security team.

**64 roles, 64 inline policies and 1 customer-managed policy** that the Context
Ontology Accelerator deployment **imports**. It creates none of them — the
pipeline is denied `iam:CreateRole`, so every role must exist, with these exact
names, before the deployment runs.

| Folder | Contents |
|---|---|
| `roles/` | one file per role: trust policy, managed policy ARNs, inline policy |
| `policies/` | the same inline policy on its own, for tooling that wants it separately |
| `managed-policies/` | two customer-managed policies — see below |

## The names are the contract

The deployment does, for every role:

```
Role.fromRoleArn(this, "...", "arn:aws:iam::<account>:role/coa-dev-authorizer-fn-role")
```

It looks up **one literal string**. A role created with a different name is not
found, **the deployment still succeeds**, and that component fails later with
access-denied. Nothing in the template says which, or why.

So: create every role with the `roleName` in its file, unchanged. The same
applies to `coa-dev-smus-exec-policy` in `managed-policies/`.

## Substitute the two placeholders

Every file uses:

| Placeholder | Replace with |
|---|---|
| `${AccountId}` | your 12-digit AWS account ID |
| `${Region}` | the deployment region, e.g. `us-east-1` |

These are **not** CloudFormation syntax — they are literal text to replace
before the policy is applied. A policy applied with `${AccountId}` left in it
will be accepted by IAM and will match nothing.

## File shape

```json
{
  "roleName": "coa-dev-admin-user-lambda-role",
  "trustPolicy":        { ... },              // who may assume it
  "managedPolicyArns":  [ "arn:aws:iam::aws:policy/service-role/..." ],
  "inlinePolicy":       { "Version": "...", "Statement": [ ... ] },
  "statementCount":     1
}
```

Apply each as: create the role with `trustPolicy` as its trust relationship,
attach each `managedPolicyArns` entry, and put `inlinePolicy` on it as an
inline policy. `stack`, `logicalId` and `nameIsExplicit` are provenance only —
they record where in the deployment the role came from and are not applied.

## The two managed policies

| Policy | Attach to |
|---|---|
| `coa-dev-smus-exec-policy` | the `coa-dev-smus-exec` role |
| `coa-dev-cfn-exec-policy` | **no role here** — pass it as `CloudFormationExecutionPolicies` when applying `coa-cdk-bootstrap.yaml` |

`coa-dev-cfn-exec-policy` is the one to get right. That bootstrap parameter
defaults to **`AdministratorAccess`**, which would let CloudFormation create
IAM roles on the deployment's behalf and make this whole arrangement
pointless. The policy allows the 23 services the stacks create resources in,
plus `iam:PassRole` to attach the roles above, and denies role and
security-group creation.

The `Deny` block is not redundant with simply omitting those actions: that
bootstrap parameter takes a **list**, so a broader policy can be attached to
the same role later, and an explicit `Deny` survives it.

## Three roles have an empty inline policy

`coa-dev-not-implemented-fn-role`, `coa-dev-session-memory-role` and
`coa-dev-rest-api-cloud-watch-role` have `"Statement": []`. That is correct,
not a truncated export: they need only their managed policy, or no permissions
at all. Create them anyway — two of the three are imported by name.

## Two roles are not used by the current deployment

`coa-dev-federation-provisioner-lf-admin-on-event-role` and
`coa-dev-rest-api-cloud-watch-role` are reserved and appear in no stack today.
Creating them is harmless; `coa-dev-rest-api-cloud-watch-role` is also the role
to set as the API Gateway account-level CloudWatch role (see below).

## What is NOT here

- **The five CDK bootstrap roles** — `cdk-hnb659fds-*-role-<account>-<region>`,
  plus an asset bucket and a container repository. They come from CDK's own
  bootstrap template, shipped as
  `pvt_vpc/networking/coa-cdk-bootstrap.yaml`, and are created by applying
  that template rather than from this package. Required in every region the
  deployment touches.
- **Security groups and VPC endpoints** — see `pvt_vpc/networking/`.

## One step after the deployment

API Gateway's account-level CloudWatch role is a per-account setting that
CloudFormation cannot manage here:

```bash
aws apigateway update-account \
  --patch-operations op=replace,path=/cloudwatchRoleArn,\
value=arn:aws:iam::<account>:role/coa-dev-rest-api-cloud-watch-role
```

Without it, API Gateway access logging silently does nothing.

## Prefix and environment

Every name begins `coa-dev-`, from `prefix` and `env` in
`pvt_vpc/config.json`. Changing either means regenerating this package — the
names here, in the config and in the networking templates must all agree.
