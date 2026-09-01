import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { AnalysisDependencies, createAnalysisHandler } from "./handler.ts";
import type {
  AuthResult,
  DatabaseResult,
  OwnedRecommendation,
  SavedAnalysis,
  ServerErrorEvent,
} from "./handler.ts";
import { GroqProviderError } from "./groq_provider.ts";

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

const racedSnapshot: SavedAnalysis = {
  ...snapshot,
  summary: "Return the previously saved immutable analysis.",
  rationale: ["The earlier request saved this snapshot first."],
  generated_at: "2026-08-30T23:59:00.000Z",
};

Deno.test("authenticated owner can create analysis for an accepted recommendation", async () => {
  const fake = new FakeDependencies();
  const response = await createAnalysisHandler(fake.dependencies)(request());

  assertEquals(response.status, 201);
  assertEquals(fake.providerCalls, 1);
  assertEquals(fake.savedRows.length, 1);
  assertEquals(fake.savedRows[0].recommendation_id, recommendation.id);
  assertEquals(fake.savedRows[0].owner_user_id, recommendation.owner_user_id);
  assertEquals(fake.savedRows[0].model_identifier, "openai/gpt-oss-20b");
  assertEquals(fake.reportedErrors, []);
  assertEquals(fake.recommendationLookupArguments, [[
    recommendation.id,
    recommendation.owner_user_id,
  ]]);
  assertEquals(fake.analysisLookupArguments, [[
    recommendation.id,
    recommendation.owner_user_id,
  ]]);
});

Deno.test("provider failures remain generic and report only fixed telemetry", async () => {
  const fake = new FakeDependencies();
  fake.generateError = new GroqProviderError("unavailable", {
    stage: "provider_request",
    code: "timeout",
  });

  const response = await createAnalysisHandler(fake.dependencies)(request());
  const body = await response.json();

  assertEquals(response.status, 503);
  assertEquals(body, {
    error: {
      code: "PROVIDER_UNAVAILABLE",
      message: "AI analysis is temporarily unavailable.",
    },
  });
  assertEquals(fake.reportedErrors, [{
    event: "generate_recommendation_analysis_error",
    stage: "provider_request",
    code: "timeout",
  }]);
  assertEquals(JSON.stringify(body).includes("timeout"), false);
});

Deno.test("recommendation query errors are server failures, never false 404s", async () => {
  const fake = new FakeDependencies();
  fake.recommendationResult = {
    data: null,
    error: {
      code: "42703",
      message: "sensitive database message",
      details: "sensitive row details",
      hint: "sensitive database hint",
    },
  };

  const response = await createAnalysisHandler(fake.dependencies)(request());
  const body = await response.json();

  assertEquals(response.status, 500);
  assertEquals(body, {
    error: {
      code: "PERSISTENCE_ERROR",
      message: "Recommendation data could not be read.",
    },
  });
  assertEquals(fake.providerCalls, 0);
  assertEquals(fake.reportedErrors, [{
    event: "generate_recommendation_analysis_error",
    stage: "find_owned_recommendation",
    code: "42703",
  }]);
  assertEquals(JSON.stringify(body).includes("sensitive"), false);
});

Deno.test("authentication failure rejects before record lookup or provider call", async () => {
  const fake = new FakeDependencies();
  fake.authResult = {
    userId: null,
    error: {
      code: "invalid_token",
      message: "sensitive authentication detail",
    },
  };

  const response = await createAnalysisHandler(fake.dependencies)(request());
  const body = await response.json();

  assertEquals(response.status, 401);
  assertEquals(body, {
    error: { code: "AUTH_REQUIRED", message: "Sign in is required." },
  });
  assertEquals(fake.recommendationLookups, 0);
  assertEquals(fake.providerCalls, 0);
  assertEquals(fake.reportedErrors, [{
    event: "generate_recommendation_analysis_error",
    stage: "authenticate",
    code: "invalid_token",
  }]);
  assertEquals(JSON.stringify(body).includes("sensitive"), false);
});

Deno.test("missing or non-owned recommendation remains safely rejected", async () => {
  const fake = new FakeDependencies();
  fake.recommendationResult = { data: null, error: null };

  const response = await createAnalysisHandler(fake.dependencies)(request());
  const body = await response.json();

  assertEquals(response.status, 404);
  assertEquals(body, {
    error: { code: "NOT_FOUND", message: "Recommendation was not found." },
  });
  assertEquals(fake.providerCalls, 0);
  assertEquals(fake.analysisLookups, 0);
  assertEquals(fake.reportedErrors, []);
  assertEquals(fake.recommendationLookupArguments, [[
    recommendation.id,
    recommendation.owner_user_id,
  ]]);
});

Deno.test("existing snapshot is returned without invoking the provider", async () => {
  const fake = new FakeDependencies();
  fake.analysisResult = { data: snapshot, error: null };

  const response = await createAnalysisHandler(fake.dependencies)(request());
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.summary, snapshot.summary);
  assertEquals(body.existing, true);
  assertEquals(fake.providerCalls, 0);
  assertEquals(fake.savedRows.length, 0);
  assertEquals(fake.reportedErrors, []);
});

