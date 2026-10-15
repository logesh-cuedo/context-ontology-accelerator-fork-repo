// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

/**
 * Private-VPC deployment configuration.
 *
 * Two deployment flows share this codebase:
 *
 *   STANDARD      — no `vpc_id`. The app creates its own VPC, endpoints,
 *                   security groups and IAM roles, exactly as it always has.
 *                   Nothing in this module changes that.
 *
 *   PRIVATE VPC   — `cdk deploy -c vpc_id=vpc-0abc123`. The account owner has
 *                   already created that VPC, its endpoints, the 6 security
 *                   groups and the 57 IAM roles, because a locked-down account
 *                   denies the pipeline `iam:CreateRole`,
 *                   `ec2:CreateSecurityGroup` and `ec2:CreateVpcEndpoint`. The
 *                   app imports all of them and creates only the application
 *                   resources.
 *
 * ## The switch is `-c vpc_id=`, not a field in this file
 *
 * `vpc_id` was already how this codebase imports a VPC, so it stays the single
 * thing that selects the flow. The config file holds only the DETAILS of the
 * VPC named on the command line — its subnets, its security groups, its
 * endpoints — and never the VPC id itself.
 *
 * That is deliberate: a VPC id in both places could disagree, and the failure
 * (deploying into one VPC while importing another's security groups) would not
 * surface until runtime.
 *
 * Validation is all-or-nothing (see `validate`): a half-filled config is the
 * dangerous state, because it would import some resources and create others,
 * leaving duplicates behind in an account that was supposed to forbid
 * creation. So `vpc_id` without a complete config fails at synth, naming every
 * missing field at once.
 */

import * as fs from "fs";
import * as path from "path";

import type { Construct } from "constructs";

import { fromRoot } from "./paths";

/** Default location of the config file, relative to the monorepo root. */
export const PVT_VPC_CONFIG_PATH = "infra/pvt_vpc/config.json";

/**
 * The pre-created subnets and route tables of the VPC named by `-c vpc_id=`.
 *
 * No `id` field: the VPC id comes from the command line, so that it cannot be
 * specified in two places that disagree.
 */
export interface PvtVpcNetwork {
  /**
   * The VPC's CIDR block.
   *
   * Required because the app writes security-group rules and Neptune subnet
   * groups against it, and `fromVpcAttributes` has no way to discover it.
   */
  readonly cidr?: string;

  /**
   * Availability zone NAMES of the private subnets, in the same order as
   * `privateSubnetIds`.
   *
   * Cannot be derived: an AZ name is not recoverable from a subnet id without
   * an AWS API call, and the whole point of listing the subnets is to avoid
   * needing credentials at synth time.
   *
   * Two minimum, and they must differ — Neptune needs a multi-AZ subnet group
   * and AgentCore places its runtime interfaces across both. Note that AZ
   * names are per-account aliases for physical zones, so `us-east-1b` in one
   * account is not the same hardware as `us-east-1b` in another.
   */
  readonly availabilityZones?: string[];

  /** The pre-created private subnet ids, one per entry in `availabilityZones`. */
  readonly privateSubnetIds?: string[];

  /**
   * Route table ids of those subnets, in the same order.
   *
   * Without these CDK cannot add routes for a gateway endpoint or a peering
   * connection, and silently emits a VPC whose subnets have no route table
   * association it can reason about.
   */
  readonly privateRouteTableIds?: string[];
}

/**
 * The eight named security groups from the networking package. Each is
 * attached to a different tier and carries different rules — see the
 * deployment notes.
 */
export interface PvtVpcSecurityGroups {
  readonly lambda?: string;
  readonly ecs?: string;
  readonly neptune?: string;
  readonly aossVpce?: string;
  readonly connector?: string;
  readonly discoveryOcsp?: string;
  /**
   * The Context Manager AgentCore runtime (serve stack). Separate from `ecs`
   * because the runtime reaches AOSS and Neptune directly, so the networking
   * package gives those two groups an ingress rule naming THIS group as the
   * source — see `AgentCoreAossIngress`/`AgentCoreNeptuneIngress` in
   * `pvt_vpc/networking/coa-networking-security-groups.yaml`.
   */
  readonly agentCore?: string;
  /** The MCP server AgentCore runtime (mcp stack). HTTPS egress only. */
  readonly mcp?: string;
}

