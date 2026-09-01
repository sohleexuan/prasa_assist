export type AnalysisContract = {
  summary: string;
  rationale: string[];
  limitations: string[];
  staffReviewChecklist: string[];
};

export type DeterministicFacts = {
  id: string;
  vehicle_id: string;
  route_id: string | null;
  score: number;
  actions_snapshot: unknown;
  evidence_snapshot: unknown;
  confidence_details: unknown;
};

const exactKeys = [
  "limitations",
  "rationale",
  "staffReviewChecklist",
  "summary",
];

export function parseAnalysis(
  raw: string,
  context: { allowedIdentifiers: string[] },
): AnalysisContract {
  let value: unknown;
  try {
    value = JSON.parse(raw);
  } catch {
    throw new Error("INVALID_MODEL_RESPONSE");
  }
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("INVALID_MODEL_RESPONSE");
  }
  const record = value as Record<string, unknown>;
  if (Object.keys(record).sort().join("|") !== exactKeys.join("|")) {
    throw new Error("INVALID_MODEL_RESPONSE");
  }
  const summary = text(record.summary);
  const rationale = list(record.rationale);
  const limitations = list(record.limitations);
  const staffReviewChecklist = list(record.staffReviewChecklist);
  const combined = [
    summary,
    ...rationale,
    ...limitations,
    ...staffReviewChecklist,
  ]
    .join(" ");
  if (
    /\b(accept|reject|dispatch|deploy|create)\b.{0,35}\b(automatically|now)\b/i
      .test(combined)
  ) {
    throw new Error("INVALID_MODEL_RESPONSE");
  }
  const identifiers = combined.match(/\b(?:B\d{3,}|route\s+\d+)\b/gi) ?? [];
  for (const identifier of identifiers) {
    const normalized = identifier.replace(/^route\s+/i, "");
    if (
      !context.allowedIdentifiers.some((allowed) =>
        allowed.toLowerCase() === normalized.toLowerCase()
      )
    ) {
      throw new Error("INVALID_MODEL_RESPONSE");
    }
  }
  return { summary, rationale, limitations, staffReviewChecklist };
}

export function buildAnalysisPrompt(facts: DeterministicFacts): string {
  const providerFacts = {
    vehicle_id: facts.vehicle_id,
    route_id: facts.route_id,
    score: facts.score,
    actions_snapshot: facts.actions_snapshot,
    evidence_snapshot: facts.evidence_snapshot,
    confidence_details: facts.confidence_details,
  };
  return [
    "You explain a stored deterministic operations recommendation to staff.",
    "Use only the JSON facts below. Do not infer or invent facts, identifiers, time, incidents, vehicles, routes, or live data.",
    "You must not accept or reject, execute, dispatch, deploy, create a work order, change actions, evidence, score, or confidence, or reveal chain-of-thought.",
    "Return concise JSON matching the supplied schema. Rationale means short user-facing reasons, not hidden reasoning.",
    JSON.stringify(providerFacts),
  ].join("\n");
}

function text(value: unknown): string {
  if (typeof value !== "string") throw new Error("INVALID_MODEL_RESPONSE");
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > 1200) {
    throw new Error("INVALID_MODEL_RESPONSE");
  }
  return trimmed;
}

function list(value: unknown): string[] {
  if (!Array.isArray(value) || value.length < 1 || value.length > 8) {
    throw new Error("INVALID_MODEL_RESPONSE");
  }
  return value.map(text);
}
