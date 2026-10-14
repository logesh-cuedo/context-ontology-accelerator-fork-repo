#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Pause / resume the always-on compute of a dev environment overnight WITHOUT
# destroying anything: no data is lost, no endpoint or URL changes, no redeploy.
#
#   sleep   1. Scale every ECS service in the ontology and VKG clusters to 0.
#              The per-namespace VKG services carry an Application Auto Scaling
#              target with MinCapacity=1 (infra/lambda/vkg-reload/index.py), which
#              would put a task straight back — so their floor is lowered to 0 too.
#              The desired count and floor in force are saved as service tags
#              (coa:wake-desired / coa:wake-min) for `wake` to restore.
#           2. Stop the Neptune cluster (storage kept; only storage is billed).
#   wake    1. Start Neptune and wait until it is available (~5-10 min) — the
#              ontology engine and VKG talk to it as soon as they start.
#           2. Restore each ECS service's floor and desired count, then wait for
#              the services to become stable.
#   status  Show Neptune's state and each service's desired / running count.
#
# Not covered, deliberately:
#   - OpenSearch Serverless has no stop. Deploy with SCL_AOSS_MIN_OCU=0 so the
#     collection scales its OCUs to zero by itself when idle.
#   - AgentCore Runtimes and Lambdas bill per use, so they cost nothing idle.
#   - The NAT gateway and interface VPC endpoints bill hourly but can only be
#     removed by destroying the network stack.
#
# AWS restarts a stopped Neptune cluster on its own after 7 days. Run `wake`
# before any `make deploy-dev`: CloudFormation cannot update a stopped cluster.
#
# Usage: scripts/dev-power.sh {sleep|wake|status} [env]
#        SCL_PREFIX (default coa) selects the resource prefix, as in deploy.sh.
set -uo pipefail

ACTION="${1:-}"
ENV="${2:-dev}"
REGION="${CDK_DEFAULT_REGION:-${AWS_DEFAULT_REGION:-${AWS_REGION:-us-east-1}}}"
# Default MUST match the CDK app's DEFAULT_RESOURCE_PREFIX (see destroy.sh).
PREFIX="${SCL_PREFIX:-coa}"
STACK_PREFIX="${PREFIX}-${ENV}"
NEPTUNE_CLUSTER="${STACK_PREFIX}-neptune"
ECS_CLUSTERS=("${STACK_PREFIX}-ontology-cluster" "${STACK_PREFIX}-vkg-cluster")
NEPTUNE_WAIT_MAX_SECONDS="${SCL_NEPTUNE_WAIT_MAX_SECONDS:-1200}"

