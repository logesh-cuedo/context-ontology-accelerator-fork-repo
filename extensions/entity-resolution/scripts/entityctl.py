# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Operator CLI for the entity-resolution extension.

    entityctl.py config put  --prefix cuedo FILE [--namespace ID]   validate + store a config
    entityctl.py config get  --prefix cuedo [--namespace ID]        print the effective config
    entityctl.py build       --prefix cuedo --namespace ID          rebuild one index (locally)
    entityctl.py invoke      --prefix cuedo --namespace ID          rebuild via the deployed Lambda
    entityctl.py status      --prefix cuedo --namespace ID          show the active index version
    entityctl.py sweep       --prefix cuedo                         delete orphaned/stale indexes

``config put`` without ``--namespace`` writes the deployment default
(``/<prefix>/entities/default``). A namespace override wins over the default.

Run from the repo root, e.g.:
    PYTHONPATH=extensions/entity-resolution/src uv run python \\
        extensions/entity-resolution/scripts/entityctl.py config put --prefix cuedo \\
        extensions/entity-resolution/entities.sample.json
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import boto3

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from coa_entity.config import DEFAULT_PARAMETER, load_config, parameter_name, parse_config  # noqa: E402


def _config_put(args: argparse.Namespace, session: boto3.Session) -> int:
    text = Path(args.file).read_text()
    parse_config(text)  # raises EntityConfigError with the exact problem
    name = parameter_name(f"/{args.prefix}", args.namespace or DEFAULT_PARAMETER)
    session.client("ssm").put_parameter(Name=name, Value=json.dumps(json.loads(text)), Type="String", Overwrite=True)
    print(f"stored {name} — republish the ontology (or run 'invoke') to rebuild the index")
    return 0


def _config_get(args: argparse.Namespace, session: boto3.Session) -> int:
    config = load_config(session.client("ssm"), f"/{args.prefix}", args.namespace or "")
    if config is None:
        print("no entity config (feature off for this namespace)")
        return 1
    for spec in config.entity_types:
        print(f"{spec.type}: {spec.table}.{spec.name_column} (id {spec.id_column}, filter {spec.sql_column})")
        for g in spec.groups:
            print(f"  group {g.type}: {g.column} (filter {g.sql_column})")
    return 0


def _lambda_env(args: argparse.Namespace, session: boto3.Session) -> None:
    """Point coa_entity.lambda_handler at the deployment, as the Lambda's own env does."""
    ssm = session.client("ssm")

    def param(name: str) -> str:
        return ssm.get_parameter(Name=f"/{args.prefix}/{name}")["Parameter"]["Value"]

    os.environ.update(
        {
            "SSM_PREFIX": f"/{args.prefix}",
            "OSS_ENDPOINT": param("opensearch/endpoint"),
            "OSS_COLLECTION_NAME": param("opensearch/collection-name"),
            "NAMESPACES_TABLE": param("namespace/namespaces-table-name"),
            "DATA_SOURCES_TABLE": f"{args.prefix}-{args.env}-sources",
            "ATHENA_WORKGROUP_PREFIX": f"{args.prefix}-{args.env}-",
            "AWS_REGION": session.region_name or "us-east-1",
            "ENTITY_BUCKET": f"{args.prefix}-{args.env}-ontology-artifacts-"
            + session.client("sts").get_caller_identity()["Account"],
        }
    )


def _build(args: argparse.Namespace, session: boto3.Session) -> int:
    _lambda_env(args, session)
    from coa_entity.lambda_handler import build

    result = build(args.namespace)
    print(json.dumps(result, indent=2))
    return 0 if result.get("status") == "built" else 1


def _status(args: argparse.Namespace, session: boto3.Session) -> int:
    from coa_entity.active import read_pointer

    pointer = read_pointer(session.client("ssm"), f"/{args.prefix}", args.namespace)
    if pointer is None:
        print("no versioned index yet (serve uses the legacy index name, without name matching)")
        return 1
    print(json.dumps({"index": pointer.index, "names": pointer.names_uri, "version": pointer.version}, indent=2))
    return 0


def _sweep(args: argparse.Namespace, session: boto3.Session) -> int:
    _lambda_env(args, session)
    from coa_entity.lambda_handler import sweep

    print(json.dumps(sweep(), indent=2))
    return 0


def _invoke(args: argparse.Namespace, session: boto3.Session) -> int:
    from botocore.config import Config

    client = session.client("lambda", config=Config(read_timeout=960))
    resp = client.invoke(
        FunctionName=f"{args.prefix}-{args.env}-entity-ext-index",
        Payload=json.dumps({"action": "build", "namespace": args.namespace}).encode(),
    )
    result = json.loads(resp["Payload"].read() or b"{}")
    print(json.dumps(result, indent=2))
    return 0 if result.get("status") == "built" else 1


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--region", default=None)
    sub = p.add_subparsers(dest="command", required=True)

    def common(sp: argparse.ArgumentParser, *, namespace: str = "optional") -> None:
        sp.add_argument("--prefix", required=True, help="Resource prefix, e.g. cuedo")
        sp.add_argument("--env", default="dev")
        if namespace == "required":
            sp.add_argument("--namespace", required=True)
        elif namespace == "optional":
            sp.add_argument("--namespace", default="", help="Namespace id (omit for the default)")

    cfg = sub.add_parser("config", help="store or show the entity config").add_subparsers(dest="op", required=True)
    put = cfg.add_parser("put")
    common(put)
    put.add_argument("file")
    put.set_defaults(fn=_config_put)
    get = cfg.add_parser("get")
    common(get)
    get.set_defaults(fn=_config_get)

    b = sub.add_parser("build", help="rebuild one namespace's index from this machine")
    common(b, namespace="required")
    b.set_defaults(fn=_build)
    inv = sub.add_parser("invoke", help="rebuild one namespace's index via the deployed Lambda")
    common(inv, namespace="required")
    inv.set_defaults(fn=_invoke)
    st = sub.add_parser("status", help="show a namespace's active index version")
    common(st, namespace="required")
    st.set_defaults(fn=_status)
    sw = sub.add_parser("sweep", help="delete indexes of deleted namespaces and stale versions")
    common(sw, namespace="none")
    sw.set_defaults(fn=_sweep)

    args = p.parse_args(argv)
    return args.fn(args, boto3.Session(region_name=args.region))


if __name__ == "__main__":
    sys.exit(main())
