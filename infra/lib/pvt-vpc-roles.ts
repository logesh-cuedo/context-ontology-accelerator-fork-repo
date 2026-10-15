// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

/**
 * Execution roles for the two deployment flows.
 *
 * Every Lambda, ECS task definition and state machine in this app needs an
 * execution role. Which of the two flows is active decides where it comes
 * from:
 *
 *   STANDARD      — the role is CREATED here, with an explicit name. The 193
 *                   `grant*` / `addToRolePolicy` calls spread across the
 *                   service stacks attach to it exactly as they always have.
 *
 *   PRIVATE VPC   — the role ALREADY EXISTS, created by the account owner
 *                   together with its permissions, because a locked-down
 *                   account denies the pipeline `iam:CreateRole`. It is
 *                   imported, and the grants become no-ops.
 *
 * ## Why this replaces CDK's implicit role
 *
 * `new lambda.Function(...)` without a `role` creates one whose physical name
 * CloudFormation generates at deploy time — `AuthorizerFnServiceRole91AE9242`.
 * That name cannot be pre-created, because it does not exist until the deploy
 * that invents it has run, and its suffix is derived from the resource's
 * position in the stack, so it changes when unrelated constructs are added or
 * renamed. An account owner cannot create a role to match it.
 *
 * Passing `role:` is therefore the only way to get a stable name, which makes
 * naming and importing the same edit rather than two separate steps.
 *
 * Standard deployments get a readable, predictable role name out of this. That
 * is a change to the synthesized template — the logical id and physical name
 * both move — so the first deploy after adopting this replaces each role.
 * Permissions and trust policies are unchanged.
 *
 * ## The silent-failure risk this file is built around
 *
 * An imported role is immutable: CDK drops `addToRolePolicy` and `grant*`
 * against it WITHOUT warning. Synth succeeds, the deploy succeeds, and the
 * platform then fails at runtime with access-denied errors scattered across
 * 40 services and nothing in the template to explain why.
 *
 * That is acceptable only because in private mode the operator has already
 * attached the permissions — but only if they attached ALL of them. So
 * `writePermissionManifest` records every statement the synth WOULD have
 * attached, for diffing against the IAM package before deploying. This turns
 * the failure `ROLE-NAMES.md` warns about ("a missing permission does not fail
 * the deployment — it fails later at runtime") into a pre-deploy diff.
 *
 * Imports deliberately use `mutable: false`. `mutable: true` would make CDK
 * emit an `AWS::IAM::Policy` per role, needing `iam:PutRolePolicy` the account
 * denies, and would overwrite the operator's own permissions with the synth's.
 */

import * as fs from "fs";
import * as path from "path";

import * as iam from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";

import { prefixed } from "./context";
import { loadPvtVpcConfig, type PvtVpcConfig } from "./pvt-vpc-config";

/**
 * The unprefixed role names, exactly as `infra/pvt_vpc/ROLE-NAMES.md` lists
 * them and exactly as the account owner must create them.
 *
 * This is a typed map rather than bare strings at the call sites so a typo
 * fails at compile time. A misspelled name would otherwise reach the account
 * as an ARN that looks valid and refers to nothing, failing at deploy in
 * private mode or creating a wrongly-named role in standard mode.
 *
 * Keys are grouped by the stack that owns them.
 */
