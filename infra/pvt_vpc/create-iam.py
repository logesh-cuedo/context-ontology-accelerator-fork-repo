"""Create the pre-created IAM the private-VPC deployment imports.

Reads pvt_vpc/iam-package/ and creates, in the caller's account:

  * 2 customer-managed policies
  * 64 roles, each with its trust policy, its AWS-managed policy attachments
    and its inline policy

Creates only. It never deletes or modifies anything that already exists: a
name that is already present is reported and skipped, so an interrupted run
can simply be repeated.

Run with --dry-run first. Nothing is sent to AWS in that mode.

    python3 create-iam.py --dry-run
    python3 create-iam.py
"""

import argparse
import json
import pathlib
import sys

import boto3
from botocore.exceptions import ClientError

PACKAGE = pathlib.Path(__file__).parent / "iam-package"


def substitute(obj, account: str, region: str):
    """Replace the package's two placeholders throughout a JSON document."""
    if isinstance(obj, dict):
        return {k: substitute(v, account, region) for k, v in obj.items()}
    if isinstance(obj, list):
        return [substitute(v, account, region) for v in obj]
    if isinstance(obj, str):
        return obj.replace("${AccountId}", account).replace("${Region}", region)
    return obj


def main() -> int:
    """Create the package's roles and policies in the caller's account."""
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--package", default=str(PACKAGE))
    args = ap.parse_args()

    pkg = pathlib.Path(args.package)
    roles_dir = pkg / "roles"
    mp_dir = pkg / "managed-policies"
    if not roles_dir.is_dir():
        print(f"no roles/ under {pkg}", file=sys.stderr)
        return 2

    iam = boto3.client("iam")
    account = boto3.client("sts").get_caller_identity()["Account"]
    region = boto3.session.Session().region_name or "us-east-1"

    print(f"account {account}  region {region}")
    print(f"package {pkg}")
    if args.dry_run:
        print("DRY RUN — nothing will be sent to AWS")
    print()

    created = skipped = failed = 0

    # ── customer-managed policies first: a role may attach one ──────────
    for path in sorted(mp_dir.glob("*.policy.json")):
        name = path.name[: -len(".policy.json")]
        doc = substitute(json.load(path.open()), account, region)
        if args.dry_run:
            print(f"  would create policy  {name}")
            created += 1
            continue
        try:
            iam.create_policy(PolicyName=name, PolicyDocument=json.dumps(doc))
            print(f"  created policy       {name}")
            created += 1
        except ClientError as err:
            if err.response["Error"]["Code"] == "EntityAlreadyExists":
                print(f"  exists, skipped      {name}")
                skipped += 1
            else:
                print(f"  FAILED policy        {name}: {err}")
                failed += 1

    # ── roles ───────────────────────────────────────────────────────────
    for path in sorted(roles_dir.glob("*.json")):
        spec = substitute(json.load(path.open()), account, region)
        name = spec["roleName"]
        trust = json.dumps(spec["trustPolicy"])
        managed = spec.get("managedPolicyArns") or []
        inline = spec.get("inlinePolicy") or {}
        statements = inline.get("Statement") or []

        if args.dry_run:
            print(f"  would create role    {name:52} managed={len(managed)} inline={len(statements)}")
            created += 1
            continue

        try:
            iam.create_role(
                RoleName=name,
                AssumeRolePolicyDocument=trust,
                Description=spec.get("description") or "",
                Tags=[{"Key": "ManagedBy", "Value": "coa-private-vpc-package"}],
            )
            print(f"  created role         {name}")
            created += 1
        except ClientError as err:
            if err.response["Error"]["Code"] == "EntityAlreadyExists":
                print(f"  exists, skipped      {name}")
                skipped += 1
                continue
            print(f"  FAILED role          {name}: {err}")
            failed += 1
            continue

        # Attachments are separate calls; a failure here leaves a role with
        # no permissions, which fails at RUNTIME rather than here — so each
        # one is reported individually.
        for arn in managed:
            try:
                iam.attach_role_policy(RoleName=name, PolicyArn=arn)
            except ClientError as err:
                print(f"    FAILED attach      {arn}: {err}")
                failed += 1

        if statements:
            try:
                iam.put_role_policy(
                    RoleName=name,
                    PolicyName=f"{name}-inline",
                    PolicyDocument=json.dumps(inline),
                )
            except ClientError as err:
                print(f"    FAILED inline      {name}: {err}")
                failed += 1

    print()
    print(f"created {created}   skipped {skipped}   failed {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