if [[ ! "$ENV" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "ERROR: ENV must be alphanumeric/dash/underscore, got: $ENV" >&2; exit 1
fi
if [[ ! "$PREFIX" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "ERROR: SCL_PREFIX must be alphanumeric/dash/underscore, got: $PREFIX" >&2; exit 1
fi

info() { echo "  ->   $1"; }
ok() { echo "  OK:  $1"; }
warn() { echo "WARN:  $1" >&2; }
err() { echo "ERROR: $1" >&2; }

# ── helpers ───────────────────────────────────────────────────────────────

neptune_status() {
  aws neptune describe-db-clusters --db-cluster-identifier "$NEPTUNE_CLUSTER" \
    --region "$REGION" --query 'DBClusters[0].Status' --output text 2>/dev/null || echo "not-found"
}

# ACTIVE service ARNs of one cluster, one per line (nothing if the cluster is absent).
list_services() {
  aws ecs list-services --cluster "$1" --region "$REGION" \
    --query 'serviceArns[]' --output text 2>/dev/null | tr '\t' '\n' | grep -v '^None$' | grep -v '^$'
}

service_tag() {  # <service-arn> <key>
  aws ecs list-tags-for-resource --resource-arn "$1" --region "$REGION" \
    --query "tags[?key=='$2'].value | [0]" --output text 2>/dev/null | grep -v '^None$'
}

# "<min> <max>" of the service's scalable target, or nothing when it has none.
scalable_range() {  # <cluster> <service-name>
  aws application-autoscaling describe-scalable-targets --service-namespace ecs \
    --resource-ids "service/$1/$2" --region "$REGION" \
    --query 'ScalableTargets[0].[MinCapacity,MaxCapacity]' --output text 2>/dev/null | grep -v '^None'
}

set_scalable_min() {  # <cluster> <service-name> <min> <max>
  aws application-autoscaling register-scalable-target --service-namespace ecs \
    --resource-id "service/$1/$2" --scalable-dimension ecs:service:DesiredCount \
    --min-capacity "$3" --max-capacity "$4" --region "$REGION" >/dev/null
}

set_desired() {  # <cluster> <service-arn> <count>
  aws ecs update-service --cluster "$1" --service "$2" --desired-count "$3" \
    --region "$REGION" --query 'service.serviceName' --output text >/dev/null
}

# ── actions ───────────────────────────────────────────────────────────────

do_sleep() {
  echo "=== Sleep ${STACK_PREFIX} (${REGION}) ==="
  local failed=0 cluster arn name desired range min max

  echo "--- ECS services → 0 ---"
  for cluster in "${ECS_CLUSTERS[@]}"; do
    while read -r arn; do
      [ -z "$arn" ] && continue
      name="${arn##*/}"
      desired=$(aws ecs describe-services --cluster "$cluster" --services "$arn" --region "$REGION" \
        --query 'services[0].desiredCount' --output text)
      # Already asleep: keep the tags written by the first sleep, never overwrite them with 0.
      if [ "$desired" != "0" ]; then
        aws ecs tag-resource --resource-arn "$arn" --region "$REGION" \
          --tags "key=coa:wake-desired,value=$desired" || { failed=1; continue; }
      fi
      range=$(scalable_range "$cluster" "$name")
      if [ -n "$range" ]; then
        read -r min max <<<"$range"
        if [ "$min" != "0" ]; then
          aws ecs tag-resource --resource-arn "$arn" --region "$REGION" \
            --tags "key=coa:wake-min,value=$min" || { failed=1; continue; }
          set_scalable_min "$cluster" "$name" 0 "$max" || { err "could not lower the floor of $name"; failed=1; continue; }
        fi
      fi
      if set_desired "$cluster" "$arn" 0; then
        ok "$name: desired $desired → 0"
      else
        err "could not scale $name to 0"; failed=1
      fi
    done < <(list_services "$cluster")
  done

  echo "--- Neptune ---"
  local status; status=$(neptune_status)
  case "$status" in
    available)
      if aws neptune stop-db-cluster --db-cluster-identifier "$NEPTUNE_CLUSTER" --region "$REGION" >/dev/null; then
        ok "$NEPTUNE_CLUSTER: stopping (takes a few minutes; storage is kept)"
      else
        err "could not stop $NEPTUNE_CLUSTER"; failed=1
      fi ;;
    stopped|stopping) ok "$NEPTUNE_CLUSTER: already $status" ;;
    not-found) warn "$NEPTUNE_CLUSTER not found — nothing to stop" ;;
    *) warn "$NEPTUNE_CLUSTER is '$status' — can only stop from 'available'; re-run later"; failed=1 ;;
  esac

  [ "$failed" = 0 ] && echo "Done. Run 'make dev-wake' to resume." || err "Sleep finished with errors (see above)."
  return "$failed"
}

