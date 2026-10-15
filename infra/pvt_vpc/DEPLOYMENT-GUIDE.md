# Deploying into a locked-down private VPC

**For:** whoever runs the deployment, and whoever has to approve what it does
to the account.

This is the second of two deployment flows the same codebase supports.

| Flow | Command | What it creates |
|---|---|---|
| Standard | `cdk deploy --all` | everything, including the VPC, NAT, 22 endpoints, 28 security groups and 69 IAM roles |
| **Private VPC** | `cdk deploy --all -c vpc_id=vpc-…` | **only application resources** — 352 of them, and **zero** IAM roles |

The switch is the `vpc_id` context value. Nothing else changes: no separate
branch, no build flag, no second copy of the code.

---

## Why this flow exists

A locked-down AWS account denies the deploying principal three things:

```
iam:CreateRole               security owns identity
ec2:CreateSecurityGroup      the network team owns the network
ec2:CreateVpcEndpoint        likewise
```

Those are reasonable restrictions, and the standard flow cannot run under
them — it creates 69 roles and 28 security groups.

So in this flow someone with the right permissions creates those resources
**in advance**, and the deployment **imports** them by name. The division is:

```
the account owner creates   identity and network   (steps 1-5)
the deployment creates      the application        (step 7)
```

### The failure mode this design has to defend against

CDK **silently drops** permission grants against an imported role. No warning,
no synth error:

```typescript
const role = iam.Role.fromRoleArn(this, "R", "arn:…:role/coa-dev-authorizer-fn-role");
role.addToPrincipalPolicy(someStatement);   // discarded, no error
```

That is correct behaviour — the operator attached those permissions when they
created the role — but only if they attached **all** of them. If one is
missing:

- the synth succeeds
- the deploy succeeds
- one component fails at runtime with access-denied, and nothing in the
  template says which or why

The same is true of a role whose **name** does not match. This is why steps 4
and 5 are exacting about names and statements, and why they are worth
double-checking before deploying rather than after.

---

## What you need before you start

| | |
|---|---|
| An AWS account | with the VPC, IAM and CloudFormation rights to do steps 1–5 |
| A region | `us-east-1` unless told otherwise — see the AZ constraint in step 1 |
| This repository | the templates and the IAM package live in `infra/pvt_vpc/` |
| The AWS CLI or console | every step works either way |

Steps 1–5 are done **once per account**. Step 7 can be repeated freely.

---

## Step 1 — The VPC, NAT and subnets

**Who:** the account owner / network team.
**Why:** everything else lives inside it, and the deployment never creates one.

**Console:** VPC → *Create VPC* → **VPC and more**

| Field | Value |
|---|---|
| Name tag | `coa-dev-vpc` |
| IPv4 CIDR | `10.0.0.0/16` |
| Availability Zones | **2** → *Customize* → **us-east-1b**, **us-east-1c** |
| Public subnets | 2 |
| Private subnets | 2 |
| NAT gateways | In 1 AZ |
| **VPC endpoints** | **None** — step 4 creates them |
| DNS hostnames / resolution | both enabled |

### ⚠️ The availability zones cannot be changed later

Two services constrain the choice and they support **different** zone sets:

- Bedrock AgentCore runs only in certain AZs
- the OpenSearch Serverless control-plane endpoint is offered in a different
  subset

The subnets must sit in the **intersection**. In `us-east-1` that is
**us-east-1b and us-east-1c**. Subnets anywhere else fail when the deployment
creates the AgentCore runtimes or reaches the OpenSearch endpoint — late,
after most of the deployment has succeeded.

AZ *names* are per-account aliases for physical zones, so `us-east-1b` in your
account is not the same hardware as in another. Confirm before using any other
region.

### Record these five values

| Value | Where to find it |
|---|---|
| VPC id | VPC → Your VPCs |
| VPC CIDR | same page |
| 2 private subnet ids | VPC → Subnets, filtered by your VPC |
| their 2 AZ names | same row |
| their 2 route table ids | click each subnet → **Route table** tab |

The subnet, AZ and route-table lists are **positional** — subnet 1 must be in
AZ 1 and use route table 1. The build checks the lengths match and the zones
differ, but it cannot check the order.

---

## Step 2 — CDK staging

**Template:** `pvt_vpc/networking/coa-cdk-staging.yaml` (3 resources)
**Why:** the deployment uploads Lambda zips and container images here, and
CloudFormation reads them from here.

**Console:** CloudFormation → *Create stack* → **Upload a template file** →
`coa-cdk-staging.yaml` → stack name `coa-cdk-staging` → *Submit*.

### Why not `cdk bootstrap`