/**
 * VPC endpoint ids the SYNTH needs.
 *
 * Only one. The OpenSearch Serverless network policy has to name the AOSS
 * data-plane endpoint explicitly in its `SourceVPCEs`, so the synth cannot
 * derive it — and without it the policy grants nothing (see the guard in
 * StorageStack).
 *
 * The other ~21 endpoints a private VPC needs — S3, DynamoDB, Bedrock, ECR,
 * STS and the rest — are NOT listed here, deliberately. They work
 * transparently through private DNS once they exist in the VPC: the AWS SDK
 * resolves the normal service hostname to the endpoint, so no code anywhere
 * references their ids. Listing them would mean collecting 21 values that
 * nothing reads, where a typo is silent. They belong in the deployment
 * runbook as things to CREATE, not in a file the build consumes.
 */
export interface PvtVpcEndpoints {
  readonly aossData?: string;
}

/**
 * An existing Neptune cluster to use instead of creating one.
 *
 * Leave every field blank and the deployment creates its own cluster, subnet
 * group and primary instance exactly as it always has. Fill them in and it
 * creates none of those and talks to yours.
 *
 * This is independent of `-c vpc_id=`: a client can already run Neptune
 * whether or not they also pre-created the VPC. All three fields are required
 * together — a partially filled block would leave the app with an endpoint it
 * cannot authorise against, or an ARN pointing at a cluster it cannot reach.
 *
 * The cluster must sit in the deployment's VPC and accept traffic on its port
 * from the Lambda and ECS security groups, which the networking template's
 * `…-neptune-sg` rules describe. Nothing here can verify that; a cluster the
 * workloads cannot reach fails at runtime.
 */
export interface PvtVpcExistingNeptune {
  /**
   * The cluster WRITER endpoint host, e.g.
   * `my-cluster.cluster-abc123.us-east-1.neptune.amazonaws.com`.
   *
   * Host only — no scheme, no port. The app builds
   * `https://{endpoint}:{port}` itself.
   */
  readonly clusterEndpoint?: string;

  /** The port, normally 8182. */
  readonly port?: string;

  /**
   * The cluster RESOURCE id — `cluster-ABCD1234EFGH5678`, not the cluster
   * name.
   *
   * These are different identifiers and the distinction is load-bearing: every
   * IAM data-access policy is built as
   * `arn:aws:neptune-db:{region}:{account}:{clusterResourceId}/*`. Putting the
   * cluster NAME here produces an ARN that looks valid, matches nothing, and
   * fails at runtime with access-denied rather than at deploy. Find it with:
   *
   *   aws neptune describe-db-clusters \
   *     --db-cluster-identifier <name> \
   *     --query 'DBClusters[0].DbClusterResourceId'
   */
  readonly clusterResourceId?: string;
}

/**
 * Resources a client may already run, which the deployment should reuse rather
 * than create.
 *
 * Each entry is independent and optional: blank means "create it", filled
 * means "use mine". This is how a client who already operates a graph database
 * avoids a second one, and it is why the names need configuring — a
 * pre-existing resource will not be called `{prefix}-{env}-…`.
 */
export interface PvtVpcExisting {
  readonly neptune?: PvtVpcExistingNeptune;
}

