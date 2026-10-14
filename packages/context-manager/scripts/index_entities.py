# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Store a namespace's sectors table in the vector DB for Tier-2 entity resolution.

Manual entry point. The same build runs automatically on every ontology publish
(the entity-index Lambda, ``packages/context-manager/lambda/entity-index``); use
this script to rebuild by hand, e.g. after the sectors table changes without a
republish, or for a table/column layout the Lambda does not auto-detect.

Reads every company (id, name, sector, subsector) from the sectors table through
Athena, embeds one document per company and one per sector with the SAME Bedrock
embedding model serve uses for queries, and writes them to the namespace's entity
index (``{collection}-entities-{namespace}``). See ``coa_common.entity_index``.

``--recreate`` (default) rebuilds the index from scratch so renamed or removed
companies disappear.

The caller's AWS principal needs AOSS write access to the collection — deploy the
storage stack with ``--context aoss_writer_principal_arns=<your role/user ARN>``.

Example:
    uv run python packages/context-manager/scripts/index_entities.py \\
        --prefix cuedo --env dev \\
        --namespace 875df224-a277-40fd-a1e8-d115a8b1773b \\
        --database shravas_db_silver --table sectors
"""

from __future__ import annotations

import argparse
import json
import sys

import boto3
from coa_common import entity_vector_index_name
from coa_common.embeddings import BedrockEmbedder
from coa_common.entity_index import build_documents, read_sectors_table, write_entity_index
from coa_common.opensearch.client import AossVectorClient


def main(argv: list[str] | None = None) -> int:
    """Parse args, read the sectors table, embed, and (re)build the entity index."""
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--prefix", required=True, help="Resource prefix, e.g. cuedo")
    p.add_argument("--env", default="dev", help="Environment, e.g. dev")
    p.add_argument("--namespace", required=True, help="Namespace id the index belongs to")
    p.add_argument("--database", required=True, help="Glue database holding the sectors table")
    p.add_argument("--table", default="sectors", help="Sectors table name (default: sectors)")
    p.add_argument("--workgroup", help="Athena workgroup (default: <prefix>-<env>-<namespace>)")
    p.add_argument("--region", default=None, help="AWS region (default: session region)")
    p.add_argument("--id-column", default="company_id")
    p.add_argument("--name-column", default="company_name")
    p.add_argument("--sector-column", default="cd_sector")
    p.add_argument("--subsector-column", default="cd_subsector")
    p.add_argument(
        "--embed-model-id", help="Bedrock embedding model (default: bedrockEmbedModelId in /<prefix>/config)"
    )
    p.add_argument("--no-recreate", action="store_true", help="Append instead of rebuilding the index")
    p.add_argument("--dry-run", action="store_true", help="Read + build documents, print a sample, write nothing")
    args = p.parse_args(argv)

    session = boto3.Session(region_name=args.region)
    region = session.region_name or "us-east-1"
    ssm = session.client("ssm")

    collection = ssm.get_parameter(Name=f"/{args.prefix}/opensearch/collection-name")["Parameter"]["Value"]
    embed_model_id = args.embed_model_id or json.loads(
        ssm.get_parameter(Name=f"/{args.prefix}/config")["Parameter"]["Value"]
    ).get("bedrockEmbedModelId")
    details = session.client("opensearchserverless").batch_get_collection(names=[collection])["collectionDetails"]
    if not details:
        print(f"collection {collection} not found", file=sys.stderr)
        return 1
    endpoint = details[0]["collectionEndpoint"]
    index = entity_vector_index_name(collection, args.namespace)

    companies = read_sectors_table(
        session.client("athena"),
        database=args.database,
        table=args.table,
        workgroup=args.workgroup or f"{args.prefix}-{args.env}-{args.namespace}",
        columns={
            "id": args.id_column,
            "name": args.name_column,
            "sector": args.sector_column,
            "subsector": args.subsector_column,
        },
    )
    docs = build_documents(companies)
    n_sectors = sum(1 for _, d in docs if d["entity_type"] == "sector")
    print(f"read {len(companies)} companies, {n_sectors} sectors from {args.database}.{args.table}")
    if args.dry_run:
        for text, _ in docs[:5] + docs[-3:]:
            print("  ", text)
        print(f"dry run — would write {len(docs)} documents to {index}")
        return 0

    embedder = BedrockEmbedder(model_id=embed_model_id, region=region)
    aoss = AossVectorClient(endpoint=endpoint, region=region, dimensions=embedder.dimensions)
    written = write_entity_index(
        docs,
        embedder=embedder,
        aoss=aoss,
        index=index,
        namespace=args.namespace,
        embed_model_id=embed_model_id,
        recreate=not args.no_recreate,
        progress=lambda msg: print(f"  {msg}", flush=True),
    )
    print(f"done — {written} documents in {index} (embedding model {embed_model_id})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
