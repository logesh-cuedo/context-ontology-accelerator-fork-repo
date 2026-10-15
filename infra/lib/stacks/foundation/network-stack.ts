// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import * as cdk from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as servicediscovery from "aws-cdk-lib/aws-servicediscovery";
import * as ssm from "aws-cdk-lib/aws-ssm";
import { Construct } from "constructs";

import { SCLStack } from "../../constructs";
import { resolveContext } from "../../context";
import { loadPvtVpcConfig, type PvtVpcConfig } from "../../pvt-vpc-config";
import {
  JdbcConnectivity,
  type PeeringConfig,
  type TransitGatewayConfig,
  type PrivateLinkConfig,
} from "../../constructs/jdbc-connectivity";

/**
 * Foundation stack: VPC, subnets, security groups, VPC endpoints, and
 * network plumbing for the SemanticContext platform.
 *
 * Supports importing an existing VPC by setting the `vpc_id` CDK context
 * key.  When omitted, a new VPC is created.
 *
 * Context keys (in addition to SCLStack defaults):
 *   - `vpc_id` - optional; if provided, looks up an existing VPC instead
 *     of creating one.
 *
 * Cross-network JDBC connectivity (created-VPC only; any combination):
 *   - VPC peering: `jdbc_peer_vpc_id`, `jdbc_peer_cidrs` (comma-separated),
 *     `jdbc_peer_owner_id` (cross-account), `jdbc_peer_region` (cross-region).
 *   - Transit Gateway: `jdbc_tgw_id`, `jdbc_tgw_cidrs` (comma-separated).
 *   - PrivateLink: `jdbc_privatelink_service`, `jdbc_privatelink_port`,
 *     `jdbc_privatelink_private_dns` ("true"/"false").
 */

export interface NetworkStackProps extends cdk.StackProps {
  /**
   * AgentCore-supported AZ **names** for the deploying account, resolved
   * at synth time by ``resolveAgentCoreAzNames`` in the CDK app
   * entrypoint. When provided, the VPC is pinned to exactly these AZs so
   * AgentCore Runtime lands only on supported physical zones. When
   * omitted (e.g. unit-test synth, or an imported VPC), the VPC falls
   * back to CDK's default ``maxAzs: 2``.
   */
  readonly agentCoreAzNames?: string[];
}

export class NetworkStack extends SCLStack {
  /** The platform VPC shared by all SemanticContext workloads. */
  public readonly vpc: ec2.IVpc;

  // The six security groups are typed as the INTERFACE, not the concrete
  // class, because a private-VPC deployment imports them instead of creating
  // them (see `importSecurityGroups` below). Consumers only ever read the id
  // or pass them as a peer, so the interface is sufficient.

  /** Security group for the Neptune graph-database cluster (port 8182). */
  public readonly neptuneSecurityGroup: ec2.ISecurityGroup;

  /** Security group for ECS Fargate tasks. */
  public readonly ecsSecurityGroup: ec2.ISecurityGroup;

  /** Security group for Lambda functions. */
  public readonly lambdaSecurityGroup: ec2.ISecurityGroup;

  /** Port-80 egress used only by direct Snowflake discovery for OCSP. */
  public readonly discoveryOcspSecurityGroup: ec2.ISecurityGroup;

  /** Security group for the AOSS VPC endpoint (port 443). */
  public readonly aossSecurityGroup: ec2.ISecurityGroup;
  /** EC2 Interface VPC Endpoint ID for AOSS (NextGen *.on.aws private DNS). */
  public readonly aossVpcEndpointId: string;

  /** Shared Cloud Map private DNS namespace for service discovery. */
  public readonly serviceNamespace: servicediscovery.PrivateDnsNamespace;

  /** Security group for Glue Connections to reach source databases. */
  public readonly connectorSecurityGroup: ec2.ISecurityGroup;

  // The two AgentCore runtime groups are created in their own stacks in the
  // standard flow, where each stack owns the group it attaches. A private-VPC
  // deployment cannot create either, so they are imported HERE — alongside the
  // other six — and passed down, which keeps every security group import in
  // one place.