export const ROLE_NAMES = {
  // ── API ────────────────────────────────────────────────────────────
  authorizerFn: "authorizer-fn-role",
  cacheInvalidationFn: "cache-invalidation-fn-role",
  notImplementedFn: "not-implemented-fn-role",
  restApiCloudWatch: "rest-api-cloud-watch-role",
  dataLayerApiFn: "data-layer-api-fn-role",

  // ── Auth ───────────────────────────────────────────────────────────
  adminUserLambda: "admin-user-lambda-role",
  // cr.Provider's framework Lambda for the admin-user custom resource, and
  // the singleton AwsCustomResource Lambda each stack that uses one gets.
  // Neither is in ROLE-NAMES.md — see the note at the bottom of this file.
  adminUserProviderFramework: "admin-user-provider-framework-role",
  authnzCustomResource: "authnz-custom-resource-role",
  webCustomResource: "web-custom-resource-role",
  lakeformationAdminOnEvent: "lakeformation-admin-on-event-role",
  lakeformationAdminFramework: "lakeformation-admin-framework-role",
  webBucketDeployment: "web-bucket-deployment-role",

  // ── Namespace / workspaces ─────────────────────────────────────────
  namespaceApiFn: "namespace-api-fn-role",
  grantsApiFn: "grants-api-fn-role",
  rolesApiFn: "roles-api-fn-role",
  platformRolesApiFn: "platform-roles-api-fn-role",
  assetTypeCrFn: "asset-type-cr-fn-role",
  // The custom-resource FRAMEWORK Lambda that wraps assetTypeCrFn. A separate
  // role from the handler's own: cr.Provider creates one implicitly otherwise,
  // and CloudFormation names it at deploy time. NOT in ROLE-NAMES.md — see the
  // "beyond ROLE-NAMES.md" note at the bottom of this file.
  assetTypeProviderFramework: "asset-type-provider-framework-role",
  deletionPipelineStateMachine: "deletion-pipeline-state-machine-role",
  deletionPipelineDeleteSourcesFn: "deletion-pipeline-delete-sources-fn-role",
  deletionPipelineDeleteOntologyFn: "deletion-pipeline-delete-ontology-fn-role",
  deletionPipelineDeleteMetricsFn: "deletion-pipeline-delete-metrics-fn-role",
  deletionPipelineDeletePlatformFn: "deletion-pipeline-delete-platform-fn-role",
  deletionPipelineFinalizeFn: "deletion-pipeline-finalize-fn-role",
  deletionPipelineMarkFailedFn: "deletion-pipeline-mark-failed-fn-role",

  // ── Data sources ───────────────────────────────────────────────────
  sourcesApi: "sources-api-role",
  dbConnectorFn: "db-connector-fn-role",
  dbScanTriggerFn: "db-scan-trigger-fn-role",
  dbScanReaperFn: "db-scan-reaper-fn-role",
  dbScanStateMachine: "db-scan-state-machine-role",
  dbEnrichmentTaskDefExec: "db-enrichment-task-def-exec-role",
  dbEnrichmentTaskDefTask: "db-enrichment-task-def-task-role",
  federationProvisionerFn: "federation-provisioner-fn-role",
  federationProvisionerLfAdminOnEvent:
    "federation-provisioner-lf-admin-on-event-role",
  glueEventRescanFn: "glue-event-rescan-fn-role",
  bulkReviewWorkerFn: "bulk-review-worker-fn-role",
  sourceDeleteWorkerFn: "source-delete-worker-fn-role",
  sourcesPreProcessingFn: "sources-pre-processing-fn-role",
  sourcesDocIngestionTriggerFn: "sources-doc-ingestion-trigger-fn-role",
  sourcesDocIngestionStateMachine: "sources-doc-ingestion-state-machine-role",
  sourcesDocDeletionCleanupFn: "sources-doc-deletion-cleanup-fn-role",
  sourcesDocDeletionStateMachine: "sources-doc-deletion-state-machine-role",
  sourcesKgBuildTaskDefExec: "sources-kg-build-task-def-exec-role",
  sourcesKgBuildTaskDefTask: "sources-kg-build-task-def-task-role",

  // ── Ontology ───────────────────────────────────────────────────────
  apiProxyFn: "api-proxy-fn-role",
  ontologyTaskDefExec: "ontology-task-def-exec-role",
  ontologyTaskDefTask: "ontology-task-def-task-role",

  // ── VKG ────────────────────────────────────────────────────────────
  vkgReloadFn: "vkg-reload-fn-role",
  vkgTaskDefExec: "vkg-task-def-exec-role",
  vkgTaskDefTask: "vkg-task-def-task-role",

  // ── Serve ──────────────────────────────────────────────────────────
  agentCoreRuntimeExec: "agent-core-runtime-exec-role",
  aossSearchProxyFn: "aoss-search-proxy-fn-role",
  sessionMemory: "session-memory-role",

  // ── MCP ────────────────────────────────────────────────────────────
  mcpRuntimeExec: "mcp-runtime-exec-role",

  // ── Metrics ────────────────────────────────────────────────────────
  metricApiFn: "metric-api-fn-role",
  importWorkerFn: "import-worker-fn-role",
  importDlqRecoveryFn: "import-dlq-recovery-fn-role",
} as const;

