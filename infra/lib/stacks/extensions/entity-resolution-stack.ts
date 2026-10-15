// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

/**
 * cuedo-ext: generic Tier-2 entity resolution (extensions/entity-resolution).
 *
 * A self-contained stack — upstream stacks are not modified. It owns:
 *   - the entity-index Lambda (`{prefix}-entity-ext-index`), which
 *       • rebuilds a namespace's entity index on every `ontology.published`
 *       • deletes indexes of deleted namespaces on a daily sweep
 *   - AOSS data-access policies: the Lambda's write access, plus optional
 *     write access for operators (`aoss_writer_principal_arns` context) who
 *     run `extensions/entity-resolution/scripts/entityctl.py build`.
 *
 * Which tables/columns are entities is NOT configured here: it is read at run
 * time from SSM `{ssmPrefix}/entities/{namespace|default}` (see the README), so
 * it changes without a redeploy. Serve reads the same parameter; serve's role
 * already has ssm:GetParameter on `{ssmPrefix}/*` and AOSS read access via the
 * search proxy, so nothing in ServeStack changes.
 *
 * Data access: the Lambda reads the entity tables through Athena with its own
 * role. That works where the tables are IAM-governed (IAM_ALLOWED_PRINCIPALS)
 * or the role holds a Lake Formation SELECT grant; it is deliberately NOT given
 * the discovery connector's LF self-grant path.
 */
import * as cdk from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as events from "aws-cdk-lib/aws-events";
import * as targets from "aws-cdk-lib/aws-events-targets";
import * as iam from "aws-cdk-lib/aws-iam";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as opensearchserverless from "aws-cdk-lib/aws-opensearchserverless";
import * as ssm from "aws-cdk-lib/aws-ssm";
import { Construct } from "constructs";
import type { IAlarmActionStrategy } from "cdk-monitoring-constructs/lib/common/alarm/action";
import { TABLE_NAMES } from "@coa/shared";
import { BRAND } from "../../constants";
import { resolveContext } from "../../context";
import { SCLStack, SclMonitoring } from "../../constructs";
import { fromRoot } from "../../paths";
import { bundlePython } from "../../utils/python-bundling";

export interface EntityResolutionStackProps extends cdk.StackProps {
  readonly vpc: ec2.IVpc;
  readonly lambdaSecurityGroup: ec2.ISecurityGroup;
  /** Athena query-results bucket the namespace workgroups write to. */
  readonly athenaResultsBucketName?: string;
  readonly alarmAction?: IAlarmActionStrategy;
}

export class EntityResolutionStack extends SCLStack {
  public readonly indexFunction: lambda.Function;