  /**
   * Security group for the Context Manager AgentCore runtime (serve stack).
   * `undefined` in the standard flow, where ServeStack creates its own.
   */
  public readonly agentCoreSecurityGroup?: ec2.ISecurityGroup;

  /**
   * Security group for the MCP server AgentCore runtime (mcp stack).
   * `undefined` in the standard flow, where McpStack creates its own.
   */
  public readonly mcpSecurityGroup?: ec2.ISecurityGroup;

  constructor(scope: Construct, id: string, props?: NetworkStackProps) {
    super(scope, id, props);
    this.addComponentTag("foundation");

    // ── VPC (create or import) ───────────────────────────────────────
    const existingVpcId = this.node.tryGetContext("vpc_id") as
      | string
      | undefined;

    if (existingVpcId) {
      // Imported from the CONFIG, not via `Vpc.fromLookup`.
      //
      // `fromLookup` calls EC2 at synth time, and without credentials it does
      // not fail — it returns DUMMY values (`vpc-12345`, subnets `p-12345`,
      // zones `dummy1a`) and the synth succeeds. A CI synth, or any developer
      // without credentials for the target account, would therefore produce a
      // template full of subnet ids that do not exist, which only fails at
      // deploy time with a confusing error about the wrong VPC.
      //
      // It also DISCOVERS which subnets are private, by reading AWS tags. In a
      // pre-created VPC owned by a network team those tags may not follow
      // CDK's convention, so the lookup can select the wrong subnets or none.
      //
      // The config names the subnets, their zones and their route tables
      // explicitly, so the synth needs no credentials and places resources in
      // exactly the subnets the operator nominated. `validate()` has already
      // proven all four fields are present and positionally consistent.
      const network = loadPvtVpcConfig(this).vpc!;
      this.vpc = ec2.Vpc.fromVpcAttributes(this, "ImportedVpc", {
        vpcId: existingVpcId,
        vpcCidrBlock: network.cidr!,
        availabilityZones: network.availabilityZones!,
        privateSubnetIds: network.privateSubnetIds!,
        privateSubnetRouteTableIds: network.privateRouteTableIds!,
      });
    } else {
      // Pin VPC AZs to AgentCore-supported physical zones. AZ *names*
      // (us-east-1a/b/…) map to different physical AZ *IDs* per account,
      // so a fixed ``maxAzs: 2`` lands on supported zones in one account
      // and unsupported ones in another (our 9923 testing account failed
      // with "subnets in unsupported availability zones"). The app
      // entrypoint resolves the supported names for the deploying account
      // via ``resolveAgentCoreAzNames`` and passes them in here. When not
      // provided (unit synth), fall back to the default 2-AZ spread.
      const azNames = props?.agentCoreAzNames;
      this.vpc = new ec2.Vpc(this, "Vpc", {
        vpcName: this.prefixed("vpc"),
        ...(azNames && azNames.length > 0
          ? { availabilityZones: azNames }
          : { maxAzs: 2 }),
        natGateways: 1,
        subnetConfiguration: [
          {
            name: "Public",
            subnetType: ec2.SubnetType.PUBLIC,
            cidrMask: 24,
          },
          {
            name: "Private",
            subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
            cidrMask: 24,
          },
        ],
      });
    }

    // ── VPC Endpoints ────────────────────────────────────────────────
    // Only created for new VPCs. Imported VPCs are expected to have
    // their own endpoints managed externally.
    if (!existingVpcId) {
      const createdVpc = this.vpc as ec2.Vpc;

      // Gateway endpoints (free - avoid NAT charges for S3/DDB traffic)
      createdVpc.addGatewayEndpoint("S3Endpoint", {
        service: ec2.GatewayVpcEndpointAwsService.S3,
      });
      createdVpc.addGatewayEndpoint("DynamoDbEndpoint", {
        service: ec2.GatewayVpcEndpointAwsService.DYNAMODB,
      });

      // Interface endpoints
      createdVpc.addInterfaceEndpoint("BedrockRuntimeEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.BEDROCK_RUNTIME,
        privateDnsEnabled: true,
      });
      createdVpc.addInterfaceEndpoint("BedrockAgentCoreEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.BEDROCK_AGENTCORE,
        privateDnsEnabled: true,
      });
      createdVpc.addInterfaceEndpoint("CloudWatchLogsEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.CLOUDWATCH_LOGS,
        privateDnsEnabled: true,
      });
      createdVpc.addInterfaceEndpoint("EcrApiEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.ECR,
        privateDnsEnabled: true,
      });
      createdVpc.addInterfaceEndpoint("EcrDkrEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.ECR_DOCKER,
        privateDnsEnabled: true,
      });
      createdVpc.addInterfaceEndpoint("SsmEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.SSM,
        privateDnsEnabled: true,
      });
      createdVpc.addInterfaceEndpoint("SecretsManagerEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.SECRETS_MANAGER,
        privateDnsEnabled: true,
      });
      const aossEndpoint = createdVpc.addInterfaceEndpoint("AossEndpoint", {
        service: new ec2.InterfaceVpcEndpointService(
          `com.amazonaws.${cdk.Stack.of(this).region}.aoss-data`,
        ),
        privateDnsEnabled: true,
      });
      this.aossVpcEndpointId = aossEndpoint.vpcEndpointId;

      // Additional interface endpoints: keep AWS API traffic private so
      // egress can be scoped away from the public internet. These cover the
      // services the ECS tasks and Lambdas call that previously required NAT.
      const region = cdk.Stack.of(this).region;
      createdVpc.addInterfaceEndpoint("StsEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.STS,
        privateDnsEnabled: true,
      });
      createdVpc.addInterfaceEndpoint("EventBridgeEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.EVENTBRIDGE,
        privateDnsEnabled: true,
      });
      createdVpc.addInterfaceEndpoint("SqsEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.SQS,
        privateDnsEnabled: true,
      });
      createdVpc.addInterfaceEndpoint("StepFunctionsEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.STEP_FUNCTIONS,
        privateDnsEnabled: true,
      });
      createdVpc.addInterfaceEndpoint("AthenaEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.ATHENA,
        privateDnsEnabled: true,
      });
      createdVpc.addInterfaceEndpoint("GlueEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.GLUE,
        privateDnsEnabled: true,
      });
      createdVpc.addInterfaceEndpoint("LambdaEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.LAMBDA,
        privateDnsEnabled: true,
      });
      createdVpc.addInterfaceEndpoint("EcsEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.ECS,
        privateDnsEnabled: true,
      });
      createdVpc.addInterfaceEndpoint("DataZoneEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.DATAZONE,
        privateDnsEnabled: true,
      });
      // Neptune Analytics (neptune-graph) — control + data plane.
      createdVpc.addInterfaceEndpoint("NeptuneGraphEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.NEPTUNE_ANALYTICS,
        privateDnsEnabled: true,
      });
      createdVpc.addInterfaceEndpoint("NeptuneGraphDataEndpoint", {
        service: ec2.InterfaceVpcEndpointAwsService.NEPTUNE_ANALYTICS_DATA,
        privateDnsEnabled: true,
      });
      // OpenSearch Serverless control plane (create/delete collection, policies).
      // No CDK constant exists; the data-plane endpoint above is separate.
      createdVpc.addInterfaceEndpoint("AossControlPlaneEndpoint", {
        service: new ec2.InterfaceVpcEndpointService(
          `com.amazonaws.${region}.aoss`,
        ),
        privateDnsEnabled: true,
      });
    }

    // ── Security Groups ──────────────────────────────────────────────
    //
    // PRIVATE-VPC MODE: the six groups and all their rules were created
    // externally by the networking package, because a locked-down account
    // denies the pipeline `ec2:CreateSecurityGroup`. Import them and return
    // before the creation block below.
    //
    // This branch is load-bearing. Without it, importing a VPC still created
    // six NEW groups inside it — leaving twelve in the account, with the app
    // silently using its own and ignoring the ones the network team made.
    const pvtVpc = loadPvtVpcConfig(this);
    if (pvtVpc.privateVpcMode) {
      const imported = this.importSecurityGroups(pvtVpc);
      this.neptuneSecurityGroup = imported.neptune;
      this.ecsSecurityGroup = imported.ecs;
      this.lambdaSecurityGroup = imported.lambda;
      this.aossSecurityGroup = imported.aoss;
      this.connectorSecurityGroup = imported.connector;
      this.discoveryOcspSecurityGroup = imported.discoveryOcsp;
      this.agentCoreSecurityGroup = imported.agentCore;
      this.mcpSecurityGroup = imported.mcp;

      // The AOSS DATA-PLANE endpoint id, which StorageStack names explicitly
      // in the OpenSearch Serverless network policy's `SourceVPCEs`.
      //
      // This is the one endpoint id the synth genuinely needs. Before this
      // assignment existed, `aossVpcEndpointId` was set ONLY inside the
      // create-the-VPC branch below, so importing a VPC left it undefined and
      // the network policy went out as `"SourceVPCEs": [undefined]`. In dev
      // the separate `AllowFromPublic: true` rule masked that — the vector
      // store stayed reachable, but publicly. In tst/demo/prod there is no
      // mask and nothing could reach the collection at all.
      //
      // `validate()` has already proven the value is present in private mode.
      this.aossVpcEndpointId = pvtVpc.vpcEndpoints!.aossData!;

      // The Cloud Map namespace is an APPLICATION resource, not pre-created
      // infrastructure — nothing in a locked-down account forbids
      // servicediscovery:CreatePrivateDnsNamespace. It is created in both
      // flows, and only the security groups above differ.
      this.serviceNamespace = this.createServiceNamespace();
      this.emitNetworkOutputs();
      return;
    }

    // Neptune - allow inbound 8182 from the ECS + Lambda SGs only (not the
    // whole VPC CIDR). Neptune is a database; it never initiates connections,
    // so outbound stays disabled. Ingress rules are added below, after the
    // ECS and Lambda SGs are constructed.
    this.neptuneSecurityGroup = new ec2.SecurityGroup(this, "NeptuneSG", {
      vpc: this.vpc,
      securityGroupName: this.prefixed("neptune-sg"),
      // Generic description: GroupDescription is immutable in CloudFormation,
      // so keep it rule-agnostic to avoid future SG replacements. Actual rules
      // are defined below and in the surrounding comments.
      description: "Neptune cluster security group",
      allowAllOutbound: false, // Neptune is a database; it doesn't initiate connections
    });

    // ECS - egress restricted to least privilege. Fargate tasks pull private
    // ECR images (via the ECR api/dkr interface endpoints + S3 gateway
    // endpoint) and call AWS service APIs on 443. 443 egress is intentionally
    // left open to 0.0.0.0/0 rather than scoped to the VPC CIDR: the
    // interface endpoints above cover the AWS APIs privately, but gateway
    // endpoints (S3/DynamoDB) route to AWS public IP ranges via prefix lists,
    // and some SDK calls may still fall back to public regional endpoints.
    // Fully scoping egress (443 -> VPC CIDR + S3/DDB prefix lists) is a planned
    // follow-up pending connectivity validation. All non-HTTPS, non-Neptune
    // outbound is denied.
    this.ecsSecurityGroup = new ec2.SecurityGroup(this, "EcsSG", {
      vpc: this.vpc,
      securityGroupName: this.prefixed("ecs-sg"),
      // Generic description (immutable in CFN — keep rule-agnostic).
      description: "ECS Fargate tasks security group",
      allowAllOutbound: false,
    });
    this.ecsSecurityGroup.addEgressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(443),
      "HTTPS to AWS APIs (interface endpoints + S3/DDB gateway prefix lists)",
    );
    this.ecsSecurityGroup.addEgressRule(
      this.neptuneSecurityGroup,
      ec2.Port.tcp(8182),
      "Neptune Gremlin/SPARQL",
    );

    // Internet-bound connector traffic can be narrowed to fixed NAT/proxy or
    // source ranges. The same peers must govern Snowflake OCSP from both the
    // managed connector and the direct-discovery Lambda so the two execution
    // paths cannot drift.
    const connectorEgressCidrs = this.ctxList("connector_egress_cidrs");
    const connectorEgressPeers: ec2.IPeer[] = connectorEgressCidrs.length
      ? connectorEgressCidrs.map((cidr) => ec2.Peer.ipv4(cidr))
      : [ec2.Peer.anyIpv4()];
    const egressScope = connectorEgressCidrs.length
      ? connectorEgressCidrs.join(",")
      : "anywhere";
    const addConfiguredOcspEgress = (
      securityGroup: ec2.ISecurityGroup,
      workload: string,
    ): void => {
      if (this.ctxString("connector_ocsp_egress") === "false") return;
      for (const peer of connectorEgressPeers) {
        securityGroup.addEgressRule(
          peer,
          ec2.Port.tcp(80),
          `Snowflake OCSP for ${workload} to ${egressScope}`,
        );
      }
    };

    // Lambda - egress restricted to least privilege. Same rationale as
    // the ECS SG: 443 for AWS service APIs, 8182 for Neptune clients
    // (metric-service, etc.). No broad outbound.
    this.lambdaSecurityGroup = new ec2.SecurityGroup(this, "LambdaSG", {
      vpc: this.vpc,
      securityGroupName: this.prefixed("lambda-sg"),
      // Generic description (immutable in CFN — keep rule-agnostic).
      description: "Lambda functions security group",
      allowAllOutbound: false,
    });
    this.lambdaSecurityGroup.addEgressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(443),
      "HTTPS to AWS APIs (interface endpoints + S3/DDB gateway prefix lists)",
    );
    this.lambdaSecurityGroup.addEgressRule(
      this.neptuneSecurityGroup,
      ec2.Port.tcp(8182),
      "Neptune Gremlin/SPARQL",
    );
    this.lambdaSecurityGroup.addEgressRule(
      this.ecsSecurityGroup,
      ec2.Port.tcp(8001),
      "Ontology-engine API: api-proxy Lambda to ECS Cloud Map service",
    );
    // The discovery Lambda (sources-db-connector) connects DIRECTLY to source
    // databases via its driver dialects (see database/connectors/dialects.py),
    // not through Glue/Athena — so it needs egress to the supported DB ports.
    // Snowflake (443) is already covered above. Non-standard ports configured
    // per-source would need to be added here.
    for (const port of [5432, 3306, 1433, 5439, 1521]) {
      this.lambdaSecurityGroup.addEgressRule(
        ec2.Peer.anyIpv4(),
        ec2.Port.tcp(port),
        `Source database ${port} (direct JDBC discovery)`,
      );
    }
    // Keep HTTP egress off the shared Lambda SG: most platform functions never
    // call an OCSP responder. SourcesStack attaches this dedicated SG only to
    // sources-db-connector, which is the Lambda that loads the Snowflake driver.
    this.discoveryOcspSecurityGroup = new ec2.SecurityGroup(
      this,
      "DiscoveryOcspSG",
      {
        vpc: this.vpc,
        securityGroupName: this.prefixed("discovery-ocsp-sg"),
        description: "Snowflake discovery OCSP egress security group",
        allowAllOutbound: false,
      },
    );
    addConfiguredOcspEgress(
      this.discoveryOcspSecurityGroup,
      "direct discovery",
    );

    // Neptune ingress — scoped to the ECS + Lambda SGs (least privilege),
    // replacing the previous VPC-CIDR-wide rule.
    this.neptuneSecurityGroup.addIngressRule(
      this.ecsSecurityGroup,
      ec2.Port.tcp(8182),
      "Allow Neptune Gremlin/SPARQL from ECS tasks",
    );
    this.neptuneSecurityGroup.addIngressRule(
      this.lambdaSecurityGroup,
      ec2.Port.tcp(8182),
      "Allow Neptune Gremlin/SPARQL from Lambda functions",
    );

    // AOSS VPC endpoint — dedicated SG so any component that needs AOSS
    // can be granted access via an ingress rule here.
    this.aossSecurityGroup = new ec2.SecurityGroup(this, "AossSG", {
      vpc: this.vpc,
      securityGroupName: this.prefixed("aoss-vpce-sg"),
      description:
        "AOSS VPC endpoint - accept HTTPS from authorized components",
      allowAllOutbound: false,
    });
    this.aossSecurityGroup.addIngressRule(
      this.ecsSecurityGroup,
      ec2.Port.tcp(443),
      "Allow HTTPS from ECS tasks",
    );

    // ── Cloud Map Namespace ────────────────────────────────────────────
    this.serviceNamespace = this.createServiceNamespace();

    // Connector SG — used by Glue Connections to reach source databases.
    // Egress restricted to least privilege: the supported source-DB
    // ports plus 443 (Snowflake wire protocol + AWS APIs the connector calls,
    // e.g. Glue/S3/STS). Source DB security groups must allow inbound from this
    // SG. Cross-network JDBC (peering/TGW/PrivateLink) adds its own scoped
    // egress rules in the JdbcConnectivity construct.
    this.connectorSecurityGroup = new ec2.SecurityGroup(this, "ConnectorSG", {
      vpc: this.vpc,
      securityGroupName: this.prefixed("connector-sg"),
      description:
        "Glue Connection / Athena connector - outbound to source databases",
      allowAllOutbound: false,
    });
    // Glue managed connectors require self-referencing rules for inter-ENI
    // communication during connection validation and query execution. Under
    // allowAllOutbound the egress side was implicit; with egress locked down it
    // must be declared explicitly on both directions.
    this.connectorSecurityGroup.addIngressRule(
      this.connectorSecurityGroup,
      ec2.Port.allTcp(),
      "Glue connector self-reference (ingress)",
    );
    this.connectorSecurityGroup.addEgressRule(
      this.connectorSecurityGroup,
      ec2.Port.allTcp(),
      "Glue connector self-reference (egress)",
    );
    // Supported source-DB engines/ports (see database/connectors/dialects.py):
    // PostgreSQL 5432, MySQL 3306, SQL Server 1433, Redshift 5439, Oracle 1521.
    // Snowflake (443) and any AWS API the connector calls are covered by the
    // 443 rule below.
    //
    // DESTINATION SCOPE: a managed Glue connector reaching a customer database
    // or a SaaS warehouse has no enumerable destination set, so the default is
    // `0.0.0.0/0` for these ports. Where the destinations ARE known — egress via
    // a fixed NAT/proxy range, or source databases on known ranges — narrow all
    // of this connector's internet-bound egress with one knob:
    //   -c connector_egress_cidrs=10.20.0.0/16,192.0.2.10/32
    // Same shape as `jdbc_peer_cidrs` (see addJdbcConnectivity), and it applies
    // to the DB ports, OCSP 80 and 443 alike rather than special-casing one
    // port. Cross-network JDBC (peering/TGW/PrivateLink) is already scoped to
    // its configured CIDRs by the JdbcConnectivity construct.
    for (const peer of connectorEgressPeers) {
      for (const port of [5432, 3306, 1433, 5439, 1521]) {
        this.connectorSecurityGroup.addEgressRule(
          peer,
          ec2.Port.tcp(port),
          `Source database ${port}`,
        );
      }
    }
    // OCSP certificate-revocation checks. OCSP is an HTTP protocol and always
    // uses port 80 — there is no HTTPS variant to fold into the 443 rule below.
    // snowflake-connector-python checks revocation on every connect; without
    // this rule each attempt burns ~5-30s per responder before failing open
    // (measured ValidationLatency of 184s on a Snowflake scan, against a 900s
    // Lambda timeout). Egress-only, and OCSP responses are signed, so plaintext
    // transport is the intended design rather than a weakening.
    //
    // Only the Snowflake driver does internet OCSP — every other engine talks
    // to a private endpoint. A deployment with no Snowflake source can drop the
    // rule entirely with `-c connector_ocsp_egress=false`; the cost of doing so
    // while Snowflake IS in use is soft-fail revocation checking plus the
    // latency above, so it is on by default.
    addConfiguredOcspEgress(this.connectorSecurityGroup, "managed connector");
    for (const peer of connectorEgressPeers) {
      this.connectorSecurityGroup.addEgressRule(
        peer,
        ec2.Port.tcp(443),
        "HTTPS: Snowflake wire protocol + AWS APIs (Glue/S3/STS)",
      );
    }

    // ── Cross-network JDBC connectivity (optional, created-VPC only) ──
    // Imported VPCs are expected to bring their own peering/TGW/PrivateLink +
    // routes (managed externally), mirroring the VPC-endpoint policy above.
    if (!existingVpcId) {
      this.addJdbcConnectivity(this.vpc as ec2.Vpc);
    }

    this.emitNetworkOutputs();
  }

  /**
   * Import the six security groups a private-VPC deployment expects to already
   * exist, instead of creating them.
   *
   * No rules are added. The networking package that created these groups also
   * created every ingress and egress rule — Neptune 8182 from Lambda and ECS,
   * the connector self-reference Glue and Athena require, the five database
   * ports, OCSP on 80 — and adding them again from here would either fail or
   * silently drift from what the network team applied.
   *
   * `mutable: false` makes that explicit: CDK then refuses any later
   * `addEgressRule` on these objects rather than generating a rule that would
   * never be applied, so a future caller gets a synth error instead of a
   * connectivity bug.
   */
  /**
   * The shared Cloud Map private DNS namespace, so services resolve each other
   * by stable name rather than an address that changes on every task restart.
   * `ontology-engine.<prefix>-<env>-services.local` is the one the API proxy
   * depends on.
   */
  private createServiceNamespace(): servicediscovery.PrivateDnsNamespace {
    return new servicediscovery.PrivateDnsNamespace(this, "ServiceNamespace", {
      name: `${this.prefixed("services")}.local`,
      vpc: this.vpc,
    });
  }

  private importSecurityGroups(config: PvtVpcConfig): {
    neptune: ec2.ISecurityGroup;
    ecs: ec2.ISecurityGroup;
    lambda: ec2.ISecurityGroup;
    aoss: ec2.ISecurityGroup;
    connector: ec2.ISecurityGroup;
    discoveryOcsp: ec2.ISecurityGroup;
    agentCore: ec2.ISecurityGroup;
    mcp: ec2.ISecurityGroup;
  } {
    const groups = config.securityGroups ?? {};

    const importGroup = (id: string, logicalId: string): ec2.ISecurityGroup =>
      ec2.SecurityGroup.fromSecurityGroupId(this, logicalId, id, {
        mutable: false,
      });

    // validate() in pvt-vpc-config has already proven all eight are present,
    // so the non-null assertions here cannot fire at runtime.
    return {
      neptune: importGroup(groups.neptune!, "ImportedNeptuneSG"),
      ecs: importGroup(groups.ecs!, "ImportedEcsSG"),
      lambda: importGroup(groups.lambda!, "ImportedLambdaSG"),
      aoss: importGroup(groups.aossVpce!, "ImportedAossSG"),
      connector: importGroup(groups.connector!, "ImportedConnectorSG"),
      discoveryOcsp: importGroup(
        groups.discoveryOcsp!,
        "ImportedDiscoveryOcspSG",
      ),
      agentCore: importGroup(groups.agentCore!, "ImportedAgentCoreSG"),
      mcp: importGroup(groups.mcp!, "ImportedMcpSG"),
    };
  }

  /**
   * Publish the VPC id, private subnet ids and Cloud Map namespace.
   *
   * Emitted in both deployment flows: a private-VPC deployment still has to
   * publish these, because the SSM parameters are the cross-app contract that
   * other CDK apps (today the COA-operated Databricks connector) read to
   * attach their own compute to this VPC.
   */
  private emitNetworkOutputs(): void {
    new cdk.CfnOutput(this, "VpcId", {
      value: this.vpc.vpcId,
      description: "SemanticContext VPC ID",
    });

    // SSM rather than a CloudFormation export: an SSM StringList read inside
    // the other stack would be a list token of unknown length, which
    // Vpc.fromVpcAttributes cannot map to subnets.
    const { ssmPrefix, envName } = resolveContext(this.node);
    new ssm.StringParameter(this, "SsmVpcId", {
      parameterName: `${ssmPrefix}/${envName}/network/vpc-id`,
      stringValue: this.vpc.vpcId,
      description: "SemanticContext VPC ID",
    });
    new ssm.StringParameter(this, "SsmPrivateSubnetIds", {
      parameterName: `${ssmPrefix}/${envName}/network/private-subnet-ids`,
      stringValue: cdk.Fn.join(
        ",",
        this.vpc.selectSubnets({
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
        }).subnetIds,
      ),
      description:
        "SemanticContext private subnet IDs (with egress), comma-separated",
    });

    new cdk.CfnOutput(this, "ServiceNamespaceArn", {
      value: this.serviceNamespace.namespaceArn,
      description: "Shared Cloud Map namespace ARN for service discovery",
    });
  }

  /**
   * Parse the `jdbc_*` connectivity context keys and, if any are set, provision
   * the corresponding cross-network plumbing (peering / TGW / PrivateLink) so
   * the discovery Lambda and Glue connector can reach source databases in
   * another VPC, account, or on-prem network.
   */
  private addJdbcConnectivity(vpc: ec2.Vpc): void {
    const peering = this.parsePeeringContext();
    const transitGateway = this.parseTransitGatewayContext();
    const privateLink = this.parsePrivateLinkContext();

    if (!peering && !transitGateway && !privateLink) {
      return;
    }

    new JdbcConnectivity(this, "JdbcConnectivity", {
      vpc,
      clientSecurityGroups: [
        this.lambdaSecurityGroup,
        this.connectorSecurityGroup,
      ],
      peering,
      transitGateway,
      privateLink,
    });
  }

  private parsePeeringContext(): PeeringConfig | undefined {
    const peerVpcId = this.ctxString("jdbc_peer_vpc_id");
    if (!peerVpcId) {
      return undefined;
    }
    const destinationCidrs = this.ctxList("jdbc_peer_cidrs");
    if (destinationCidrs.length === 0) {
      throw new Error(
        "jdbc_peer_vpc_id requires jdbc_peer_cidrs (comma-separated CIDRs)",
      );
    }
    return {
      peerVpcId,
      destinationCidrs,
      peerOwnerId: this.ctxString("jdbc_peer_owner_id"),
      peerRegion: this.ctxString("jdbc_peer_region"),
    };
  }

  private parseTransitGatewayContext(): TransitGatewayConfig | undefined {
    const transitGatewayId = this.ctxString("jdbc_tgw_id");
    if (!transitGatewayId) {
      return undefined;
    }
    const destinationCidrs = this.ctxList("jdbc_tgw_cidrs");
    if (destinationCidrs.length === 0) {
      throw new Error(
        "jdbc_tgw_id requires jdbc_tgw_cidrs (comma-separated CIDRs)",
      );
    }
    return { transitGatewayId, destinationCidrs };
  }

  private parsePrivateLinkContext(): PrivateLinkConfig | undefined {
    const serviceName = this.ctxString("jdbc_privatelink_service");
    if (!serviceName) {
      return undefined;
    }
    const portRaw = this.ctxString("jdbc_privatelink_port");
    const port = portRaw ? Number(portRaw) : NaN;
    if (!Number.isInteger(port) || port < 1 || port > 65535) {
      throw new Error(
        "jdbc_privatelink_service requires jdbc_privatelink_port (integer 1-65535)",
      );
    }
    return {
      serviceName,
      port,
      privateDnsEnabled:
        this.ctxString("jdbc_privatelink_private_dns") === "true",
    };
  }

  /** Read a string context value, returning undefined when unset/empty. */
  private ctxString(key: string): string | undefined {
    const raw = this.node.tryGetContext(key) as string | undefined;
    return raw && String(raw).trim() ? String(raw).trim() : undefined;
  }

  /** Read a comma-separated context value into a trimmed, non-empty list. */
  private ctxList(key: string): string[] {
    const raw = this.ctxString(key);
    if (!raw) {
      return [];
    }
    return raw
      .split(",")
      .map((s) => s.trim())
      .filter((s) => s.length > 0);
  }
}
