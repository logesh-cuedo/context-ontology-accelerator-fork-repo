// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

/**
 * Per-step-type formatters that convert structured detail objects
 * from the backend into human-readable sentences for the execution plan.
 *
 * Each formatter receives the detail record and returns a display string.
 * Falls back to raw string detail or empty string for unknown shapes.
 */

import {
  ENTITY_STEP_FALLBACK,
  ENTITY_STEP_ID,
  EXTENSION_STEP_FORMATTERS,
} from "../../../extensions/entity-resolution"; // cuedo-ext

type DetailRecord = Record<string, unknown>;
type Formatter = (detail: DetailRecord) => string;

// Human-readable phrasing for raw backend error codes so the UI never shows
// snake_case identifiers like "vkg_translation_error".
const ERROR_CODE_LABELS: Record<string, string> = {
  vkg_translation_error: "Ontop could not translate the SPARQL to SQL",
  no_tables_retrieved: "no matching tables found",
  query_execution_error: "query execution failed",
  firewall_error: "firewall check failed",
  unsafe_sql: "generated SQL was not a safe SELECT",
  empty_sql: "the model returned no SQL",
  // Backend exception class names that reach the trace verbatim — map to a
  // reader-friendly cause so the demo never shows a raw "FooError".
  UnsafeSQLError: "the generated SQL was not a safe read-only SELECT",
  GraphQueryError: "the graph store did not respond in time",
  TimeoutError: "the request timed out",
  RetrieveError: "the search backend was unavailable",
};

function humanizeError(value: unknown): string {
  const raw = String(value ?? "").trim();
  if (ERROR_CODE_LABELS[raw]) return ERROR_CODE_LABELS[raw];
  // Some backend errors arrive as "<code>: <detail>" (e.g.
  // "retrieve_failed: Vector search proxy returned an error"). Humanize the
  // leading code and keep a short, readable tail rather than leaking the raw
  // internal message.
  const prefixed = raw.match(/^([a-z][a-z0-9_]+):\s*(.+)$/);
  if (prefixed) {
    const code = prefixed[1];
    if (code === "retrieve_failed") return "the search backend was unavailable";
    const label = ERROR_CODE_LABELS[code] ?? code.replace(/_/g, " ");
    return label;
  }
  // Generic snake_case → sentence case for unknown codes.
  if (/^[a-z][a-z0-9_]+$/.test(raw)) return raw.replace(/_/g, " ");
  return raw;
}

// A bare exception class name (e.g. "VKGTranslationError") carries no useful
// info for end users — used to decide whether to append an error detail.
function isRawExceptionName(value: unknown): boolean {
  const raw = String(value ?? "").trim();
  return /^[A-Z][A-Za-z0-9]*(Error|Exception)$/.test(raw);
}

// Cap a list for inline display; full list stays in the raw detail/trace.
function summarizeList(items: unknown, max = 5): string {
  if (!Array.isArray(items) || items.length === 0) return "";
  const shown = items.slice(0, max).join(", ");
  const extra = items.length - max;
  return extra > 0 ? `${shown}, +${extra} more` : shown;
}

const _authorizeFormatter: Formatter = (d) => {
  const principal = d.principal ?? "unknown";
  // "allow" with no row/column restriction to apply. Phrased as an outcome
  // ("access authorized") rather than the implementation detail ("no filter
  // injection required"), which read as a non-sequitur in the demo trace.
  if (d.decision === "allow")
    return `Access authorized for ${principal} (no row/column restrictions).`;
  if (d.decision === "deny") return `Access denied for principal ${principal}.`;
  return "";
};