Deno.test("snapshot query errors are server failures and skip the provider", async () => {
  const fake = new FakeDependencies();
  fake.analysisResult = {
    data: null,
    error: {
      code: "42P01",
      message: "sensitive database message",
      details: "sensitive row details",
      hint: "sensitive database hint",
    },
  };

  const response = await createAnalysisHandler(fake.dependencies)(request());
  const body = await response.json();

  assertEquals(response.status, 500);
  assertEquals(body, {
    error: {
      code: "PERSISTENCE_ERROR",
      message: "Saved analysis could not be read.",
    },
  });
  assertEquals(fake.providerCalls, 0);
  assertEquals(fake.reportedErrors, [{
    event: "generate_recommendation_analysis_error",
    stage: "find_existing_analysis",
    code: "42P01",
  }]);
  assertEquals(JSON.stringify(body).includes("sensitive"), false);
});

Deno.test("save errors remain generic and report only an allowlisted code", async () => {
  const fake = new FakeDependencies();
  fake.saveResult = {
    data: null,
    error: {
      code: "23514",
      message: "constraint failed for sensitive generated content",
      details: "complete sensitive row",
      hint: "sensitive hint",
    },
  };

  const response = await createAnalysisHandler(fake.dependencies)(request());
  const body = await response.json();

  assertEquals(response.status, 500);
  assertEquals(body, {
    error: {
      code: "PERSISTENCE_ERROR",
      message: "Unable to save AI analysis.",
    },
  });
  assertEquals(fake.reportedErrors, [{
    event: "generate_recommendation_analysis_error",
    stage: "save_analysis",
    code: "23514",
  }]);
  assertEquals(
    JSON.stringify(fake.reportedErrors).includes("sensitive"),
    false,
  );
  assertEquals(JSON.stringify(body).includes("sensitive"), false);
});

Deno.test("unknown database codes are reduced to a safe fallback", async () => {
  const fake = new FakeDependencies();
  fake.recommendationResult = {
    data: null,
    error: {
      code: "secret-custom-code",
      message: "sensitive database message",
    },
  };

  const response = await createAnalysisHandler(fake.dependencies)(request());
  const body = await response.json();

  assertEquals(response.status, 500);
  assertEquals(body, {
    error: {
      code: "PERSISTENCE_ERROR",
      message: "Recommendation data could not be read.",
    },
  });
  assertEquals(fake.reportedErrors, [{
    event: "generate_recommendation_analysis_error",
    stage: "find_owned_recommendation",
    code: "unknown",
  }]);
});

Deno.test("malformed database codes are reduced to a safe fallback", async () => {
  const fake = new FakeDependencies();
  fake.analysisResult = {
    data: null,
    error: { code: 23505 },
  };

  const response = await createAnalysisHandler(fake.dependencies)(request());
  const body = await response.json();

  assertEquals(response.status, 500);
  assertEquals(body, {
    error: {
      code: "PERSISTENCE_ERROR",
      message: "Saved analysis could not be read.",
    },
  });
  assertEquals(fake.reportedErrors, [{
    event: "generate_recommendation_analysis_error",
    stage: "find_existing_analysis",
    code: "unknown",
  }]);
});

Deno.test("reporter failures never replace the safe client response", async () => {
  const fake = new FakeDependencies();
  fake.recommendationResult = { data: null, error: { code: "42703" } };
  fake.reporter = (_) => {
    throw new Error("reporter unavailable");
  };

  const response = await createAnalysisHandler(fake.dependencies)(request());

  assertEquals(response.status, 500);
  assertEquals(await response.json(), {
    error: {
      code: "PERSISTENCE_ERROR",
      message: "Recommendation data could not be read.",
    },
  });
  assertEquals(fake.providerCalls, 0);
});

Deno.test("rejected async reporters never affect the safe client response", async () => {
  const fake = new FakeDependencies();
  fake.recommendationResult = { data: null, error: { code: "42703" } };
  fake.reporter = async (_) => {
    throw new Error("async reporter unavailable");
  };

  const response = await createAnalysisHandler(fake.dependencies)(request());
  await new Promise((resolve) => setTimeout(resolve, 0));

  assertEquals(response.status, 500);
  assertEquals(await response.json(), {
    error: {
      code: "PERSISTENCE_ERROR",
      message: "Recommendation data could not be read.",
    },
  });
});

Deno.test("throwing database code getters remain safe at the save stage", async () => {
  const fake = new FakeDependencies();
  const hostileError = Object.defineProperty({}, "code", {
    get() {
      throw new Error("sensitive getter failure");
    },
  });
  fake.saveResult = { data: null, error: hostileError };

  const response = await createAnalysisHandler(fake.dependencies)(request());

  assertEquals(response.status, 500);
  assertEquals(await response.json(), {
    error: {
      code: "PERSISTENCE_ERROR",
      message: "Unable to save AI analysis.",
    },
  });
  assertEquals(fake.reportedErrors, [{
    event: "generate_recommendation_analysis_error",
    stage: "save_analysis",
    code: "unknown",
  }]);
});

