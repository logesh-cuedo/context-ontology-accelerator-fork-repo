// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import * as cdk from "aws-cdk-lib";
import * as s3 from "aws-cdk-lib/aws-s3";
import { Construct } from "constructs";
import { SCLConstruct } from "./scl-construct";
import { resolveContext } from "../context";
import { loadPvtVpcConfig } from "../pvt-vpc-config";

export interface AccessLogsBucketProps {
  /**
   * Unique-per-stack suffix for the bucket name. Required so multiple
   * access-log buckets across stacks don't collide on a shared name
   * (e.g. "storage-logs", "sources-logs").
   */
  readonly nameSuffix: string;

  /** Days to retain access logs before expiry. Default 90. */
  readonly retentionDays?: number;

  /**
   * Object ownership for the bucket. Leave unset (S3 default, ACLs disabled)
   * for S3 server access logging. Set `BUCKET_OWNER_PREFERRED` (ACLs enabled)
   * for buckets that receive CloudFront **legacy** standard logs, which are
   * delivered via a bucket ACL grant.
   */
  readonly objectOwnership?: s3.ObjectOwnership;
}

/**
 * Hardened S3 bucket used as the server-access-log **target** for other
 * buckets (S3 server access logging).
 *
 * Wire a source bucket to it with:
 *   serverAccessLogsBucket: accessLogs.bucket,
 *   serverAccessLogsPrefix: "<source-name>/",
 *
 * The bucket is intentionally **not** self-logging (that would create a
 * delivery loop), which is the accepted exception for a log-archive bucket.
 * CDK grants the S3 log-delivery service principal write access via the
 * bucket policy (ACL-free) when this bucket is referenced as a
 * serverAccessLogsBucket, so it is compatible with `enforceSSL` and
 * BlockPublicAccess.BLOCK_ALL.
 */
export class AccessLogsBucket extends SCLConstruct {
  public readonly bucket: s3.Bucket;

  constructor(scope: Construct, id: string, props: AccessLogsBucketProps) {
    super(scope, id);

    const stack = cdk.Stack.of(this);
    const isProd = resolveContext(this.node).envName === "prod";

    this.bucket = new s3.Bucket(this, "Bucket", {
      bucketName: cdk.Lazy.string({
        produce: () => `${this.prefixed(props.nameSuffix)}-${stack.account}`,
      }),
      encryption: s3.BucketEncryption.S3_MANAGED,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      enforceSSL: true,
      versioned: false,
      objectOwnership: props.objectOwnership,
      lifecycleRules: [
        {
          id: "expire-access-logs",
          enabled: true,
          expiration: cdk.Duration.days(props.retentionDays ?? 90),
        },
      ],
      removalPolicy: isProd
        ? cdk.RemovalPolicy.RETAIN
        : cdk.RemovalPolicy.DESTROY,
      // autoDeleteObjects provisions a custom resource WITH ITS OWN ROLE,
      // named by CloudFormation at deploy time, so it cannot be pre-created in
      // a locked-down account.
      autoDeleteObjects: !isProd && !loadPvtVpcConfig(this).privateVpcMode,
    });
  }
}