const _firewallFormatter: Formatter = (d) => {
  // Backend emits {denied: false} on the pass path (t2.vkg.firewall) and
  // {decision: "authorized"} elsewhere. The firewall validates the SQL — it
  // does not "inject" — so a clean pass reads as "passed", not "no injection".
  if (d.denied === false || d.decision === "authorized")
    return "SQL firewall passed — query is a safe read-only SELECT.";
  // Error path: the firewall rejected the generated SQL (e.g. a low-confidence
  // SPARQL translated to non-SELECT SQL). Explain the cause rather than showing
  // the raw exception name; this is a non-fatal fallthrough to Tier 3.
  if (d.error)
    return `SQL firewall blocked the query — ${humanizeError(d.error)}.`;
  if (d.denied === true) return "SQL firewall blocked the query.";
  if (d.reason) return String(d.reason);
  return "";
};

const _executeFormatter: Formatter = (d) => {
  const rows = d.rowCount ?? d.rows ?? 0;
  const tables = Array.isArray(d.tables)
    ? summarizeList(d.tables)
    : d.table
      ? String(d.table)
      : "";
  let msg = `${rows} row(s) returned${tables ? ` from ${tables}` : ""}.`;
  if (d.truncated) msg += " (truncated)";
  return msg;
};

const stepFormatters: Record<string, Formatter> = {
  "t1.metric_match": (d) => {
    // Tier-1 matched a metric but the question carried a qualifier the metric's
    // fixed SQL cannot express (a filter, grouping, or time window), so it
    // declined rather than return the unfiltered aggregate. Checked before the
    // metricName branch — a bypass is not a resolution and carries no confidence.
    if (d.unhandledQualifier) {
      return `Matched ${d.metricName ?? "a metric"} but "${d.unhandledQualifier}" can't be applied to it; routing to structured query.`;
    }
    if (d.metricName) {
      return `Resolved to ${d.metricName} (${d.matchSource ?? "exact"}, confidence ${d.confidence ?? 1.0}).`;
    }
    // No metric matched — don't echo the query (it's already on screen above);
    // state what happens next instead. The backend miss detail is
    // {query_length: N} (no metricName), so treat any non-match detail as a miss.
    if (
      d.query !== undefined ||
      d.matchCount !== undefined ||
      d.query_length !== undefined
    ) {
      return "No matching metric; routing to structured query.";
    }
    return "";
  },

  "query.embed": (d) => {
    if (d.dimensions) return `Embedded query (${d.dimensions} dimensions).`;
    if (d.error) return `Embedding failed: ${d.message || d.error}`;
    return "";
  },

  "t2.vkg.context": (d) => {
    const classes = d.classCount ?? d.classes ?? 0;
    const props = d.propertyCount ?? d.properties ?? 0;
    return `${classes} classes, ${props} properties pulled from the published ontology.`;
  },

  "t2.vkg.translate": (d) => {
    if (d.confidence) return `NL → SPARQL with confidence ${d.confidence}.`;
    const parts: string[] = [];
    if (d.dialect) parts.push(`Dialect=${d.dialect}`);
    if (d.tables) {
      const tables = Array.isArray(d.tables)
        ? d.tables.join(", ")
        : String(d.tables);
      parts.push(`Tables: ${tables}`);
    }
    return parts.length > 0 ? `${parts.join(". ")}.` : "";
  },

  "t2.vkg.validate": (d) => {
    if (d.valid === true || d.status === "clean") return "Parsed clean.";
    if (d.error) return `Validation error: ${d.error}`;
    return "";
  },

  "t2.vkg.retry": (d) => {
    if (d.reason) {
      // Strip the "retry also failed: <code>" wrapper and humanize the code.
      const reason = String(d.reason).replace(/^retry also failed:\s*/i, "");
      return `Retry failed — ${humanizeError(reason)}.`;
    }
    if (d.error) return `Retry failed — ${humanizeError(d.error)}.`;
    return "";
  },

  "t2.vkg.compile": (d) => {
    // Ontop SPARQL→SQL translation. On failure this is what triggers the retry.
    // Suppress a bare exception class name (no user value); the base message
    // already explains the failure.
    if (d.error) {
      return isRawExceptionName(d.error)
        ? "Ontop could not translate SPARQL to SQL."
        : `Ontop could not translate SPARQL to SQL: ${humanizeError(d.error)}.`;
    }
    const parts: string[] = [];
    if (d.dialect) parts.push(`dialect ${d.dialect}`);
    const tables = summarizeList(d.tables);
    if (tables) parts.push(`tables: ${tables}`);
    return parts.length > 0
      ? `Translated to SQL (${parts.join(", ")}).`
      : "Translated SPARQL to SQL.";
  },

  ...EXTENSION_STEP_FORMATTERS, // cuedo-ext

  "t2.sql.generate": (d) => {
    // Error path: the NL→SQL strategy couldn't produce SQL (e.g. its schema
    // retrieval was unavailable). This is a non-fatal fallthrough — the VKG
    // (Ontop) strategy runs next — so phrase it as "skipped", not a hard error.
    if (d.error) {
      return `NL→SQL skipped (${humanizeError(d.error)}); falling back to VKG.`;
    }
    const conf = d.confidence;
    const tables = summarizeList(d.tables);
    const parts: string[] = [];
    if (conf !== undefined) parts.push(`confidence ${conf}`);
    if (tables) parts.push(`tables: ${tables}`);
    return parts.length > 0
      ? `SQL generated (${parts.join(", ")}).`
      : "SQL generated.";
  },

  "t1.authorize": _authorizeFormatter,
  "t2.sql.authorize": _authorizeFormatter,
  "t2.vkg.authorize": _authorizeFormatter,

  "t1.firewall": _firewallFormatter,
  "t2.sql.firewall": _firewallFormatter,
  "t2.vkg.firewall": _firewallFormatter,

  "t1.execute": _executeFormatter,
  "t2.sql.execute": _executeFormatter,
  "t2.vkg.execute": _executeFormatter,

  "t3.vector_search": (d) => {
    if (d.chunks !== undefined) return `${d.chunks} chunks retrieved.`;
    if (d.itemCount !== undefined) return `${d.itemCount} items retrieved.`;
    return "";
  },

  "t3.graph_traverse": (d) => {
    if (d.entities !== undefined) return `${d.entities} entities found.`;
    if (d.itemCount !== undefined) return `${d.itemCount} items.`;
    return "";
  },

  "t3.synthesize": (d) => {
    if (d.outputTokens)
      return `${d.inputTokens ?? "?"} → ${d.outputTokens} tokens.`;
    if (d.tokenCount) return `Generated ${d.tokenCount} tokens.`;
    return "";
  },

  "t3.retrieve": (d) => {
    const count = Array.isArray(d.sources) ? d.sources.length : 0;
    return count ? `${count} sources in parallel.` : "Parallel retrieval.";
  },

  // graphrag-toolkit lexical retriever (TIER3_STRATEGY=lexical-baseline).
  // Backend sends a STRING detail ("strategy=chunk_based_semantic; 5 nodes
  // retrieved"), which formatStepDetail passes through directly — this handler
  // only fires if the detail is ever upgraded to a structured object.
  lexical_baseline_retrieve: (d) => {
    const nodes = d.nodes ?? d.itemCount ?? d.count;
    const strategy = d.strategy ? ` via ${d.strategy}` : "";
    if (nodes !== undefined)
      return `Retrieved ${nodes} document chunk(s)${strategy}.`;
    if (d.error) return `Lexical retrieval failed: ${humanizeError(d.error)}.`;
    return "";
  },

  "t2.sql.failed": (d) => strategyFailedDetail(d),
  "t2.vkg.failed": (d) => strategyFailedDetail(d),

  "t2.strategy_selected": (d) => {
    const friendly = STRATEGY_DISPLAY_NAMES[String(d.strategy)] ?? d.strategy;
    return friendly ? `Chose ${friendly}.` : "Strategy selected.";
  },
};