do_wake() {
  echo "=== Wake ${STACK_PREFIX} (${REGION}) ==="
  local failed=0 cluster arn name desired min range cur_min max

  echo "--- Neptune ---"
  local status; status=$(neptune_status)
  case "$status" in
    stopped)
      aws neptune start-db-cluster --db-cluster-identifier "$NEPTUNE_CLUSTER" --region "$REGION" >/dev/null \
        && info "$NEPTUNE_CLUSTER: starting" || { err "could not start $NEPTUNE_CLUSTER"; failed=1; } ;;
    not-found) warn "$NEPTUNE_CLUSTER not found — skipping" ;;
    *) info "$NEPTUNE_CLUSTER: $status" ;;
  esac
  if [ "$status" != "not-found" ] && [ "$failed" = 0 ]; then
    local waited=0
    # A cluster still 'stopping' from last night's sleep must finish before it can start.
    while status=$(neptune_status); [ "$status" != "available" ]; do
      if [ "$status" = "stopped" ]; then
        aws neptune start-db-cluster --db-cluster-identifier "$NEPTUNE_CLUSTER" --region "$REGION" >/dev/null || true
      fi
      if [ "$waited" -ge "$NEPTUNE_WAIT_MAX_SECONDS" ]; then
        err "$NEPTUNE_CLUSTER still '$status' after ${waited}s — starting ECS anyway"; failed=1; break
      fi
      sleep 30; waited=$((waited + 30))
      info "$NEPTUNE_CLUSTER: $status (${waited}s)"
    done
    [ "$status" = "available" ] && ok "$NEPTUNE_CLUSTER: available"
  fi

  echo "--- ECS services → restored ---"
  for cluster in "${ECS_CLUSTERS[@]}"; do
    local arns=()
    while read -r arn; do
      [ -z "$arn" ] && continue
      arns+=("$arn")
      name="${arn##*/}"
      desired=$(service_tag "$arn" coa:wake-desired); desired="${desired:-1}"
      min=$(service_tag "$arn" coa:wake-min)
      range=$(scalable_range "$cluster" "$name")
      if [ -n "$range" ] && [ -n "$min" ]; then
        read -r cur_min max <<<"$range"
        set_scalable_min "$cluster" "$name" "$min" "$max" || { err "could not restore the floor of $name"; failed=1; }
      fi
      if set_desired "$cluster" "$arn" "$desired"; then
        ok "$name: desired → $desired"
      else
        err "could not scale $name to $desired"; failed=1
      fi
    done < <(list_services "$cluster")
    if [ "${#arns[@]}" -gt 0 ]; then
      info "waiting for ${cluster} services to become stable…"
      # `services-stable` takes at most 10 services per call.
      local i
      for ((i = 0; i < ${#arns[@]}; i += 10)); do
        aws ecs wait services-stable --cluster "$cluster" --services "${arns[@]:i:10}" --region "$REGION" \
          || { warn "${cluster}: not stable yet — check 'make dev-status' in a few minutes"; }
      done
    fi
  done

  [ "$failed" = 0 ] && echo "Done. Environment is awake." || err "Wake finished with errors (see above)."
  return "$failed"
}

do_status() {
  echo "=== Status ${STACK_PREFIX} (${REGION}) ==="
  echo "Neptune  $NEPTUNE_CLUSTER: $(neptune_status)"
  local cluster arn
  for cluster in "${ECS_CLUSTERS[@]}"; do
    # No mapfile: macOS ships bash 3.2.
    local arns=()
    while read -r arn; do [ -n "$arn" ] && arns+=("$arn"); done < <(list_services "$cluster")
    if [ "${#arns[@]}" -eq 0 ]; then
      echo "ECS      $cluster: no services"
      continue
    fi
    local i
    for ((i = 0; i < ${#arns[@]}; i += 10)); do
      aws ecs describe-services --cluster "$cluster" --services "${arns[@]:i:10}" --region "$REGION" \
        --query 'services[].[serviceName,desiredCount,runningCount]' --output text \
        | while read -r n d r; do echo "ECS      $n: desired=$d running=$r"; done
    done
  done
}

case "$ACTION" in
  sleep) do_sleep ;;
  wake) do_wake ;;
  status) do_status ;;
  *) echo "Usage: $0 {sleep|wake|status} [env]" >&2; exit 2 ;;
esac