/** A key of {@link ROLE_NAMES}. */
export type RoleKey = keyof typeof ROLE_NAMES;

/** Service principals that assume these roles. */
export const SERVICE_PRINCIPALS = {
  lambda: "lambda.amazonaws.com",
  ecsTasks: "ecs-tasks.amazonaws.com",
  states: "states.amazonaws.com",
  apigateway: "apigateway.amazonaws.com",
  bedrockAgentcore: "bedrock-agentcore.amazonaws.com",
  scheduler: "scheduler.amazonaws.com",
} as const;

export type ServicePrincipalKey = keyof typeof SERVICE_PRINCIPALS;

export interface RoleOptions {
  /** Extra trust principals beyond the primary service. */
  readonly additionalPrincipals?: iam.IPrincipal[];
  /** AWS managed policies to attach. Ignored in private mode. */
  readonly managedPolicies?: iam.IManagedPolicy[];
  /** Overrides the derived name. Only for roles outside the convention. */
  readonly roleName?: string;
  /** Description applied to a created role. */
  readonly description?: string;
  /**
   * Set when the Lambda is attached to a VPC, which additionally requires
   * `AWSLambdaVPCAccessExecutionRole` to manage its ENIs. CDK adds this
   * automatically to the role it creates implicitly; an explicit role has to
   * ask for it, and without it the function fails to initialize.
   */
  readonly inVpc?: boolean;
}

/**
 * The managed policies CDK attaches to the execution role it creates
 * implicitly. Reproduced here because passing an explicit `role:` opts out of
 * that behaviour entirely — omitting them leaves a Lambda unable to write its
 * own logs, which surfaces as a function that runs but logs nothing.
 */
/** IAM's hard limit on a role name. */
const IAM_ROLE_NAME_MAX_LENGTH = 64;

const LAMBDA_BASIC_EXECUTION =
  "service-role/AWSLambdaBasicExecutionRole" as const;
const LAMBDA_VPC_ACCESS =
  "service-role/AWSLambdaVPCAccessExecutionRole" as const;

/**
 * Per-stack factory for execution roles.
 *
 * Construct one per stack and call {@link forService} at each site that would
 * otherwise let CDK create a role implicitly.
 */
export class PvtVpcRoles {
  private readonly config: PvtVpcConfig;

  /**
   * @param scope the stack these roles belong to
   * @param config injected in tests; defaults to the on-disk config
   */
  constructor(
    private readonly scope: Construct,
    config?: PvtVpcConfig,
  ) {
    this.config = config ?? loadPvtVpcConfig(scope);
  }

  /** True when roles are imported rather than created. */
  get privateVpcMode(): boolean {
    return this.config.privateVpcMode;
  }

  /**
   * The `policy` prop for an `AwsCustomResource`, or undefined in private mode.
   *
   * `AwsCustomResourcePolicy` generates an `AWS::IAM::Policy` per custom
   * resource. That is right in standard mode, where CDK also created the role,
   * but in private mode the pre-created role already carries these permissions
   * and emitting the policy would need `iam:PutRolePolicy` — denied — and
   * would overwrite what the operator attached.
   *
   * CDK permits this: `policy` is required only when no `role` is supplied.
   * Call sites read:
   *
   *     new cr.AwsCustomResource(this, "Seed", {
   *       role: customResourceRole,
   *       ...(roles.customResourcePolicy(policy) ?? {}),
   *     });
   */
  customResourcePolicy<T>(policy: T): { policy: T } | undefined {
    return this.config.privateVpcMode ? undefined : { policy };
  }