/**
 * The config file as written on disk.
 *
 * Deliberately small: it holds ONLY what the build cannot discover or derive
 * for itself when deploying into a pre-created VPC.
 *
 * Everything else a deployment needs already has a home, and both flows read
 * it from there:
 *
 *   - container image URIs   `-c ontology_engine_image_uri=` etc.
 *   - admin user, IdP, SAML  SSM `/{prefix}/config`
 *   - custom domains, certs  SSM `/{prefix}/config`
 *   - alarm topics, WAF ids  `-c` context keys
 *   - JDBC peering, MFA      `-c` context keys
 *
 * Those are not duplicated here. A second source for the same value is a
 * second thing to keep in sync, and the failure when they disagree is silent.
 */
export interface PvtVpcConfigFile {
  /**
   * The AWS account id. Every imported role ARN is built from it, and it
   * cannot be derived at synth time without credentials.
   */
  readonly account?: string;

  /** The deploy region, for the same reason as `account`. */
  readonly region?: string;

  /** Resource prefix — the `coa` in `coa-dev-authorizer-fn-role`. */
  readonly prefix?: string;

  /** Environment name — the `dev` in `coa-dev-authorizer-fn-role`. */
  readonly env?: string;

  /** Subnets and route tables of the VPC named by `-c vpc_id=`. */
  readonly vpc?: PvtVpcNetwork;

  /** The six pre-created security groups. */
  readonly securityGroups?: PvtVpcSecurityGroups;

  /** The one endpoint id the synth cannot derive. */
  readonly vpcEndpoints?: PvtVpcEndpoints;

  /**
   * Resources the client already runs, to reuse instead of create.
   *
   * Read in BOTH flows, unlike everything above: an existing Neptune is
   * possible whether or not the VPC was pre-created.
   */
  readonly existing?: PvtVpcExisting;
}

/** The config plus the resolved mode flag the stacks branch on. */
export interface PvtVpcConfig extends PvtVpcConfigFile {
  /**
   * True when `-c vpc_id=` was given. Every "import rather than create" branch
   * in the app keys off this one flag, so standard deployments take an
   * identical path to the one they take today.
   */
  readonly privateVpcMode: boolean;

  /** The VPC id from `-c vpc_id=`, set only in private mode. */
  readonly vpcId?: string;
}

/** A config with private mode off — what a standard deployment resolves to. */
const STANDARD_MODE: PvtVpcConfig = { privateVpcMode: false };

/**
 * An existing Neptune cluster from the config, or undefined to create one.
 *
 * Read directly from the file rather than through {@link loadPvtVpcConfig},
 * because this applies in BOTH flows: a client can already run Neptune without
 * having pre-created the VPC. The rest of the config is irrelevant here and is
 * not validated — a standard deployment must keep working with every other
 * field blank, which is the shipped state of the file.
 *
 * Returns undefined when the file is missing, unreadable, or the block is
 * blank. A PARTIALLY filled block throws: an endpoint without a resource id
 * would leave every IAM policy pointing at nothing, and a resource id without
 * an endpoint leaves nothing to connect to. Both fail at runtime rather than
 * at deploy, so they are rejected here.
 *
 * @param scope      any construct; reserved for future context overrides
 * @param configPath overrides the file location; tests use it directly
 */