`cdk bootstrap` is the normal way to create these. It also creates **five IAM
roles** that the deployment then assumes:

```
cdk-hnb659fds-deploy-role-…            cdk-hnb659fds-file-publishing-role-…
cdk-hnb659fds-cfn-exec-role-…          cdk-hnb659fds-image-publishing-role-…
cdk-hnb659fds-lookup-role-…
```

An account that denies `iam:CreateRole` cannot run it — so the deployment
could never start, regardless of what the application itself creates. And
because CDK names those roles at deploy time, there is no name to pre-create
and import.

This template creates only the bucket and the repository, which need **no IAM
permission at all**. Naming them in `config.json` switches the app to
`CliCredentialsStackSynthesizer`, which publishes assets with the caller's own
credentials and assumes no role.

**Do not also run `cdk bootstrap`.** It is unnecessary once `staging` is set
and would create the five roles this avoids.

### Outputs to keep

| Output | Goes to |
|---|---|
| `StagingBucketName` | `staging.bucketName` |
| `ContainerRepositoryName` | `staging.repositoryName` |

---

## Step 3 — Security groups

**Template:** `pvt_vpc/networking/coa-networking-security-groups.yaml`
(21 resources)
**Why:** the deployment is denied `ec2:CreateSecurityGroup`, so all nine groups
and the twelve rules between them are created here and imported by id.

**Apply before step 4** — the endpoints template takes one of its outputs.

| Parameter | Value |
|---|---|
| `Prefix` | `coa` |
| `EnvName` | `dev` |
| `VpcId` | from step 1 |
| `VpcCidr` | from step 1, e.g. `10.0.0.0/16` |

### The nine groups

