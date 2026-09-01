import {
  AnalysisContract,
  buildAnalysisPrompt,
  DeterministicFacts,
  parseAnalysis,
} from "./analysis_contract.ts";

export const groqEndpoint = "https://api.groq.com/openai/v1/chat/completions";
export const groqModelIdentifier = "openai/gpt-oss-20b";
export const groqTimeoutMs = 20_000;

export type ProviderTelemetry = {
  stage: "provider_configuration" | "provider_request" | "provider_response";
  code:
    | "missing_api_key"
    | "network_failure"
    | "timeout"
    | "http_400"
    | "http_401"
    | "http_403"
    | "http_429"
    | "http_5xx"
    | "http_other"
    | "invalid_structured_response";
};

export class GroqProviderError extends Error {
  constructor(
    readonly kind: "unavailable" | "invalid_response",
    readonly telemetry: ProviderTelemetry,
  ) {
    super(kind);
  }
}

type FetchImplementation = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;

export type GroqGeneratorOptions = {
  apiKey: string | undefined;
  fetchImpl?: FetchImplementation;
  timeoutMs?: number;
  abortControllerFactory?: () => AbortController;
};

export function createGroqGenerator({
  apiKey,
  fetchImpl = fetch,
  timeoutMs = groqTimeoutMs,
  abortControllerFactory = () => new AbortController(),
}: GroqGeneratorOptions): (
  facts: DeterministicFacts,
) => Promise<AnalysisContract> {
  return async (facts) => {
    const key = apiKey?.trim();
    if (!key) {
      throw new GroqProviderError("unavailable", {
        stage: "provider_configuration",
        code: "missing_api_key",
      });
    }

    const controller = abortControllerFactory();
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, timeoutMs);

    let response: Response;
    try {
      response = await fetchImpl(groqEndpoint, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${key}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(groqRequestBody(facts)),
        signal: controller.signal,
      });
    } catch {
      throw new GroqProviderError("unavailable", {
        stage: "provider_request",
        code: timedOut ? "timeout" : "network_failure",
      });
    } finally {
      clearTimeout(timer);
    }

    if (timedOut) {
      throw new GroqProviderError("unavailable", {
        stage: "provider_request",
        code: "timeout",
      });
    }
    if (!response.ok) {
      throw new GroqProviderError("unavailable", {
        stage: "provider_response",
        code: httpCode(response.status),
      });
    }

    let payload: unknown;
    try {
      payload = await response.json();
    } catch {
      throw invalidResponse();
    }

    try {
      const content = completionContent(payload);
      return parseAnalysis(content, {
        allowedIdentifiers: [facts.vehicle_id, facts.route_id]
          .filter((value): value is string => Boolean(value)),
      });
    } catch {
      throw invalidResponse();
    }
  };
}

function groqRequestBody(facts: DeterministicFacts) {
  return {
    model: groqModelIdentifier,
    messages: [{ role: "user", content: buildAnalysisPrompt(facts) }],
    temperature: 0.1,
    max_completion_tokens: 2048,
    stream: false,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "recommendation_analysis",
        strict: true,
        schema: {
          type: "object",
          properties: {
            summary: { type: "string" },
            rationale: { type: "array", items: { type: "string" } },
            limitations: { type: "array", items: { type: "string" } },
            staffReviewChecklist: {
              type: "array",
              items: { type: "string" },
            },
          },
          required: [
            "summary",
            "rationale",
            "limitations",
            "staffReviewChecklist",
          ],
          additionalProperties: false,
        },
      },
    },
  };
}

function completionContent(payload: unknown): string {
  if (!payload || typeof payload !== "object") throw invalidResponse();
  const choices = (payload as { choices?: unknown }).choices;
  if (!Array.isArray(choices) || choices.length === 0) throw invalidResponse();
  const choice = choices[0];
  if (!choice || typeof choice !== "object") throw invalidResponse();
  const finishReason = (choice as { finish_reason?: unknown }).finish_reason;
  if (finishReason !== undefined && finishReason !== "stop") {
    throw invalidResponse();
  }
  const message = (choice as { message?: unknown }).message;
  if (!message || typeof message !== "object") throw invalidResponse();
  const content = (message as { content?: unknown }).content;
  if (typeof content !== "string" || !content.trim()) throw invalidResponse();
  return content;
}

function httpCode(status: number): ProviderTelemetry["code"] {
  if (status === 400) return "http_400";
  if (status === 401) return "http_401";
  if (status === 403) return "http_403";
  if (status === 429) return "http_429";
  if (status >= 500 && status <= 599) return "http_5xx";
  return "http_other";
}

function invalidResponse(): GroqProviderError {
  return new GroqProviderError("invalid_response", {
    stage: "provider_response",
    code: "invalid_structured_response",
  });
}