export function resolveExistingNeptune(
  scope?: Construct,
  configPath?: string,
): Required<PvtVpcExistingNeptune> | undefined {
  void scope;
  const file = readConfigFileIfPresent(configPath);
  const neptune = file?.existing?.neptune;
  if (!neptune) {
    return undefined;
  }

  const endpoint = neptune.clusterEndpoint?.trim() ?? "";
  const resourceId = neptune.clusterResourceId?.trim() ?? "";
  const port = neptune.port?.trim() ?? "";

  // Nothing identifying a cluster: create our own, as always.
  //
  // `port` alone does not count as filled in. The shipped template pre-fills
  // it with 8182 as a hint, and treating that as a partial block would make
  // the committed config throw on EVERY deployment — including the standard
  // flow, which has no business reading this file at all.
  if (endpoint === "" && resourceId === "") {
    return undefined;
  }

  const problems: string[] = [];
  if (endpoint === "") {
    problems.push("existing.neptune.clusterEndpoint is required");
  } else if (endpoint.includes("://") || endpoint.includes(":")) {
    // The app builds `https://{endpoint}:{port}`; a scheme or port here
    // produces a URL like `https://https://host:8182:8182`, which fails at
    // first connection rather than at deploy.
    problems.push(
      `existing.neptune.clusterEndpoint must be a host only, with no scheme ` +
        `or port (got "${endpoint}")`,
    );
  }

  if (resourceId === "") {
    problems.push("existing.neptune.clusterResourceId is required");
  } else if (!resourceId.startsWith("cluster-")) {
    // The single most likely mistake, and the most expensive: every IAM
    // data-access policy is `arn:aws:neptune-db:…:{clusterResourceId}/*`, so
    // the cluster NAME here yields a valid-looking ARN that matches nothing
    // and denies every request at runtime.
    problems.push(
      `existing.neptune.clusterResourceId must be the cluster RESOURCE id ` +
        `(starts with "cluster-"), not the cluster name (got "${resourceId}"). ` +
        `Find it with: aws neptune describe-db-clusters ` +
        `--db-cluster-identifier ${resourceId} ` +
        `--query 'DBClusters[0].DbClusterResourceId'`,
    );
  }

  if (port === "") {
    problems.push("existing.neptune.port is required (normally 8182)");
  } else if (!/^\d+$/.test(port) || Number(port) < 1 || Number(port) > 65535) {
    problems.push(
      `existing.neptune.port must be a port number (got "${port}")`,
    );
  }

  if (problems.length > 0) {
    throw new Error(
      [
        "existing.neptune in the private-VPC config is incomplete:",
        ...problems.map((p) => `  - ${p}`),
        "",
        "All three fields are required together. Clear all of them to have",
        "the deployment create its own Neptune cluster instead.",
      ].join("\n"),
    );
  }

  return { clusterEndpoint: endpoint, port, clusterResourceId: resourceId };
}

/**
 * Parse the config file, or undefined if it is absent or malformed.
 *
 * Deliberately forgiving, unlike {@link loadPvtVpcConfigFile}: the callers of
 * {@link resolveExistingNeptune} run in BOTH flows, and a standard deployment
 * must not be broken by a config file it otherwise ignores.
 */
function readConfigFileIfPresent(
  configPath?: string,
): PvtVpcConfigFile | undefined {
  const resolved =
    configPath ??
    process.env.COA_PVT_VPC_CONFIG ??
    fromRoot(PVT_VPC_CONFIG_PATH);
  if (!fs.existsSync(resolved)) {
    return undefined;
  }
  try {
    const parsed: unknown = JSON.parse(fs.readFileSync(resolved, "utf-8"));
    if (
      parsed === null ||
      typeof parsed !== "object" ||
      Array.isArray(parsed)
    ) {
      return undefined;
    }
    return parsed as PvtVpcConfigFile;
  } catch {
    // Malformed JSON is reported loudly by loadPvtVpcConfigFile when a
    // private-VPC deployment actually needs the file. Failing here would
    // break standard deployments that never read it.
    return undefined;
  }
}

function isBlank(value: string | undefined): boolean {
  return value === undefined || value.trim() === "";
}

/** True when the list is absent, empty, or holds only blank placeholders. */
function isBlankList(value: string[] | undefined): boolean {
  return value === undefined || value.length === 0 || value.every(isBlank);
}

/**
 * Check that a private-VPC config is complete.
 *
 * Returns the problems rather than throwing so the caller can report all of
 * them at once — an operator filling in 41 fields should not have to rerun the
 * synth once per mistake.
 */