| Name | Purpose |
|---|---|
| `coa-dev-lambda-sg` | Lambda functions |
| `coa-dev-ecs-sg` | Fargate tasks (ontology engine, VKG) |
| `coa-dev-neptune-sg` | graph database — inbound 8182 from Lambda/ECS/AgentCore only, no egress |
| `coa-dev-aoss-vpce-sg` | OpenSearch endpoint — inbound 443 from Lambda/ECS/AgentCore only |
| `coa-dev-connector-sg` | database connectors (self-referencing, required by Glue/Athena) |
| `coa-dev-discovery-ocsp-sg` | outbound 80 for Snowflake certificate checks |
| `coa-dev-agent-core-sg` | Context Manager runtime — reaches AOSS and Neptune directly |
| `coa-dev-mcp-sg` | MCP server runtime — HTTPS only |
| `coa-dev-vpce-sg` | shared by all 20 interface endpoints (step 4's parameter) |

One shared group serves all 20 interface endpoints rather than 20 identical
copies: every one accepts 443 from inside the VPC and nothing else. What
restricts the service reached is the endpoint, not the group.

### Outputs to keep — all nine

Eight go into `config.json`:

| Output | Goes to |
|---|---|
| `LambdaSecurityGroupId` | `securityGroups.lambda` |
| `EcsSecurityGroupId` | `securityGroups.ecs` |
| `NeptuneSecurityGroupId` | `securityGroups.neptune` |
| `AossSecurityGroupId` | `securityGroups.aossVpce` |
| `ConnectorSecurityGroupId` | `securityGroups.connector` |
| `DiscoveryOcspSecurityGroupId` | `securityGroups.discoveryOcsp` |
| `AgentCoreSecurityGroupId` | `securityGroups.agentCore` |
| `McpSecurityGroupId` | `securityGroups.mcp` |

The ninth, **`InterfaceEndpointSecurityGroupId`**, does **not** go into the
config — it is a parameter of step 4.

---

## Step 4 — VPC endpoints

**Template:** `pvt_vpc/networking/coa-networking-vpc-endpoints.yaml`
(22 resources)
**Why:** the deployment is denied `ec2:CreateVpcEndpoint`. There is no NAT path
for AWS API traffic in this design — all 22 endpoints keep it inside the VPC.

Takes about five minutes.

| Parameter | Value |
|---|---|
| `VpcId` | from step 1 |
| `PrivateSubnetIds` | the **two private** subnets from step 1 |
| `PrivateRouteTableIds` | their two route table ids |
| `InterfaceEndpointSecurityGroupId` | from step 3's outputs |

Passed **by value**, not as a CloudFormation export, so the two stacks stay
independent — neither blocks changing or deleting the other.

### Output to keep — one of twenty-two

| Output | Goes to |
|---|---|
| `AossDataVpcEndpointId` | `vpcEndpoints.aossData` |

The other 21 endpoints must **exist** — nothing works without them — but their
ids are not configured anywhere: private DNS makes them transparent, so the
AWS SDK resolves the normal service hostname and no code references an id.
Asking for 21 values that nothing reads would be 21 chances for a silent typo.

`AossDataVpcEndpointId` is the exception because the OpenSearch collection's
network policy names that endpoint explicitly. Without it the collection is
either unreachable or left publicly reachable, so the deployment fails rather
than shipping either.

### No internet access

All AWS access goes through these endpoints, so the workloads never route to
the internet. The platform can reach AWS services and any database on your own
network, but **not** the public internet. If a data source needs outbound
internet, that requires a NAT gateway or a proxy — a deliberate decision, not
an oversight.

---

## Step 5 — IAM: 64 roles, 64 policies, 1 managed policy

**Package:** `pvt_vpc/iam-package/` — see its own `README.md`.
**Why:** the deployment is denied `iam:CreateRole`, so every role it needs must
already exist, with the exact name it imports.

```
roles/              64 files   trust policy + managed policy ARNs + inline policy
policies/           64 files   the same inline policies, standalone
managed-policies/    1 policy  coa-dev-smus-exec-policy, attached to coa-dev-smus-exec
```

### Two things that go wrong here

**1. Names are an exact-match contract.** The code does:

```typescript
Role.fromRoleArn(this, "…", "arn:aws:iam::<account>:role/coa-dev-authorizer-fn-role")
```

One literal string. A role created with any other name is not found, the
deployment **still succeeds**, and that component fails later with
access-denied.

**2. The placeholders are literal text.** Every file contains `${AccountId}`
and `${Region}`. These are **not** CloudFormation syntax — replace them before
applying. IAM will happily accept a policy with `${AccountId}` left in it, and
it will match nothing.

Three roles have `"Statement": []` — `coa-dev-not-implemented-fn-role`,
`coa-dev-session-memory-role`, `coa-dev-rest-api-cloud-watch-role`. That is
correct, not a truncated export.

---

## Step 6 — Fill in the config

**File:** `pvt_vpc/config.json`. This is the only connection between what was
created in steps 1–5 and what the deployment imports.

```jsonc
{
  "account": "",                      // your 12-digit account id
  "region": "us-east-1",
  "prefix": "coa",                    // must match the templates' Prefix
  "env": "dev",                       // must match the templates' EnvName

  "vpc": {                            // all four from step 1, POSITIONAL
    "cidr": "",
    "availabilityZones": ["", ""],
    "privateSubnetIds": ["", ""],
    "privateRouteTableIds": ["", ""]
  },

  "securityGroups": {                 // the 8 ids from step 3
    "lambda": "", "ecs": "", "neptune": "", "aossVpce": "",
    "connector": "", "discoveryOcsp": "", "agentCore": "", "mcp": ""
  },

  "vpcEndpoints": { "aossData": "" }, // from step 4

  "staging": {                        // from step 2
    "bucketName": "",
    "repositoryName": ""
  }
}
```

**The VPC id is not in this file.** It goes on the command line, and its
presence is what selects this flow.

Every field above is required when `-c vpc_id=` is given. A blank one fails at
synth with a named list — before anything is deployed, which is the cheapest
place to find out.

`prefix` and `env` must match what you passed to the templates in steps 2–4:
every resource name and every IAM role name is built from them.

### Optional: resources you already run

`existing.neptune` points the deployment at a graph database you already have,
instead of creating one. Leave all three fields blank — the shipped state — and
it creates its own cluster exactly as before.

```jsonc
"existing": {
  "neptune": {
    "clusterEndpoint": "",     // host only, no scheme, no port
    "port": "8182",
    "clusterResourceId": ""    // "cluster-ABCD1234…", NOT the cluster name
  }
}
```

`clusterResourceId` is the expensive mistake. Every IAM data-access policy is
`arn:aws:neptune-db:…:{clusterResourceId}/*`, so the cluster **name** there
produces a valid-looking ARN that matches nothing and denies every request — at
runtime, not at deploy. Find the real value with:

```bash
aws neptune describe-db-clusters --db-cluster-identifier <name> \
  --query 'DBClusters[0].DbClusterResourceId'
```

This block is read in **both** flows: an existing Neptune is possible whether
or not the VPC was also pre-created.

---

## Step 7 — Deploy

```bash
cd infra
npx cdk deploy --all -c vpc_id=vpc-xxxxxxxx
```

15 stacks, 352 resources. Expect 30–60 minutes on a first run, most of it
Neptune, OpenSearch and the AgentCore runtimes.

### What it creates, and what it never touches

| | |
|---|---|
| `AWS::IAM::Role` | **0** |
| `AWS::IAM::Policy` | **0** |
| `AWS::IAM::ManagedPolicy` | **0** |
| `AWS::EC2::SecurityGroup` | **0** |
| `AWS::EC2::VPCEndpoint` | **0** |
| `AWS::EC2::VPC` | **0** |

It does create 55 **resource** policies, which are a different thing from
identity policies:

| Type | Count |
|---|---:|
| `Lambda::Permission` | 17 |
| `SQS::QueuePolicy` | 14 |
| `S3::BucketPolicy` | 11 |
| `OpenSearchServerless::AccessPolicy` | 6 |
| `Logs::ResourcePolicy` | 3 |
| `OpenSearchServerless::SecurityPolicy` | 2 |
| `DataZone::PolicyGrant` | 2 |

```
identity policy   "this ROLE may do X"      needs iam:*        none created
resource policy   "X may use this QUEUE"    needs sqs:* etc.   55 created
```

Every one targets a resource the deployment itself creates.

### Permissions the deploying principal does need

Create/update/delete on: Lambda, S3, SQS, DynamoDB, SSM, CloudWatch, Logs,
ECS, ECR, Events, StepFunctions, Scheduler, ApiGateway, Cognito, CloudFront,
WAFv2, Neptune, OpenSearchServerless, DataZone, Athena, Bedrock,
BedrockAgentCore, ServiceDiscovery, CloudFormation — plus `iam:PassRole` to
attach the pre-created roles, and `logs:PutResourcePolicy`.

`logs:PutResourcePolicy` is worth calling out: EventBridge cannot deliver to a
log group without a resource policy on it, and this flow writes that policy as
plain CloudFormation. The alternative CDK uses by default is a Lambda-backed
custom resource with a CDK-named IAM role — which is exactly what this account
denies.

---

## Step 8 — After the deployment

### Set the API Gateway account-level CloudWatch role

```bash
aws apigateway update-account \
  --patch-operations op=replace,path=/cloudwatchRoleArn,\
value=arn:aws:iam::<account>:role/coa-dev-rest-api-cloud-watch-role
```

An account-wide setting, not a per-stack one, and CDK's `SpecRestApi` exposes
it only as a boolean — so it cannot accept a pre-created role and must be set
once by hand. Without it, API Gateway access logging silently does nothing.
The role is already in the IAM package.

### Verify the vector store is not publicly reachable

```bash
aws opensearchserverless get-security-policy --name coa-dev-network --type network
```

Expect `SourceVPCEs` to list your endpoint and **no `AllowFromPublic`**. The
templates are correct, but this confirms the deployed state — and an
`AllowFromPublic` rule is **additive**, so it would open a second door beside
the endpoint rather than replacing it.

---

## Tearing down

```bash
# 1. Empty the 11 buckets FIRST
#    coa-dev-{metric-logs,metric-osi,sources-logs,sources-data,storage-logs,
#             athena-results,athena-spill,ontology-artifacts,ui-logs,
#             ui-assets,cf-logs}-*
npx cdk destroy --all -c vpc_id=vpc-xxxxxxxx
```

The standard flow installs an auto-delete helper that empties them for you.
This flow does not: that helper is a Lambda needing its own IAM role.
CloudFormation cannot delete a non-empty bucket, so the stack delete fails
part-way if you skip this.

Then remove, in any order: the IAM package, the three CloudFormation stacks,
and the VPC. The staging bucket and repository are `Retain`, so deleting their
stack leaves them behind — delete them by hand if you want them gone.

---

## If something fails

| Symptom | Cause |
|---|---|
| `AccessDenied` on `iam:CreateRole` | the deployment is creating a role it should import — a bug, report it |
| `AccessDenied` on `ec2:CreateSecurityGroup` | same, for security groups |
| **Deploy succeeds, a feature fails with access-denied** | a role name in step 5 does not match, or a statement is missing from its policy |
| `AccessDenied` on `logs:PutResourcePolicy` | the deploying principal needs this; see step 7 |
| Synth fails listing config fields | step 6 is incomplete — the message names each one |
| Fails before any stack starts | `staging` missing or misnamed; or `cdk bootstrap` was run and conflicts |
| AgentCore or OpenSearch fails late | the subnets are in the wrong AZs — step 1 |

The third row is the one to watch. It does **not** fail the deployment, because
an imported role that does not exist is only discovered when something tries to
use it. If you see access-denied at runtime, compare the role name in the error
against `pvt_vpc/iam-package/roles/`.

---

## Rehearsing this before a client runs it

`pvt_vpc/testing/` has a deny policy and a runbook for reproducing these
restrictions in an account you control. An admin account cannot test this
flow — every `iam:CreateRole` succeeds, so the deployment passes whether or not
the code is right, and the first real failure lands in the client's account.
