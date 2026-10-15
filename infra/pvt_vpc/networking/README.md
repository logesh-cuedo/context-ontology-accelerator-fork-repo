# Networking to create

**For:** the AWS account owner / network team.

**Two** CloudFormation templates that add the **22 VPC endpoints and 9 security
groups** the Context Ontology Accelerator needs into a VPC you already have,
split by resource type — one file of security groups, one of endpoints. The
deployment imports these; it creates no networking itself.

| Template | Creates | Apply |
|---|---|---|
| `coa-cdk-bootstrap.yaml` | CDK's own bootstrap — 5 IAM roles, asset bucket, container repository (14 resources) | any time, **in every region** |
| `coa-networking-security-groups.yaml` | **all** security groups — 8 application + 1 shared for the endpoints — and the 12 rules (21 resources) | **first of the two** |
| `coa-networking-vpc-endpoints.yaml` | 22 endpoints, no security groups (22 resources) | second |

`coa-cdk-bootstrap.yaml` is CDK's own template, unmodified — `cdk bootstrap` is
only a CLI wrapper that deploys it. The deploying principal cannot run that
command in an account denying `iam:CreateRole`, but **you** can apply the
template, and all five role names are fully determined
(`cdk-hnb659fds-<x>-role-<account>-<region>`), which is what makes
pre-creating them possible.

Two things about it:

- **`CloudFormationExecutionPolicies`** — left empty, this attaches
  `AdministratorAccess` to the role CloudFormation assumes, which hands the
  deployment full admin and makes the `iam:CreateRole` denial meaningless.
  Pass a scoped policy ARN.
- **Apply it in every region the deployment touches.** The `*-edge-waf` stack
  always goes to `us-east-1` (a CLOUDFRONT-scope WAF WebACL can only exist
  there), so a deployment targeting another region needs both.

The split is by resource type: **every security group is in the first file, every
endpoint in the second.**

Apply the security groups first, then pass that stack's
`InterfaceEndpointSecurityGroupId` output as a **parameter** of the endpoints
template. It is passed by value rather than exported, so the two stacks stay
independent — neither blocks changing or deleting the other.

The VPC, its private subnets and their route tables are **not** created here —
they are stage 1, done before this. This template takes their ids as
parameters.

## Apply

**Console:** CloudFormation → Create stack → Upload template file → security
groups first → fill the parameters → Create. Then the endpoints template,
pasting the `InterfaceEndpointSecurityGroupId` from the first stack's Outputs.

**CLI:**

```bash
# CDK bootstrap - any time, and once per region the deployment touches
aws cloudformation deploy \
  --stack-name CDKToolkit \
  --template-file coa-cdk-bootstrap.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides CloudFormationExecutionPolicies=<scoped-policy-arn>

# 1 of 2 - all security groups
aws cloudformation deploy \
  --stack-name coa-networking-security-groups \
  --template-file coa-networking-security-groups.yaml \
  --parameter-overrides VpcId=vpc-0abc123 VpcCidr=10.0.0.0/16

# Take the shared endpoint group id from its Outputs
SG=$(aws cloudformation describe-stacks \
       --stack-name coa-networking-security-groups \
       --query "Stacks[0].Outputs[?OutputKey=='InterfaceEndpointSecurityGroupId'].OutputValue" \
       --output text)

# 2 of 2 - VPC endpoints. No VpcCidr: the only resources that needed it were
# the endpoint security groups, which now live in template 1 of 2.
aws cloudformation deploy \
  --stack-name coa-networking-vpc-endpoints \
  --template-file coa-networking-vpc-endpoints.yaml \
  --parameter-overrides \
      VpcId=vpc-0abc123 \
      PrivateSubnetIds=subnet-0a,subnet-0b \
      PrivateRouteTableIds=rtb-0a,rtb-0b \
      InterfaceEndpointSecurityGroupId=$SG
```

### If the VPC already has an S3 gateway endpoint

The VPC console wizard creates one when "VPC endpoints: S3 Gateway" is
selected, and AWS refuses a **second** gateway endpoint for the same service
on the same route table — this stack would fail. Either delete the existing
one, or keep it and pass:

```bash
      CreateS3Endpoint=false
```

Nothing reads this endpoint's id: a gateway endpoint is a route-table entry,
not something the deployment addresses, so an existing one works identically.
`CreateDynamoDbEndpoint` does the same for DynamoDB. Check first with:

```bash
aws ec2 describe-vpc-endpoints \
  --filters Name=vpc-id,Values=<vpc-id> Name=vpc-endpoint-type,Values=Gateway \
  --query 'VpcEndpoints[].{Id:VpcEndpointId,Service:ServiceName}' --output table
```

## These match what the deployment would create itself

The settings in these templates are not a reduced subset. They were diffed
against the CloudFormation the deployment generates in the flow where it builds
its own networking, and the property sets are identical:

```
endpoint properties only in CDK      : none
endpoint properties only in template : none
tag keys match                       : yes
```

VPC endpoints have no size, capacity, retention or version setting to choose —
the eight properties present are all there are. `Prefix`, `EnvName` and
`ProjectTag` exist only to reproduce the four tags (`Name`, `Project`,
`Environment`, `Component`) the deployment applies stack-wide, so cost
allocation and resource search behave the same either way.

`Prefix` (`coa`) and `EnvName` (`dev`) default to the values the deployment
expects. If you change either, the same values must be used in
`pvt_vpc/config.json` — every resource name and every IAM role name is built
from them.

## Pick the Availability Zones carefully

The subnets you pass in decide this, so it is settled in stage 1 — but it is
the one choice that cannot be changed later without rebuilding.