  /** The full physical name of a role, e.g. `coa-dev-authorizer-fn-role`. */
  physicalName(key: RoleKey, override?: string): string {
    return override ?? prefixed(this.scope.node, ROLE_NAMES[key]);
  }

  /**
   * Import a role that is ALREADY declared with an explicit `roleName`, or
   * return undefined so the caller creates it as before.
   *
   * For the handful of roles built with `new iam.Role(...)` and a name of
   * their own — the catalog roles, the API Gateway invoke role — where there
   * is nothing to derive, only a create to suppress. Call sites read:
   *
   *     const role = roles.importNamed("smus-exec", "DomainExecutionRole")
   *       ?? new iam.Role(this, "DomainExecutionRole", { ... });
   *
   * @param unprefixedName the name as passed to `prefixed()`
   * @param logicalId      the construct id the created role would have used
   */
  importNamed(
    unprefixedName: string,
    logicalId: string,
  ): iam.IRole | undefined {
    if (!this.config.privateVpcMode) {
      return undefined;
    }
    const name = prefixed(this.scope.node, unprefixedName);
    return iam.Role.fromRoleArn(
      this.scope,
      logicalId,
      `arn:aws:iam::${this.config.account}:role/${name}`,
      { mutable: false },
    );
  }

  /**
   * The role for one construct.
   *
   * In standard mode this CREATES a named role; in private mode it IMPORTS
   * the pre-created one. The returned `IRole` is passed straight to the
   * construct's `role:` prop in both flows.
   *
   * @param key   the role, keyed into {@link ROLE_NAMES}
   * @param principal the service that assumes it
   */
  forService(
    key: RoleKey,
    principal: ServicePrincipalKey,
    options: RoleOptions = {},
  ): iam.IRole {
    const name = this.physicalName(key, options.roleName);
    // The logical id is derived from the role key, NOT from the owning
    // construct, so it stays stable if the construct is ever renamed.
    const logicalId = `${capitalize(key)}Role`;

    if (this.config.privateVpcMode) {
      // `mutable: false` makes the dropped-grant behaviour explicit rather
      // than depending on CDK's default, and guarantees no AWS::IAM::Policy
      // is emitted for a role whose permissions the operator already set.
      return iam.Role.fromRoleArn(
        this.scope,
        logicalId,
        `arn:aws:iam::${this.config.account}:role/${name}`,
        { mutable: false },
      );
    }

    // IAM caps a role name at 64 characters, and the convention requires EVERY
    // role to fit — so the binding limit is the LONGEST name's, not this
    // one's. Checked against that rather than against `name.length`: a short
    // role would otherwise synth happily under a prefix that makes the longest
    // role unsynthesisable, so which role failed would depend on construction
    // order. CDK's own error names only the offending role, leaving an
    // operator to work the arithmetic out from one of ~50 failures.
    const longest = Object.values(ROLE_NAMES).reduce((a, b) =>
      a.length >= b.length ? a : b,
    );
    const prefixLength = name.length - ROLE_NAMES[key].length;
    const budget = IAM_ROLE_NAME_MAX_LENGTH - longest.length;
    // Skipped for an explicit `roleName` override, where `name` is not
    // `{prefix}-{env}-{ROLE_NAMES[key]}` and the subtraction is meaningless.
    if (
      options.roleName === undefined &&
      prefixLength + longest.length > IAM_ROLE_NAME_MAX_LENGTH
    ) {
      throw new Error(
        `"{prefix}-{env}-" is ${prefixLength} characters, so the longest role ` +
          `name ("${longest}", ${longest.length} characters) would be ` +
          `${prefixLength + longest.length} — IAM allows ` +
          `${IAM_ROLE_NAME_MAX_LENGTH}. It must be at most ${budget} ` +
          "characters. Shorten the resource_prefix or env context value.",
      );
    }

    const principals = [
      new iam.ServicePrincipal(SERVICE_PRINCIPALS[principal]),
      ...(options.additionalPrincipals ?? []),
    ];

    // Reproduce what CDK's implicit role would have carried. Passing `role:`
    // opts out of that entirely, so these have to be requested explicitly or
    // the function cannot write logs (and, in a VPC, cannot start at all).
    const managedPolicies = [...(options.managedPolicies ?? [])];
    if (principal === "lambda") {
      managedPolicies.unshift(
        iam.ManagedPolicy.fromAwsManagedPolicyName(LAMBDA_BASIC_EXECUTION),
      );
      if (options.inVpc) {
        managedPolicies.push(
          iam.ManagedPolicy.fromAwsManagedPolicyName(LAMBDA_VPC_ACCESS),
        );
      }
    }

    return new iam.Role(this.scope, logicalId, {
      roleName: name,
      assumedBy:
        principals.length === 1
          ? principals[0]
          : new iam.CompositePrincipal(...principals),
      description: options.description,
      managedPolicies: managedPolicies.length > 0 ? managedPolicies : undefined,
    });
  }
}