/** Human-friendly names for the Tier-2 strategy identifiers. */
const STRATEGY_DISPLAY_NAMES: Record<string, string> = {
  nl_to_sql: "NL→SQL",
  ontop: "VKG (Ontop)",
};

/** Detail for an abandoned-strategy step: explain why it was skipped. */
function strategyFailedDetail(d: DetailRecord): string {
  if (d.reason === "empty_low_confidence") {
    const conf =
      typeof d.confidence === "number" ? ` (confidence ${d.confidence})` : "";
    return `Returned no rows with low confidence${conf} — trying another approach.`;
  }
  if (d.message) return `Abandoned — ${humanizeError(d.message)}.`;
  if (d.error) return `Abandoned — ${humanizeError(d.error)}.`;
  return "Strategy abandoned; trying another approach.";
}

const NOISE_VALUES = new Set(["ok", "empty", "null", "{}", "[]", "none"]);

const STEP_FALLBACKS: Record<string, string> = {
  "t1.metric_match": "Checked metric catalog.",
  "query.embed": "Query embedded.",
  "t2.vkg.context": "Ontology context loaded.",
  "t2.vkg.translate": "SPARQL generated.",
  "t2.vkg.validate": "Passed.",
  "t2.vkg.compile": "Translated SPARQL to SQL.",
  "t2.sql.generate": "SQL generated.",
  "t1.authorize": "Authorized.",
  "t2.sql.authorize": "Authorized.",
  "t2.vkg.authorize": "Authorized.",
  "t1.firewall": "SQL firewall passed.",
  "t2.sql.firewall": "SQL firewall passed.",
  "t2.vkg.firewall": "SQL firewall passed.",
  "t1.execute": "Query executed.",
  "t2.sql.execute": "Query executed.",
  "t2.vkg.execute": "Query executed.",
  "t3.vector_search": "Knowledge base searched.",
  "t3.graph_traverse": "Graph traversed.",
  "t3.synthesize": "Response synthesized.",
  "t3.retrieve": "Parallel retrieval complete.",
  lexical_baseline_retrieve: "Document chunks retrieved.",
  "t3.catalog_context": "Catalog context loaded.",
  "t2.vkg.retry": "Retry attempted.",
  "t2.sql.failed": "NL→SQL strategy abandoned.",
  "t2.vkg.failed": "VKG strategy abandoned.",
  "t2.strategy_selected": "Strategy selected.",
  "routing.select": "Intent routed.",
  [ENTITY_STEP_ID]: ENTITY_STEP_FALLBACK, // cuedo-ext
};

