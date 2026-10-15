# Rehearsing the locked-down deployment in your own account

**For:** whoever tests the private-VPC flow before a client runs it.

An admin account **cannot** test this scenario. Admin rights mean every
`iam:CreateRole` succeeds, so the deployment passes whether or not the code is
correct — and the first real failure happens in the client's account, where it
is expensive to debug.

The fix is to keep the admin user for setup and deploy as a **second principal
that is denied exactly what the client's account denies**.

## The idea

```
you (admin)            -> plays the CLIENT: creates the VPC, roles, networking
coa-deploy-test (role) -> plays the PIPELINE: denied iam:CreateRole etc.
```

Everything in the "client" column is legitimately done with elevated rights —
the client's own security team has them. Only the deployment itself must run
restricted.

## 1. Create the restricted deploy role

`deny-locked-down.json` here is the deny policy: 27 actions across IAM and EC2,
matching what a locked-down account refuses. Attach it alongside
`AdministratorAccess` — **an explicit Deny always wins in IAM**, so the result
is "admin, except these 27 actions", which is exactly the shape you want to
test and is far simpler than enumerating every allow.

```bash
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

# A role you can assume, that the denies apply to
aws iam create-role --role-name coa-deploy-test \
  --assume-role-policy-document "{
    \"Version\":\"2012-10-17\",
    \"Statement\":[{\"Effect\":\"Allow\",
      \"Principal\":{\"AWS\":\"arn:aws:iam::${ACCOUNT}:root\"},
      \"Action\":\"sts:AssumeRole\"}]}"

aws iam attach-role-policy --role-name coa-deploy-test \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

aws iam put-role-policy --role-name coa-deploy-test \
  --policy-name deny-locked-down \
  --policy-document file://deny-locked-down.json
```

## 2. As admin, do everything the client would do

In this order:

1. **VPC, NAT, subnets, route tables.** Subnets in **us-east-1b and
   us-east-1c** — the one choice that cannot be changed later.
2. **`pvt_vpc/networking/coa-cdk-bootstrap.yaml`** as stack `CDKToolkit` —
   CDK's own bootstrap: five roles, an asset bucket and a container
   repository. Pass a scoped `CloudFormationExecutionPolicies`, or the role
   CloudFormation assumes gets AdministratorAccess and the rehearsal proves
   nothing. Apply it in `us-east-1` too if you deploy elsewhere.
3. **`pvt_vpc/networking/coa-networking-security-groups.yaml`**, then
   **`coa-networking-vpc-endpoints.yaml`** (the second takes
   `InterfaceEndpointSecurityGroupId` from the first).
4. **The IAM package** — 64 roles, 64 inline policies, 1 managed policy. See
   `pvt_vpc/iam-package/README.md`. Substitute `${AccountId}` and `${Region}`.

## 3. Fill in the config

`pvt_vpc/config.json`: `account`, the 8 security group ids and
`vpcEndpoints.aossData` from the stack outputs, the 4 `vpc.*` values from
step 2.1. The bootstrap stack contributes nothing to the config.

## 4. Deploy as the restricted role

```bash
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
CREDS=$(aws sts assume-role \
  --role-arn arn:aws:iam::${ACCOUNT}:role/coa-deploy-test \
  --role-session-name coa-test --query Credentials --output json)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c 'import json,sys;print(json.load(sys.stdin)["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c 'import json,sys;print(json.load(sys.stdin)["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c 'import json,sys;print(json.load(sys.stdin)["SessionToken"])')

# Prove the denies are in force BEFORE deploying. This must fail.
aws iam create-role --role-name coa-deny-probe \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
# expected: AccessDenied. If it SUCCEEDS, the session is not restricted and
# the whole test is void.

cd infra
npx cdk deploy --all -c vpc_id=vpc-xxxxxxxx
```

That probe matters. Assuming a role in your own account is easy to get wrong —
a stale profile or an unexported variable leaves you as admin, the deploy
passes, and the test has proven nothing.

## 5. What a pass looks like

- all 15 stacks reach `CREATE_COMPLETE`
- no `AccessDenied` anywhere in the events
- the vector store is not public:

  ```bash
  aws opensearchserverless get-security-policy \
    --name coa-dev-network --type network
  ```

  `SourceVPCEs` present, **no** `AllowFromPublic`.

## 6. Reading a failure

| Failure | Meaning |
|---|---|
| `AccessDenied` on `iam:CreateRole` | the app still creates a role somewhere — a real bug, the thing this test exists to catch |
| `AccessDenied` on `ec2:CreateSecurityGroup` | same, for security groups |
| `Role ... does not exist` / access-denied at runtime | a role name in the IAM package does not match what the code imports |
| `AccessDenied` on `logs:PutResourcePolicy` | the client's policy is stricter than this deny list; tell the developers |
| Fails before any stack | the `CDKToolkit` stack is missing in this region |

The third row is the dangerous one: it does **not** fail the deployment. It
fails later, at runtime, in whichever component holds the mis-named role.

## Tearing down

```bash
# still as the restricted role
npx cdk destroy --all -c vpc_id=vpc-xxxxxxxx
```

**Empty the 11 S3 buckets first** (`coa-dev-*`): the private flow creates no
auto-delete helper, because that helper needs its own IAM role. Stack deletion
fails on a non-empty bucket.

Then, as admin, delete the IAM package, the networking stacks, the
`CDKToolkit` stack (its bucket and repository are retained — empty and delete
them by hand), and the VPC.

## What this does not cover

The deny list is a faithful model of `iam:CreateRole` and
`ec2:CreateSecurityGroup` being refused. A real client may also restrict
things this rehearsal allows — KMS, specific regions, or a permissions
boundary. If they publish their actual policy, use that here instead of this
file.