/**
 * Write the permissions the synth would have attached, for the operator to
 * diff against the IAM package before deploying.
 *
 * Only meaningful in private mode, where every statement below was dropped.
 * Reads the SYNTHESIZED templates rather than hooking the grant calls, so it
 * reports what standard mode actually produces — the real contract — instead
 * of a reconstruction of it.
 *
 * @param templateDir  directory of `*.template.json` (normally `cdk.out`)
 * @param outFile      where to write the manifest
 * @returns the number of statements recorded
 */
export function writePermissionManifest(
  templateDir: string,
  outFile: string,
): number {
  const manifest: Record<string, unknown[]> = {};
  let count = 0;

  if (!fs.existsSync(templateDir)) {
    return 0;
  }

  for (const file of fs.readdirSync(templateDir)) {
    if (!file.endsWith(".template.json")) {
      continue;
    }
    let template: Record<string, unknown>;
    try {
      template = JSON.parse(
        fs.readFileSync(path.join(templateDir, file), "utf-8"),
      ) as Record<string, unknown>;
    } catch {
      // A partially written template is not worth failing the manifest over.
      continue;
    }

    const resources = (template.Resources ?? {}) as Record<
      string,
      { Type?: string; Properties?: Record<string, unknown> }
    >;

    // Logical id -> physical RoleName, so a policy can be reported against
    // the role an operator actually creates rather than against CDK's internal
    // logical id. Built per template because logical ids are stack-scoped.
    const roleNames = new Map<string, string>();
    for (const [logicalId, resource] of Object.entries(resources)) {
      if (resource.Type !== "AWS::IAM::Role") {
        continue;
      }
      const name = (resource.Properties ?? {}).RoleName;
      if (typeof name === "string") {
        roleNames.set(logicalId, name);
      }
    }

    for (const [logicalId, resource] of Object.entries(resources)) {
      if (
        resource.Type !== "AWS::IAM::Policy" &&
        resource.Type !== "AWS::IAM::Role"
      ) {
        continue;
      }
      const props = resource.Properties ?? {};
      // An inline policy on a Role, or a standalone Policy attached to one.
      const docs =
        resource.Type === "AWS::IAM::Policy"
          ? [props.PolicyDocument]
          : ((props.Policies ?? []) as { PolicyDocument?: unknown }[]).map(
              (p) => p.PolicyDocument,
            );

      for (const doc of docs) {
        const statements = ((doc as { Statement?: unknown[] })?.Statement ??
          []) as unknown[];
        if (statements.length === 0) {
          continue;
        }
        const key = `${file.replace(".template.json", "")}/${resolveRoleName(
          logicalId,
          resource,
          roleNames,
        )}`;
        // Append rather than assign: a role can carry both an inline policy
        // and one or more attached AWS::IAM::Policy resources, and keying by
        // role name now makes those collide.
        manifest[key] = [...(manifest[key] ?? []), ...statements];
        count += statements.length;
      }
    }
  }

  fs.mkdirSync(path.dirname(outFile), { recursive: true });
  fs.writeFileSync(
    outFile,
    JSON.stringify(
      {
        note: [
          "Permissions the STANDARD-mode synth attaches to each role.",
          "In private-VPC mode these are NOT attached — CDK drops them against",
          "an imported role without warning. Diff this against the IAM package",
          "before deploying: a statement missing there fails at runtime, not at",
          "deploy time.",
        ],
        statementCount: count,
        roles: manifest,
      },
      null,
      2,
    ),
  );

  return count;
}

