# Entity resolution extension (cuedo-ext)

Generic Tier-2 entity resolution for serve. Before NL→SQL runs, the question's
named entities (companies, sectors, products, customers — whatever you
configure) are matched against a per-namespace vector index:

| Outcome | What the user sees |
|---|---|
| found | the query runs with exact filters (`LOWER(company_name) LIKE '%bajaj auto ltd.%'`) |
| ambiguous | a numbered list — "Reply with the number or the name." |
| not_found | "I couldn't find **x** … Did you mean one of these?" |
| no entity named / index missing | the query runs with generic LIKE filter rules |

Everything lives in this folder plus three small, marked (`cuedo-ext`) folders
or hook points elsewhere — see [Upstream touch points](#upstream-touch-points).

## Companies and sectors — one path

Every configured kind (an entity type such as `company`, or a group such as
`sector`) is resolved the same way:

- **Candidates** = vector search ∪ name matching (`lexical.py`: words, acronyms
  like TCS / L&T, prefixes like automo…, typos). The name list is written by
  each index build to `s3://<ontology bucket>/entities/<ns>/v<version>.json`.
- **Clarification** for ambiguous / unknown names, with numbered options; a group
  kind (sector) also offers **All of these**.
- **Replies**: `2`, `2.`, `#2`, `1,4`, `all`, or an option's name are matched to
  the listed options exactly (no model guess); a reply that is itself a new
  question is treated as a new question.
- **SQL**: companies → `LOWER(company_name) LIKE '%<full name>%'` (+ the company's
  sector with `filterWithMember`); sectors → `sector IN (...)` (the `sectors`
  table itself uses `cd_sector`). Nothing resolved → generic LIKE rules.

## Configure (no redeploy)

What counts as an entity is a JSON document in SSM:

```
/<prefix>/entities/default         used by every namespace
/<prefix>/entities/<namespace-id>  optional per-namespace override
```

No parameter → the feature is off for that namespace. Schema and field
meanings: `src/coa_entity/config.py`. Example: `entities.sample.json`.

```bash
# validate + store the default (run from the repo root)
PYTHONPATH=extensions/entity-resolution/src uv run python \
  extensions/entity-resolution/scripts/entityctl.py config put --prefix cuedo \
  extensions/entity-resolution/entities.sample.json

# show the effective config for a namespace
... entityctl.py config get --prefix cuedo --namespace <id>
```

Serve picks up a config change within ~5 minutes; the index is rebuilt on the
next ontology publish (or run `entityctl.py invoke`).

## How the index is built

`coa_entity.lambda_handler` (Lambda `<prefix>-<env>-entity-ext-index`):

- **On `ontology.published`** — reads the namespace's config, finds each
  configured table in the namespace's Glue sources (or the pinned `database`),
  reads it through the namespace's Athena workgroup, embeds one document per
  entity and per group value with serve's embedding model
  (`bedrockEmbedModelId` in `/<prefix>/config`), and rebuilds
  `<collection>-entities-<namespace>`.
- Each build writes a **new index version** (`…-entities-<ns>-v<ts>`), then the
  name list, then switches the active pointer `/<prefix>/entities/_active/<ns>`;
  serve keeps using the previous version until the new one is complete.
- **Daily** — deletes indexes of deleted namespaces and superseded versions.

Fail-open: no config, a missing table/column or a read error is logged and
skipped.

Manual runs:

```bash
entityctl.py invoke --prefix cuedo --namespace <id>   # via the deployed Lambda (~5 min)
entityctl.py build  --prefix cuedo --namespace <id>   # from this machine (slow; needs
                                                      # aoss_writer_principal_arns)
entityctl.py status --prefix cuedo --namespace <id>   # active index version
entityctl.py sweep  --prefix cuedo
```

**Lake Formation:** the Lambda reads with its own role. That works when the
tables allow IAM access (`IAM_ALLOWED_PRINCIPALS`); in strict-LF accounts grant
the Lambda role `SELECT` on the entity tables.

## Layout

```
extensions/entity-resolution/
  src/coa_entity/
    config.py          config schema + SSM lookup
    index_builder.py   Athena read → documents → embed → AOSS
    resolver.py        candidates → LLM pick → clarification / SQL section / resume
    lexical.py         name matching (words, acronyms, prefixes, typos)
    active.py          active index-version pointer (SSM)
    serve_hook.py      the object serve's orchestrator calls
    lambda_handler.py  build-on-publish + daily sweep
  scripts/entityctl.py operator CLI
  entity_tests/        pytest suite (run: .venv/bin/python -m pytest extensions/entity-resolution/entity_tests)
  entities.sample.json
infra/lib/stacks/extensions/entity-resolution-stack.ts   CDK stack <prefix>-<env>-entity-ext
infra/test/extensions/                                   its CDK tests
packages/web-app/src/extensions/entity-resolution.ts     the step's label / summary in Rationale
```

## Upstream touch points

All marked `cuedo-ext`; each is optional at runtime (serve runs unchanged
without the package). Re-apply these after an upstream sync if they conflict.

| File | Hook |
|---|---|
| `packages/context-manager/src/coa_serve/main.py` | guarded import + `entity_hook=` |
| `packages/context-manager/src/coa_serve/orchestrator.py` | `entity_hook` kwarg; resume + before-Tier-2 call |
| `packages/context-manager/src/coa_serve/tier2/nl_to_sql/sql_generator.py`, `strategy.py` | `entities` prompt-section passthrough |
| `packages/context-manager/Dockerfile`, `.dockerignore` | install this package last (`--no-deps`) |
| `infra/bin/app.ts` | instantiate `EntityResolutionStack` |
| `packages/web-app/src/components/Chat/step-labels.ts`, `RationalePanel/format-step-detail.ts`, `RationalePanel/RationalePanel.tsx` | import the step label / formatter / lead-in set |

After a serve deploy, the Playground keeps its AgentCore runtime session (one per
user, idle timeout 15 min), so new serve code reaches a user after ~15 minutes
idle.

Deploy: `cdk deploy <prefix>-<env>-entity-ext` for the Lambda; serve
(`<prefix>-<env>-serve`) and web (`<prefix>-<env>-web`) only when their hooks or
this package change.
