// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

/**
 * cuedo-ext: UI side of the generic entity-resolution extension
 * (extensions/entity-resolution). Upstream files only import these:
 *   - step-labels.ts          labels for the step
 *   - format-step-detail.ts   the step's one-line summary
 *   - RationalePanel.tsx      keep the step visible in the split SQL/VKG view
 *
 * Generic: entity types come from the backend detail
 * (`entities: { company: [...], sector: [...] }`), nothing is hard-coded.
 */

export const ENTITY_STEP_ID = "t2.entity.resolve";

/** Live (streaming) label. */
export const ENTITY_STEP_LABELS: Record<string, string> = {
  [ENTITY_STEP_ID]: "Resolving entities",
};

/** Execution-plan label. */
export const ENTITY_STEP_DISPLAY_NAMES: Record<string, string> = {
  [ENTITY_STEP_ID]: "Resolve entities",
};

/**
 * Tier-2 steps that run before either strategy. When the t2 section is split
 * into NL→SQL / VKG subgroups they belong to neither, so they stay in the
 * section's lead-in — otherwise the split view would drop them.
 */
export const ENTITY_LEAD_IN_STEP_IDS = new Set([ENTITY_STEP_ID]);

export const ENTITY_STEP_FALLBACK = "Entities resolved.";

function list(items: unknown): string {
  if (!Array.isArray(items) || items.length === 0) return "";
  const shown = items.slice(0, 5).join(", ");
  return items.length > 5 ? `${shown}, +${items.length - 5} more` : shown;
}

/** One-line summary of the entity step's detail. */
export function formatEntityStep(d: Record<string, unknown>): string {
  const entities =
    d.entities && typeof d.entities === "object"
      ? (d.entities as Record<string, unknown>)
      : {};
  const parts = Object.entries(entities)
    .map(([kind, names]) => {
      const shown = list(names);
      return shown ? `${kind}: ${shown}` : "";
    })
    .filter(Boolean);
  switch (d.status) {
    case "found":
      return parts.length > 0
        ? `Resolved ${parts.join("; ")}.`
        : ENTITY_STEP_FALLBACK;
    case "no_entity":
      return "No specific entity named in the question.";
    case "ambiguous":
      return "Several matches; asked which one.";
    case "not_found":
      return "No matching entity found; asked to clarify.";
    case "skipped":
      return d.reason ? `Skipped (${String(d.reason)}).` : "Skipped.";
    default:
      return "";
  }
}