/**
 * Format a trace step's detail for display in the execution plan.
 *
 * Always returns a non-empty string — uses fallback descriptions when
 * no structured detail is available from the backend.
 */
export function formatStepDetail(
  stepName: string,
  detail: string | Record<string, unknown> | undefined | null,
): string {
  if (!detail) return STEP_FALLBACKS[stepName] ?? "";

  // Structured detail object — use formatter
  if (typeof detail === "object") {
    const formatter = stepFormatters[stepName];
    if (formatter) {
      const result = formatter(detail);
      if (result) return result;
    }
    // Generic error/message extraction
    if (detail.message && typeof detail.message === "string") {
      return String(detail.message);
    }
    if (detail.error && typeof detail.error === "string") {
      return String(detail.error);
    }
    if (detail.reason && typeof detail.reason === "string") {
      return String(detail.reason);
    }
    return STEP_FALLBACKS[stepName] ?? "";
  }

  // String detail — clean up noise
  const trimmed = detail.trim();
  if (NOISE_VALUES.has(trimmed.toLowerCase())) {
    return STEP_FALLBACKS[stepName] ?? "";
  }

  // Some backend steps send terse string details; turn them into sentences.
  if (stepName === "t2.vkg.context") {
    const m = trimmed.match(/(\d+)\s+classes?,\s*(\d+)\s+properties?/i);
    if (m)
      return `${m[1]} classes, ${m[2]} properties pulled from the published ontology.`;
  }
  if (stepName === "t2.vkg.translate") {
    const m = trimmed.match(/confidence=([\d.]+)/i);
    if (m) return `NL → SPARQL with confidence ${m[1]}.`;
  }
  // The OTHER Tier-1 bypass. When more than one governed metric matches, the
  // question is ambiguous for the single-metric path, so Tier 1 declines rather
  // than execute just the first one. The backend records this as a BARE STRING
  // ("3 metrics"), not an object, so the stepFormatters entry above never sees it
  // and the raw fragment reached the UI verbatim. Phrase it like its sibling
  // residual_qualifier_bypass: name the reason, then where the question goes.
  // The count is pluralized rather than interpolated bare: the backend emits
  // f"{count} metrics" unconditionally, so a hypothetical "1 metric" detail would
  // otherwise render "matched 1 metrics".
  if (stepName === "t1.metric_match") {
    const m = trimmed.match(/^(\d+)\s+metrics?$/i);
    if (m) {
      const n = Number(m[1]);
      return `Question matched ${n} ${n === 1 ? "metric" : "metrics"}, so it is ambiguous for the single-metric path; routing to structured query.`;
    }
  }
  // The NL→SQL generate step records its failure detail as a BARE STRING
  // (e.g. "retrieve_failed: Vector search proxy returned an error" or
  // "empty_sql"), not an object — so the object formatter above never sees it.
  // Humanize it here so the raw backend string never reaches the UI. This is a
  // non-fatal fallthrough (VKG/Ontop runs next); the trace status already
  // conveys skipped-vs-error, this is just the copy.
  if (stepName === "t2.sql.generate") {
    return `NL→SQL skipped (${humanizeError(trimmed)}); falling back to VKG.`;
  }

  // Lexical retriever sends a string detail: "strategy=<name>; <N nodes
  // retrieved | TimeoutError after Xs | GraphQueryError>". Parse it into a
  // human sentence. On error the retriever returns no chunks (the graphrag
  // engine does vector + Neptune content-fetch as one call), so synthesis runs
  // without retrieved context — phrase it as a retrieval failure, not a
  // partial success.
  if (stepName === "lexical_baseline_retrieve") {
    const outcome = trimmed.replace(/^strategy=[^;]*;\s*/i, "");
    const nodeMatch = outcome.match(/^(\d+)\s+nodes?\s+retrieved/i);
    if (nodeMatch) return `Retrieved ${nodeMatch[1]} document chunk(s).`;
    if (/timeouterror/i.test(outcome))
      return "No documents retrieved — the graph store timed out.";
    if (/^[A-Za-z]+Error/.test(outcome))
      return `No documents retrieved — ${humanizeError(outcome.match(/^[A-Za-z]+Error/)?.[0])}.`;
    return outcome || (STEP_FALLBACKS[stepName] ?? "");
  }

  // Python-style dicts or JSON — try to extract message
  if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
    try {
      const jsonStr = trimmed.includes("'")
        ? trimmed.replace(/'/g, '"')
        : trimmed;
      const parsed = JSON.parse(jsonStr);
      if (typeof parsed === "object" && parsed !== null) {
        const msg =
          parsed.error || parsed.message || parsed.detail || parsed.reason;
        if (typeof msg === "string") return msg;
        const values = Object.values(parsed);
        if (values.every((v) => !v || (Array.isArray(v) && v.length === 0))) {
          return STEP_FALLBACKS[stepName] ?? "";
        }
      }
      return STEP_FALLBACKS[stepName] ?? "";
    } catch {
      return STEP_FALLBACKS[stepName] ?? "";
    }
  }

  // Snake_case identifiers → Title Case
  if (/^[a-z][a-z0-9_]+$/.test(trimmed)) {
    return trimmed.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
  }

  return trimmed;
}