Two AWS services constrain it, and they support **different** sets of zones:

- Bedrock AgentCore runs only in certain AZs
- The OpenSearch Serverless control-plane endpoint is offered in a different
  subset

The subnets must sit in the **intersection**. In `us-east-1` that is
**us-east-1b and us-east-1c**. Subnets elsewhere will fail the deployment when
it creates the AgentCore runtimes or reaches the OpenSearch endpoint.

AZ *names* are per-account aliases for physical zones, so `us-east-1b` in your
account is not the same hardware as `us-east-1b` in another. Confirm with us
before applying in any other region.

## No NAT gateway, no internet gateway

All AWS access goes through these 22 endpoints, so the workloads never route to
the internet.

One consequence worth knowing: the platform can reach AWS services and any
database you connect it to over your own network, but it cannot reach the
public internet. If a data source requires outbound internet access, tell us —
it needs a NAT gateway or a proxy, which is a deliberate decision rather than
an oversight.

## What these templates create

43 resources in total.

**`coa-networking-security-groups.yaml`** — 21:

| Resource | Count |
|---|---:|
| Application security groups | 8 |
| Shared security group for all interface endpoints | 1 |
| Security group rules (ingress + egress) | 12 |

**`coa-networking-vpc-endpoints.yaml`** — 22:

| Resource | Count |
|---|---:|
| Gateway VPC endpoints (S3, DynamoDB — no hourly cost) | 2 |
| Interface VPC endpoints | 20 |

One shared group serves all 20 interface endpoints rather than 20 identical
copies: every interface endpoint accepts 443 from inside the VPC and nothing
else. What restricts the service reached is the endpoint itself; the group only
decides who may open the connection. To give one endpoint tighter rules, add a
second group to template 1, output it, and pass it to that endpoint.

The 8 application security groups are:

| Name | Purpose |
|---|---|
| `…-lambda-sg` | Lambda functions |
| `…-ecs-sg` | Fargate tasks (ontology engine, VKG) |
| `…-neptune-sg` | Graph database — inbound 8182 from Lambda/ECS/AgentCore only, no outbound |
| `…-aoss-vpce-sg` | OpenSearch endpoint — inbound 443 from Lambda/ECS/AgentCore only |
| `…-connector-sg` | Database connectors (self-referencing, required by Glue/Athena) |
| `…-discovery-ocsp-sg` | Outbound 80 for Snowflake certificate checks |
| `…-agent-core-sg` | Context Manager AgentCore runtime — reaches AOSS and Neptune directly |
| `…-mcp-sg` | MCP server AgentCore runtime — HTTPS only |

The last two have no equivalent in the standard flow's networking: there each
runtime's stack creates its own group. A locked-down account denies that, so
they are created here and imported by id.

## Outbound database ports

The Lambda and connector security groups allow outbound to the standard
database ports — 5432, 3306, 1433, 5439, 1521 — so the platform can scan source
databases. If you only use some of these, the unused rules can be removed. Tell
us which, and we will regenerate.

## What to send back

Each stack's **Outputs** tab gives the values the deployment needs. They map to
`pvt_vpc/config.json` like this.

From **`coa-networking-security-groups`**:

| Output | Goes into config.json |
|---|---|
| `LambdaSecurityGroupId` | `securityGroups.lambda` |
| `EcsSecurityGroupId` | `securityGroups.ecs` |
| `NeptuneSecurityGroupId` | `securityGroups.neptune` |
| `AossSecurityGroupId` | `securityGroups.aossVpce` |
| `ConnectorSecurityGroupId` | `securityGroups.connector` |
| `DiscoveryOcspSecurityGroupId` | `securityGroups.discoveryOcsp` |
| `AgentCoreSecurityGroupId` | `securityGroups.agentCore` |
| `McpSecurityGroupId` | `securityGroups.mcp` |

That stack has a **ninth** output, `InterfaceEndpointSecurityGroupId`, which
does **not** go into the config — it is a parameter of the endpoints template.

The bootstrap stack needs **nothing** copied into the config: the deployment
derives its bucket, repository and role names from the account, region and
qualifier.

From **`coa-networking-vpc-endpoints`** — one value, out of 22 endpoints:

| Output | Goes into config.json |
|---|---|
| `AossDataVpcEndpointId` | `vpcEndpoints.aossData` |

Plus, from stage 1 rather than this stack's outputs:

| Value | Goes into config.json |
|---|---|
| VPC CIDR | `vpc.cidr` |
| The two AZ names | `vpc.availabilityZones` |
| The two subnet ids | `vpc.privateSubnetIds` |
| Their route table ids | `vpc.privateRouteTableIds` |

`vpc.availabilityZones`, `privateSubnetIds` and `privateRouteTableIds` are
**positional** — subnet 1 must be in zone 1 and use route table 1. The build
checks the lengths match and the zones differ, but it cannot check the order,
so send them in a consistent order.

The **VPC id is not in config.json**. It goes on the deploy command:
`cdk deploy -c vpc_id=vpc-0abc123`.

`AossDataVpcEndpointId` is **required**. The OpenSearch collection's network
policy names that endpoint explicitly; without it the collection is either
unreachable or left publicly reachable, and the deployment now fails rather
than shipping either.

Also send your 12-digit account ID, which the IAM package needs and which goes
into `config.json` as `account`.

## The 21 endpoint ids you do not need to send

Only `AossDataVpcEndpointId` goes into the config. The other 21 endpoints must
**exist** — nothing works without them — but their ids are not configured
anywhere: private DNS makes them transparent, so the AWS SDK resolves the
normal service hostname to the endpoint and no code references an id. Asking
for 21 values that nothing reads would just be 21 chances for a silent typo.
