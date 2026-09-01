import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildAnalysisPrompt, parseAnalysis } from "./analysis_contract.ts";
import type { DeterministicFacts } from "./analysis_contract.ts";

Deno.test("parseAnalysis accepts only the explanation contract", () => {
  const value = parseAnalysis(
    JSON.stringify({
      summary: "Inspect B1023 before return to service.",
      rationale: ["The stored breakdown evidence supports inspection."],
      limitations: ["Staff must confirm the current vehicle condition."],
      staffReviewChecklist: ["Review the stored evidence."],
    }),
    { allowedIdentifiers: ["B1023", "300"] },
  );
  assertEquals(value.rationale.length, 1);
});

Deno.test("parseAnalysis rejects deterministic mutations and unknown identifiers", () => {
  const base = {
    summary: "Review B1023.",
    rationale: ["Stored evidence supports review."],
    limitations: ["Staff verification is required."],
    staffReviewChecklist: ["Review evidence."],
  };
  assertThrows(() =>
    parseAnalysis(JSON.stringify({ ...base, score: 100 }), {
      allowedIdentifiers: ["B1023"],
    })
  );
  assertThrows(() =>
    parseAnalysis(
      JSON.stringify({
        ...base,
        summary: "Dispatch vehicle B9999 automatically.",
      }),
      { allowedIdentifiers: ["B1023"] },
    )
  );
});

Deno.test("prompt contains facts and forbids operational decisions", () => {
  const prompt = buildAnalysisPrompt({
    id: "rec-1",
    vehicle_id: "B1023",
    route_id: "300",
    score: 85,
    actions_snapshot: [{
      type: "inspect_or_repair_vehicle",
      vehicleId: "B1023",
    }],
    evidence_snapshot: [{ ruleId: "breakdown", contribution: 50 }],
    confidence_details: { factors: [], penalties: [] },
  });
  assertEquals(prompt.includes("B1023"), true);
  assertEquals(prompt.includes("must not accept or reject"), true);
});

Deno.test("prompt excludes recommendation and owner metadata from provider input", () => {
  const prompt = buildAnalysisPrompt({
    id: "460d90f1-d4f1-451f-ac69-761dc972b652",
    owner_user_id: "e1a376c2-b7f7-4ad3-970c-8b10534a2d07",
    status: "accepted",
    version: 7,
    vehicle_id: "B1023",
    route_id: "300",
    score: 85,
    actions_snapshot: [{
      type: "inspect_or_repair_vehicle",
      vehicleId: "B1023",
    }],
    evidence_snapshot: [{ ruleId: "breakdown", contribution: 50 }],
    confidence_details: { factors: [], penalties: [] },
  } as unknown as DeterministicFacts);

  assertEquals(prompt.includes("460d90f1-d4f1-451f-ac69-761dc972b652"), false);
  assertEquals(prompt.includes("e1a376c2-b7f7-4ad3-970c-8b10534a2d07"), false);
  assertEquals(prompt.includes('"vehicle_id":"B1023"'), true);
  assertEquals(prompt.includes('"route_id":"300"'), true);
});