function capitalize(value: string): string {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

/**
 * The physical role name a policy applies to, for the manifest's key.
 *
 * An operator diffs the manifest against the IAM package they used to create
 * the roles, so the key has to be the role NAME they created — not CDK's
 * logical id, which appears nowhere in their package.
 *
 * Falls back to the logical id when the name cannot be resolved: a role
 * referenced via `Fn::ImportValue` from another stack, or one whose name
 * CloudFormation still generates (the API Gateway CloudWatch role). A key that
 * needs interpreting beats dropping the statements silently.
 */
function resolveRoleName(
  logicalId: string,
  resource: { Type?: string; Properties?: Record<string, unknown> },
  roleNames: Map<string, string>,
): string {
  if (resource.Type === "AWS::IAM::Role") {
    return roleNames.get(logicalId) ?? logicalId;
  }
  // An AWS::IAM::Policy names its roles in `Roles`, each either a literal
  // name or a `{ "Ref": "<logical id>" }`.
  const roles = (resource.Properties ?? {}).Roles;
  if (!Array.isArray(roles) || roles.length === 0) {
    return logicalId;
  }
  const names = roles.map((entry): string | undefined => {
    if (typeof entry === "string") {
      return entry;
    }
    const ref = (entry as { Ref?: unknown }).Ref;
    return typeof ref === "string" ? roleNames.get(ref) : undefined;
  });
  // Only when every role resolved; a partial answer would be misleading.
  return names.every((n): n is string => n !== undefined)
    ? names.join("+")
    : logicalId;
}

/**
 * ## Roles beyond ROLE-NAMES.md
 *
 * `infra/pvt_vpc/ROLE-NAMES.md` lists the APPLICATION roles — the Lambdas, the
 * task definitions, the state machines. `ROLE_NAMES` above also covers roles
 * CDK would otherwise create for its own plumbing, which that document does
 * not mention because they belong to no service:
 *
 *   - `asset-type-provider-framework-role`      cr.Provider framework Lambda
 *   - `admin-user-provider-framework-role`      cr.Provider framework Lambda
 *   - `lakeformation-admin-framework-role`      cr.Provider framework Lambda
 *   - `authnz-custom-resource-role`             shared AwsCustomResource Lambda
 *   - `web-custom-resource-role`                shared AwsCustomResource Lambda
 *   - `web-bucket-deployment-role`              s3deploy.BucketDeployment
 *
 * They still need pre-creating: each is an `iam:CreateRole` the account
 * denies. The authoritative list is whatever a standard-mode synth puts in
 * `RoleName`, which is what `scripts/pvt-vpc-role-names.ts` prints — generated
 * from the code so it cannot drift from what the deploy looks for.
 *
 * Two more role sources are switched OFF in private mode rather than named,
 * because the construct accepts no role:
 *
 *   - `autoDeleteObjects` on a Bucket (storage, sources, metric-service,
 *     public-ui, access-logs). The operator empties those buckets by hand.
 *   - `cloudWatchRole` on SpecRestApi (api). API Gateway's account-level
 *     CloudWatch role is configured externally.
 *
 * `logRetention` was a third; it is replaced by an explicit `logs.LogGroup` in
 * both flows, which needs no role at all.
 */