  constructor(scope: Construct, id: string, props: EntityResolutionStackProps) {
    super(scope, id, props);

    const region = cdk.Stack.of(this).region;
    const account = cdk.Stack.of(this).account;
    const { ssmPrefix, eventSourcePrefix } = resolveContext(this.node);

    const param = (name: string) =>
      ssm.StringParameter.valueForStringParameter(this, `${ssmPrefix}/${name}`);
    const collectionName = param("opensearch/collection-name");
    const collectionArn = param("opensearch/collection-arn");
    const namespacesTableName = param("namespace/namespaces-table-name");
    const sourcesTableName = this.prefixed(TABLE_NAMES.SOURCES);
    const resultsBucket =
      props.athenaResultsBucketName ?? this.prefixed("athena-results");

    const code = bundlePython({
      srcDirs: [
        fromRoot("extensions/entity-resolution/src"),
        fromRoot("libs/common/src"),
      ],
      pipDeps: [
        "opensearch-py",
        "requests-aws4auth",
        "cedarpy",
        "cryptography",
        "pydantic-settings",
        "PyJWT",
        "requests",
        "structlog",
      ],
      architecture: "arm64",
    });

    const fn = new lambda.Function(this, "EntityIndexFn", {
      functionName: this.prefixed("entity-ext-index"),
      runtime: lambda.Runtime.PYTHON_3_12,
      architecture: lambda.Architecture.ARM_64,
      handler: "coa_entity.lambda_handler.handler",
      code,
      // ~8k entities embed in ~5 min from inside the region; the ceiling leaves
      // headroom for larger entity tables.
      timeout: cdk.Duration.minutes(15),
      memorySize: 1024,
      environment: {
        OSS_ENDPOINT: param("opensearch/endpoint"),
        OSS_COLLECTION_NAME: collectionName,
        DATA_SOURCES_TABLE: sourcesTableName,
        NAMESPACES_TABLE: namespacesTableName,
        ATHENA_WORKGROUP_PREFIX: this.prefixed(""),
        SSM_PREFIX: ssmPrefix,
      },
      vpc: props.vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
      securityGroups: [props.lambdaSecurityGroup],
    });
    this.indexFunction = fn;

    fn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["dynamodb:GetItem", "dynamodb:Query"],
        resources: [
          `arn:aws:dynamodb:${region}:${account}:table/${sourcesTableName}`,
          `arn:aws:dynamodb:${region}:${account}:table/${namespacesTableName}`,
        ],
      }),
    );
    fn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["ssm:GetParameter"],
        resources: [
          `arn:aws:ssm:${region}:${account}:parameter${ssmPrefix}/config`,
          `arn:aws:ssm:${region}:${account}:parameter${ssmPrefix}/entities/*`,
        ],
      }),
    );
    fn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["bedrock:InvokeModel"],
        resources: [
          `arn:aws:bedrock:*:${account}:inference-profile/*`,
          `arn:aws:bedrock:*::foundation-model/*`,
        ],
      }),
    );
    fn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:GetWorkGroup",
        ],
        resources: [
          `arn:aws:athena:${region}:${account}:workgroup/${this.prefixed("")}*`,
        ],
      }),
    );
    fn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions",
          "glue:GetUnfilteredTableMetadata",
          "glue:GetUnfilteredPartitionMetadata",
        ],
        resources: [
          `arn:aws:glue:${region}:${account}:catalog`,
          `arn:aws:glue:${region}:${account}:database/*`,
          `arn:aws:glue:${region}:${account}:table/*/*`,
        ],
      }),
    );
    // lakeformation:GetDataAccess does not support resource-level restrictions.
    fn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["lakeformation:GetDataAccess"],
        resources: ["*"],
      }),
    );
    fn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
        ],
        resources: [
          `arn:aws:s3:::${resultsBucket}`,
          `arn:aws:s3:::${resultsBucket}/*`,
        ],
      }),
    );
    fn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["aoss:APIAccessAll"],
        resources: [collectionArn],
      }),
    );

    // AOSS data access: entity indexes only — never ontology, metric or GraphRAG.
    const entityIndexes = `index/${collectionName}/${collectionName}-entities-*`;
    const writerRules = [
      {
        ResourceType: "index",
        Resource: [entityIndexes],
        Permission: [
          "aoss:CreateIndex",
          "aoss:DeleteIndex",
          "aoss:UpdateIndex",
          "aoss:DescribeIndex",
          "aoss:ReadDocument",
          "aoss:WriteDocument",
        ],
      },
    ];
    // Names deliberately differ from the pre-extension policies
    // ("entity-index-writer" / "entity-index-lambda") so this stack can be
    // created while those still exist.
    new opensearchserverless.CfnAccessPolicy(this, "EntityIndexLambdaAccess", {
      name: this.prefixed("entity-ext-lambda"),
      type: "data",
      description:
        "Entity-index Lambda: rebuild/sweep per-namespace entity indexes",
      policy: JSON.stringify([
        { Rules: writerRules, Principal: [fn.role!.roleArn] },
      ]),
    });

    const operatorArns = (
      (this.node.tryGetContext("aoss_writer_principal_arns") as
        | string
        | undefined) ?? ""
    )
      .split(",")
      .map((arn) => arn.trim())
      .filter((arn) => arn.length > 0);
    if (operatorArns.length > 0) {
      new opensearchserverless.CfnAccessPolicy(
        this,
        "EntityIndexOperatorAccess",
        {
          name: this.prefixed("entity-ext-operators"),
          type: "data",
          description: "Operator write access to entity indexes (entityctl.py)",
          policy: JSON.stringify([
            { Rules: writerRules, Principal: operatorArns },
          ]),
        },
      );
    }

    // Same event (and source pair) as VKG's OntologyPublishedRule — see
    // vkg-stack.ts for why the legacy static source is matched too.
    const legacySource = `${BRAND}.ontology`;
    const scopedSource = `${eventSourcePrefix}.ontology`;
    new events.Rule(this, "BuildOnPublishRule", {
      ruleName: this.prefixed("entity-ext-on-publish"),
      eventPattern: {
        source:
          scopedSource === legacySource
            ? [scopedSource]
            : [scopedSource, legacySource],
        detailType: ["ontology.published"],
      },
      targets: [
        new targets.LambdaFunction(fn, {
          maxEventAge: cdk.Duration.hours(1),
          // A rebuild drops and recreates the index, so a retry is safe.
          retryAttempts: 1,
        }),
      ],
    });

    // Deleted namespaces leave their entity index behind (namespace teardown is
    // upstream code and is not modified); sweep them daily. The AOSS collection
    // caps the number of indexes, so orphans must not accumulate.
    new events.Rule(this, "SweepScheduleRule", {
      ruleName: this.prefixed("entity-ext-sweep"),
      schedule: events.Schedule.rate(cdk.Duration.days(1)),
      targets: [new targets.LambdaFunction(fn, { retryAttempts: 1 })],
    });

    new SclMonitoring(this, "Monitoring", {
      alarmNamePrefix: this.prefixed("entity-ext"),
      alarmAction: props.alarmAction,
    }).monitorLambda(fn);
  }
}
