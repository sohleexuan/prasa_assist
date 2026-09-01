import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { AnalysisDependencies, createAnalysisHandler } from "./handler.ts";
import type {
  AuthResult,
  DatabaseResult,
  OwnedRecommendation,
  SavedAnalysis,
} from "./handler.ts";

const recommendation: OwnedRecommendation = {
  id: "460d90f1-d4f1-451f-ac69-761dc972b652",
  owner_user_id: "e1a376c2-b7f7-4ad3-970c-8b10534a2d07",
  vehicle_id: "B1023",
  route_id: "300",
  score: 85,
  status: "accepted",
  actions_snapshot: [{ type: "inspect_or_repair_vehicle", vehicleId: "B1023" }],
  evidence_snapshot: [{ ruleId: "confirmed_breakdown", contribution: 50 }],
  confidence_details: { factors: [], penalties: [] },
};

const snapshot: SavedAnalysis = {
  recommendation_id: recommendation.id,
  owner_user_id: recommendation.owner_user_id,
  model_identifier: "gemini-2.5-flash",
  schema_version: 1,
  summary: "Inspect B1023 before return to service.",
  rationale: ["Stored breakdown evidence supports inspection."],
  limitations: ["Staff must confirm the current vehicle condition."],
  staff_review_checklist: ["Review the stored evidence."],
  generated_at: "2026-08-31T00:00:00.000Z",
};

Deno.test("authenticated owner can create analysis for an accepted recommendation", async () => {
  const fake = new FakeDependencies();
  const response = await createAnalysisHandler(fake.dependencies)(request());

  assertEquals(response.status, 201);
  assertEquals(fake.providerCalls, 1);
  assertEquals(fake.savedRows.length, 1);
  assertEquals(fake.savedRows[0].recommendation_id, recommendation.id);
  assertEquals(fake.savedRows[0].owner_user_id, recommendation.owner_user_id);
});

Deno.test("recommendation query errors are server failures, never false 404s", async () => {
  const fake = new FakeDependencies();
  fake.recommendationResult = { data: null, error: { code: "42703" } };

  const response = await createAnalysisHandler(fake.dependencies)(request());

  assertEquals(response.status, 500);
  assertEquals((await response.json()).error.code, "PERSISTENCE_ERROR");
  assertEquals(fake.providerCalls, 0);
});

Deno.test("authentication failure rejects before record lookup or Gemini", async () => {
  const fake = new FakeDependencies();
  fake.authResult = { userId: null, error: { code: "invalid_token" } };

  const response = await createAnalysisHandler(fake.dependencies)(request());

  assertEquals(response.status, 401);
  assertEquals((await response.json()).error.code, "AUTH_REQUIRED");
  assertEquals(fake.recommendationLookups, 0);
  assertEquals(fake.providerCalls, 0);
});

Deno.test("missing or non-owned recommendation remains safely rejected", async () => {
  const fake = new FakeDependencies();
  fake.recommendationResult = { data: null, error: null };

  const response = await createAnalysisHandler(fake.dependencies)(request());

  assertEquals(response.status, 404);
  assertEquals((await response.json()).error.code, "NOT_FOUND");
  assertEquals(fake.providerCalls, 0);
  assertEquals(fake.analysisLookups, 0);
});

Deno.test("existing snapshot is returned without invoking Gemini", async () => {
  const fake = new FakeDependencies();
  fake.analysisResult = { data: snapshot, error: null };

  const response = await createAnalysisHandler(fake.dependencies)(request());
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.summary, snapshot.summary);
  assertEquals(body.existing, true);
  assertEquals(fake.providerCalls, 0);
  assertEquals(fake.savedRows.length, 0);
});

Deno.test("snapshot query errors are server failures and skip Gemini", async () => {
  const fake = new FakeDependencies();
  fake.analysisResult = { data: null, error: { code: "42P01" } };

  const response = await createAnalysisHandler(fake.dependencies)(request());

  assertEquals(response.status, 500);
  assertEquals((await response.json()).error.code, "PERSISTENCE_ERROR");
  assertEquals(fake.providerCalls, 0);
});

Deno.test("unique insert race reloads one snapshot without a second Gemini call", async () => {
  const fake = new FakeDependencies();
  fake.saveResult = { data: null, error: { code: "23505" } };
  fake.analysisResults = [
    { data: null, error: null },
    { data: snapshot, error: null },
  ];

  const response = await createAnalysisHandler(fake.dependencies)(request());

  assertEquals(response.status, 200);
  assertEquals(fake.providerCalls, 1);
  assertEquals(fake.savedRows.length, 1);
  assertEquals(fake.analysisLookups, 2);
});

function request(): Request {
  return new Request("http://localhost/generate-recommendation-analysis", {
    method: "POST",
    headers: {
      "Authorization": "Bearer staff-token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ recommendationId: recommendation.id }),
  });
}

class FakeDependencies {
  authResult: AuthResult = {
    userId: recommendation.owner_user_id,
    error: null,
  };
  recommendationResult: DatabaseResult<OwnedRecommendation> = {
    data: recommendation,
    error: null,
  };
  analysisResult: DatabaseResult<SavedAnalysis> = { data: null, error: null };
  analysisResults?: DatabaseResult<SavedAnalysis>[];
  saveResult: DatabaseResult<null> = { data: null, error: null };
  providerCalls = 0;
  recommendationLookups = 0;
  analysisLookups = 0;
  readonly savedRows: SavedAnalysis[] = [];
  readonly dependencies: AnalysisDependencies;

  constructor() {
    this.dependencies = new AnalysisDependencies(
      async (_) => this.authResult,
      async (_, __) => {
        this.recommendationLookups++;
        return this.recommendationResult;
      },
      async (_, __) => {
        const index = this.analysisLookups++;
        return this.analysisResults?.[index] ?? this.analysisResult;
      },
      async (_) => {
        this.providerCalls++;
        return {
          summary: snapshot.summary,
          rationale: snapshot.rationale,
          limitations: snapshot.limitations,
          staffReviewChecklist: snapshot.staff_review_checklist,
        };
      },
      async (row) => {
        this.savedRows.push(row);
        return this.saveResult;
      },
      () => new Date(snapshot.generated_at),
    );
  }
}