Deno.test("unique insert race reloads one snapshot without a second provider call", async () => {
  const fake = new FakeDependencies();
  fake.saveResult = { data: null, error: { code: "23505" } };
  fake.analysisResults = [
    { data: null, error: null },
    { data: racedSnapshot, error: null },
  ];

  const response = await createAnalysisHandler(fake.dependencies)(request());
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body, {
    summary: racedSnapshot.summary,
    rationale: racedSnapshot.rationale,
    limitations: racedSnapshot.limitations,
    staffReviewChecklist: racedSnapshot.staff_review_checklist,
    modelIdentifier: racedSnapshot.model_identifier,
    schemaVersion: racedSnapshot.schema_version,
    generatedAt: racedSnapshot.generated_at,
    existing: true,
  });
  assertEquals(fake.providerCalls, 1);
  assertEquals(fake.savedRows.length, 1);
  assertEquals(fake.analysisLookups, 2);
  assertEquals(fake.reportedErrors, [{
    event: "generate_recommendation_analysis_error",
    stage: "save_analysis",
    code: "23505",
  }]);
  assertEquals(fake.analysisLookupArguments, [
    [recommendation.id, recommendation.owner_user_id],
    [recommendation.id, recommendation.owner_user_id],
  ]);
});

Deno.test("duplicate-race reload errors remain generic and identify the reload stage", async () => {
  const fake = new FakeDependencies();
  fake.saveResult = { data: null, error: { code: "23505" } };
  fake.analysisResults = [
    { data: null, error: null },
    {
      data: null,
      error: {
        code: "42501",
        message: "sensitive database message",
        details: "sensitive row details",
        hint: "sensitive database hint",
      },
    },
  ];

  const response = await createAnalysisHandler(fake.dependencies)(request());
  const body = await response.json();

  assertEquals(response.status, 500);
  assertEquals(body, {
    error: {
      code: "PERSISTENCE_ERROR",
      message: "Unable to load saved AI analysis.",
    },
  });
  assertEquals(fake.providerCalls, 1);
  assertEquals(fake.analysisLookups, 2);
  assertEquals(fake.reportedErrors, [
    {
      event: "generate_recommendation_analysis_error",
      stage: "save_analysis",
      code: "23505",
    },
    {
      event: "generate_recommendation_analysis_error",
      stage: "reload_after_duplicate",
      code: "42501",
    },
  ]);
  assertEquals(JSON.stringify(body).includes("sensitive"), false);
});

Deno.test("duplicate-race empty reload remains generic and reports unknown", async () => {
  const fake = new FakeDependencies();
  fake.saveResult = { data: null, error: { code: "23505" } };
  fake.analysisResults = [
    { data: null, error: null },
    { data: null, error: null },
  ];

  const response = await createAnalysisHandler(fake.dependencies)(request());
  const body = await response.json();

  assertEquals(response.status, 500);
  assertEquals(body, {
    error: {
      code: "PERSISTENCE_ERROR",
      message: "Unable to load saved AI analysis.",
    },
  });
  assertEquals(fake.reportedErrors, [
    {
      event: "generate_recommendation_analysis_error",
      stage: "save_analysis",
      code: "23505",
    },
    {
      event: "generate_recommendation_analysis_error",
      stage: "reload_after_duplicate",
      code: "unknown",
    },
  ]);
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
  generateError: unknown | null = null;
  providerCalls = 0;
  recommendationLookups = 0;
  analysisLookups = 0;
  readonly savedRows: SavedAnalysis[] = [];
  readonly reportedErrors: ServerErrorEvent[] = [];
  readonly recommendationLookupArguments: string[][] = [];
  readonly analysisLookupArguments: string[][] = [];
  reporter: (event: ServerErrorEvent) => void | PromiseLike<void> = (event) => {
    this.reportedErrors.push(event);
  };
  readonly dependencies: AnalysisDependencies;

  constructor() {
    this.dependencies = new AnalysisDependencies(
      async (_) => this.authResult,
      async (recommendationId, ownerUserId) => {
        this.recommendationLookups++;
        this.recommendationLookupArguments.push([
          recommendationId,
          ownerUserId,
        ]);
        return this.recommendationResult;
      },
      async (recommendationId, ownerUserId) => {
        const index = this.analysisLookups++;
        this.analysisLookupArguments.push([recommendationId, ownerUserId]);
        return this.analysisResults?.[index] ?? this.analysisResult;
      },
      async (_) => {
        this.providerCalls++;
        if (this.generateError) throw this.generateError;
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
      (event) => this.reporter(event),
    );
  }
}
