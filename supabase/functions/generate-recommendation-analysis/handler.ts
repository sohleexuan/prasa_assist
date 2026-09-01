import { AnalysisContract, DeterministicFacts } from "./analysis_contract.ts";

const headers = { "Content-Type": "application/json" };

export type DatabaseError = { code?: string };
export type DatabaseResult<T> = {
  data: T | null;
  error: DatabaseError | null;
};

export type OwnedRecommendation = DeterministicFacts & {
  owner_user_id: string;
  status: string;
};

export type SavedAnalysis = {
  recommendation_id: string;
  owner_user_id: string;
  model_identifier: string;
  schema_version: number;
  summary: string;
  rationale: string[];
  limitations: string[];
  staff_review_checklist: string[];
  generated_at: string;
};

export type AuthResult = {
  userId: string | null;
  error: unknown | null;
};

export class ProviderError extends Error {
  constructor(readonly kind: "unavailable" | "invalid_response") {
    super(kind);
  }
}

export class AnalysisDependencies {
  constructor(
    readonly authenticate: (authorization: string) => Promise<AuthResult>,
    readonly findOwnedRecommendation: (
      recommendationId: string,
      ownerUserId: string,
    ) => Promise<DatabaseResult<OwnedRecommendation>>,
    readonly findAnalysis: (
      recommendationId: string,
      ownerUserId: string,
    ) => Promise<DatabaseResult<SavedAnalysis>>,
    readonly generate: (
      recommendation: OwnedRecommendation,
    ) => Promise<AnalysisContract>,
    readonly saveAnalysis: (
      analysis: SavedAnalysis,
    ) => Promise<DatabaseResult<null>>,
    readonly clock: () => Date,
  ) {}
}

export function createAnalysisHandler(dependencies: AnalysisDependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return safe(405, "INVALID_REQUEST", "Use POST.");
    }
    const authorization = request.headers.get("Authorization");
    if (!authorization) {
      return safe(401, "AUTH_REQUIRED", "Sign in is required.");
    }

    const authentication = await dependencies.authenticate(authorization);
    if (authentication.error || !authentication.userId) {
      return safe(401, "AUTH_REQUIRED", "Sign in is required.");
    }

    const recommendationId = await parseRecommendationId(request);
    if (recommendationId instanceof Response) return recommendationId;

    const recommendationResult = await dependencies.findOwnedRecommendation(
      recommendationId,
      authentication.userId,
    );
    if (recommendationResult.error) {
      return safe(
        500,
        "PERSISTENCE_ERROR",
        "Recommendation data could not be read.",
      );
    }
    const recommendation = recommendationResult.data;
    if (!recommendation) {
      return safe(404, "NOT_FOUND", "Recommendation was not found.");
    }

    const existingResult = await dependencies.findAnalysis(
      recommendationId,
      authentication.userId,
    );
    if (existingResult.error) {
      return safe(
        500,
        "PERSISTENCE_ERROR",
        "Saved analysis could not be read.",
      );
    }
    if (existingResult.data) {
      return analysisResponse(existingResult.data, 200, true);
    }

    let analysis: AnalysisContract;
    try {
      analysis = await dependencies.generate(recommendation);
    } catch (error) {
      if (error instanceof ProviderError && error.kind === "invalid_response") {
        return safe(
          502,
          "INVALID_MODEL_RESPONSE",
          "AI analysis could not be validated.",
        );
      }
      return safe(
        503,
        "PROVIDER_UNAVAILABLE",
        "AI analysis is temporarily unavailable.",
      );
    }

    const saved: SavedAnalysis = {
      recommendation_id: recommendation.id,
      owner_user_id: authentication.userId,
      model_identifier: "gemini-2.5-flash",
      schema_version: 1,
      summary: analysis.summary,
      rationale: analysis.rationale,
      limitations: analysis.limitations,
      staff_review_checklist: analysis.staffReviewChecklist,
      generated_at: dependencies.clock().toISOString(),
    };
    const saveResult = await dependencies.saveAnalysis(saved);
    if (saveResult.error?.code === "23505") {
      const raced = await dependencies.findAnalysis(
        recommendationId,
        authentication.userId,
      );
      if (raced.error || !raced.data) {
        return safe(
          500,
          "PERSISTENCE_ERROR",
          "Unable to load saved AI analysis.",
        );
      }
      return analysisResponse(raced.data, 200, true);
    }
    if (saveResult.error) {
      return safe(500, "PERSISTENCE_ERROR", "Unable to save AI analysis.");
    }
    return analysisResponse(saved, 201, false);
  };
}

async function parseRecommendationId(
  request: Request,
): Promise<string | Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return safe(400, "INVALID_REQUEST", "Invalid request body.");
  }
  const recommendationId = body && typeof body === "object" &&
      typeof (body as Record<string, unknown>).recommendationId === "string"
    ? (body as Record<string, string>).recommendationId.trim()
    : "";
  if (!recommendationId) {
    return safe(400, "INVALID_REQUEST", "Recommendation ID is required.");
  }
  return recommendationId;
}

function analysisResponse(
  analysis: SavedAnalysis,
  status: number,
  existing: boolean,
): Response {
  return new Response(
    JSON.stringify({
      summary: analysis.summary,
      rationale: analysis.rationale,
      limitations: analysis.limitations,
      staffReviewChecklist: analysis.staff_review_checklist,
      modelIdentifier: analysis.model_identifier,
      schemaVersion: analysis.schema_version,
      generatedAt: analysis.generated_at,
      existing,
    }),
    { status, headers },
  );
}

function safe(status: number, code: string, message: string): Response {
  return new Response(JSON.stringify({ error: { code, message } }), {
    status,
    headers,
  });
}
