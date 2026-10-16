"""Delete the IAM that create-iam.py made, and nothing else.

Two independent safety conditions, both required before a role is touched:

  * its name appears in pvt_vpc/iam-package/roles/
  * it carries the tag ManagedBy=coa-private-vpc-package, written by
    create-iam.py

A role matching only one of those is reported and left alone. That is what
keeps a live deployment's roles — cuedo-dev's, or anything else sharing the
account — out of reach even if a name were to collide.

IAM also refuses to delete a role that still has policies attached, so each
role is stripped first: detach managed, delete inline, then delete the role.

    python3 delete-iam.py --dry-run
    python3 delete-iam.py --yes
"""

import argparse
import pathlib
import sys

import boto3
from botocore.exceptions import ClientError

PACKAGE = pathlib.Path(__file__).parent / "iam-package"
TAG_KEY, TAG_VALUE = "ManagedBy", "coa-private-vpc-package"


def main() -> int:
    """Delete only what create-iam.py made, verified two ways."""
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--yes", action="store_true", help="required for a real deletion")
    ap.add_argument("--package", default=str(PACKAGE))
    args = ap.parse_args()

    if not args.dry_run and not args.yes:
        print("refusing to delete without --yes (or use --dry-run)")
        return 2

    pkg = pathlib.Path(args.package)
    expected = {p.stem for p in (pkg / "roles").glob("*.json")}
    policies = {p.name[: -len(".policy.json")] for p in (pkg / "managed-policies").glob("*.policy.json")}
    if not expected:
        print(f"no roles under {pkg}/roles — refusing to proceed")
        return 2

    iam = boto3.client("iam")
    account = boto3.client("sts").get_caller_identity()["Account"]
    print(f"account {account}")
    print(f"package names: {len(expected)} roles, {len(policies)} policies")
    if args.dry_run:
        print("DRY RUN — nothing will be deleted")
    print()

    deleted = skipped = failed = 0

    for name in sorted(expected):
        try:
            role = iam.get_role(RoleName=name)["Role"]
        except ClientError as err:
            if err.response["Error"]["Code"] == "NoSuchEntity":
                continue
            print(f"  FAILED lookup   {name}: {err}")
            failed += 1
            continue

        tags = {t["Key"]: t["Value"] for t in role.get("Tags", [])}
        if tags.get(TAG_KEY) != TAG_VALUE:
            # Same name, but this script did not create it. Leave it.
            print(f"  NOT OURS, kept  {name}  (no {TAG_KEY}={TAG_VALUE} tag)")
            skipped += 1
            continue

        if args.dry_run:
            print(f"  would delete    {name}")
            deleted += 1
            continue

        try:
            for p in iam.list_attached_role_policies(RoleName=name)["AttachedPolicies"]:
                iam.detach_role_policy(RoleName=name, PolicyArn=p["PolicyArn"])
            for p in iam.list_role_policies(RoleName=name)["PolicyNames"]:
                iam.delete_role_policy(RoleName=name, PolicyName=p)
            iam.delete_role(RoleName=name)
            print(f"  deleted         {name}")
            deleted += 1
        except ClientError as err:
            print(f"  FAILED          {name}: {err}")
            failed += 1

    # Customer-managed policies: every non-default version must go first.
    for name in sorted(policies):
        arn = f"arn:aws:iam::{account}:policy/{name}"
        try:
            iam.get_policy(PolicyArn=arn)
        except ClientError as err:
            if err.response["Error"]["Code"] == "NoSuchEntity":
                continue
            print(f"  FAILED lookup   {name}: {err}")
            failed += 1
            continue

        if args.dry_run:
            print(f"  would delete    {name} (policy)")
            deleted += 1
            continue

        try:
            for v in iam.list_policy_versions(PolicyArn=arn)["Versions"]:
                if not v["IsDefaultVersion"]:
                    iam.delete_policy_version(PolicyArn=arn, VersionId=v["VersionId"])
            for e in iam.list_entities_for_policy(PolicyArn=arn)["PolicyRoles"]:
                iam.detach_role_policy(RoleName=e["RoleName"], PolicyArn=arn)
            iam.delete_policy(PolicyArn=arn)
            print(f"  deleted         {name} (policy)")
            deleted += 1
        except ClientError as err:
            print(f"  FAILED          {name}: {err}")
            failed += 1

    print()
    print(f"deleted {deleted}   kept {skipped}   failed {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