export function validate(config: PvtVpcConfigFile, vpcId?: string): string[] {
  const problems: string[] = [];

  // Nothing to check in standard mode: the app creates its own resources.
  if (isBlank(vpcId)) {
    return problems;
  }

  const require = (value: string | undefined, key: string): void => {
    if (isBlank(value)) {
      problems.push(`${key} is required when -c vpc_id= is given`);
    }
  };

  // The account id cannot be derived, and every imported role ARN is built
  // from it. A wrong or missing account produces an ARN that looks valid and
  // refers to nothing.
  require(config.account, "account");
  require(config.region, "region");
  require(config.prefix, "prefix");
  require(config.env, "env");

  if (isBlankList(config.vpc?.privateSubnetIds)) {
    problems.push("vpc.privateSubnetIds is required when -c vpc_id= is given");
  } else if ((config.vpc?.privateSubnetIds ?? []).length < 2) {
    // Two subnets in two different AZs is a hard requirement, not a
    // preference: Neptune needs a multi-AZ subnet group, and AgentCore places
    // runtime interfaces across both.
    problems.push(
      "vpc.privateSubnetIds needs at least 2 subnets in different availability zones",
    );
  }

  if (isBlankList(config.vpc?.privateRouteTableIds)) {
    problems.push(
      "vpc.privateRouteTableIds is required when -c vpc_id= is given",
    );
  }

  require(config.vpc?.cidr, "vpc.cidr");

  if (isBlankList(config.vpc?.availabilityZones)) {
    problems.push("vpc.availabilityZones is required when -c vpc_id= is given");
  }

  // The three lists are positional — subnet[i] lives in zone[i] and uses route
  // table[i]. A length mismatch is not a synth error: CDK zips them and
  // silently drops the extras, so subnets would be placed in the wrong zone
  // with no warning, and Neptune's "multi-AZ" subnet group could end up
  // single-AZ.
  const zones = config.vpc?.availabilityZones ?? [];
  const subnets = config.vpc?.privateSubnetIds ?? [];
  const routeTables = config.vpc?.privateRouteTableIds ?? [];
  if (
    zones.length > 0 &&
    subnets.length > 0 &&
    zones.length !== subnets.length
  ) {
    problems.push(
      `vpc.availabilityZones has ${zones.length} entries but ` +
        `vpc.privateSubnetIds has ${subnets.length} — they are positional and ` +
        "must be the same length",
    );
  }
  if (
    routeTables.length > 0 &&
    subnets.length > 0 &&
    routeTables.length !== subnets.length
  ) {
    problems.push(
      `vpc.privateRouteTableIds has ${routeTables.length} entries but ` +
        `vpc.privateSubnetIds has ${subnets.length} — they are positional and ` +
        "must be the same length",
    );
  }
  if (zones.length >= 2 && new Set(zones).size < zones.length) {
    problems.push(
      "vpc.availabilityZones contains duplicates — Neptune needs a multi-AZ " +
        "subnet group and AgentCore spreads across distinct zones",
    );
  }

  // All six, or none. A partial set would have the app import some groups and
  // create others, which is how you end up with twelve security groups and the
  // app quietly ignoring the six the network team made.
  const sgKeys: (keyof PvtVpcSecurityGroups)[] = [
    "lambda",
    "ecs",
    "neptune",
    "aossVpce",
    "connector",
    "discoveryOcsp",
    "agentCore",
    "mcp",
  ];
  for (const key of sgKeys) {
    require(config.securityGroups?.[key], `securityGroups.${key}`);
  }

  // The one endpoint the synth genuinely needs. The OpenSearch network policy
  // names it explicitly; without it the collection is unreachable, or in a dev
  // account left open.
  require(config.vpcEndpoints?.aossData, "vpcEndpoints.aossData");

  return problems;
}

/** The CDK context key that selects a private-VPC deployment. */
export const VPC_ID_CONTEXT_KEY = "vpc_id";

/** Read `-c vpc_id=` from the construct tree, or undefined in standard mode. */
export function readVpcIdFromContext(scope: Construct): string | undefined {
  const value = scope.node.tryGetContext(VPC_ID_CONTEXT_KEY) as
    | string
    | undefined;
  return isBlank(value) ? undefined : value;
}

/**
 * Load the private-VPC configuration for the VPC named by `-c vpc_id=`.
 *
 * Without `vpc_id` this returns standard mode and never looks at the file, so
 * a developer who has never heard of private-VPC mode is unaffected by
 * whatever the file contains.
 *
 * With `vpc_id`, the file must exist and be complete. A missing or half-filled
 * file is an error rather than a silent fallback: falling back to CREATING
 * resources in an account that forbids it would turn a typo into a failed
 * deploy fifteen stacks later.
 *
 * @param scope      any construct, for reading `vpc_id` from context
 * @param configPath overrides the file location; tests use it directly
 */
export function loadPvtVpcConfig(
  scope?: Construct,
  configPath?: string,
): PvtVpcConfig {
  const vpcId = scope ? readVpcIdFromContext(scope) : undefined;

  // Standard mode: the app creates its own VPC and everything in it. The
  // config file is not read at all, so it cannot break this flow.
  if (isBlank(vpcId)) {
    return STANDARD_MODE;
  }
  return loadPvtVpcConfigFile(vpcId!, configPath);
}

/**
 * The file half of {@link loadPvtVpcConfig}, with `vpc_id` already resolved.
 *
 * Separate so tests can supply a VPC id directly instead of building a
 * construct tree to carry one.
 */
export function loadPvtVpcConfigFile(
  vpcId: string,
  configPath?: string,
): PvtVpcConfig {
  // COA_PVT_VPC_CONFIG points the loader at an alternate file. Two uses: a
  // test fixture, and an operator keeping the filled-in config outside the
  // repo so real account ids and subnet ids are never committed.
  const resolved =
    configPath ??
    process.env.COA_PVT_VPC_CONFIG ??
    fromRoot(PVT_VPC_CONFIG_PATH);

  if (!fs.existsSync(resolved)) {
    throw new Error(
      [
        `-c ${VPC_ID_CONTEXT_KEY}=${vpcId} selects a private-VPC deployment, but`,
        `${PVT_VPC_CONFIG_PATH} does not exist.`,
        "",
        "That file supplies the subnets, security groups and endpoints of the",
        "VPC named on the command line. Create it, or drop the",
        `-c ${VPC_ID_CONTEXT_KEY}= flag to deploy in standard mode where the app`,
        "creates its own VPC, endpoints, security groups and IAM roles.",
      ].join("\n"),
    );
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(fs.readFileSync(resolved, "utf-8"));
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new Error(`${path.basename(resolved)} is not valid JSON (${msg})`);
  }

  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error(`${path.basename(resolved)} must contain a JSON object`);
  }

  const file = parsed as PvtVpcConfigFile;

  const problems = validate(file, vpcId);
  if (problems.length > 0) {
    throw new Error(
      [
        `${path.basename(resolved)} is incomplete for a private-VPC deployment`,
        `of ${vpcId}:`,
        ...problems.map((p) => `  - ${p}`),
        "",
        `Fill these in, or drop the -c ${VPC_ID_CONTEXT_KEY}= flag to deploy in`,
        "standard mode where the app creates its own VPC, endpoints, security",
        "groups and IAM roles.",
      ].join("\n"),
    );
  }

  return { ...file, privateVpcMode: true, vpcId };
}

/**
 * Build the ARN of a pre-created IAM role.
 *
 * The config holds no role ARNs. All 71 are derived from account + prefix +
 * env plus the role's own name, which is why the names in
 * `infra/pvt_vpc/ROLE-NAMES.md` have to be used exactly — a renamed role
 * cannot be found, and the failure surfaces at deploy or runtime rather than
 * when the config is reviewed.
 *
 * @param roleName the unprefixed name, e.g. `authorizer-fn-role`
 */
export function pvtVpcRoleArn(
  config: PvtVpcConfig,
  roleName: string,
): string | undefined {
  if (!config.privateVpcMode) {
    return undefined;
  }
  // validate() has already proven these are present in private mode.
  return `arn:aws:iam::${config.account}:role/${config.prefix}-${config.env}-${roleName}`;
}
