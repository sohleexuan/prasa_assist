import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createGroqGenerator, GroqProviderError } from "./groq_provider.ts";
import type { DeterministicFacts } from "./analysis_contract.ts";

const facts: DeterministicFacts = {
  id: "460d90f1-d4f1-451f-ac69-761dc972b652",
  vehicle_id: "B1023",
  route_id: "300",
  score: 85,
  actions_snapshot: [{ type: "inspect_or_repair_vehicle", vehicleId: "B1023" }],
  evidence_snapshot: [{ ruleId: "confirmed_breakdown", contribution: 50 }],
  confidence_details: { factors: [], penalties: [] },
};

const validContent = JSON.stringify({
  summary: "Inspect B1023 before return to service.",
  rationale: ["Stored breakdown evidence supports inspection."],
  limitations: ["Staff must confirm the current vehicle condition."],
  staffReviewChecklist: ["Review the stored evidence."],
});

Deno.test("Groq generator sends the bounded strict structured-output request", async () => {
  let capturedUrl = "";
  let capturedInit: RequestInit | undefined;
  const generate = createGroqGenerator({
    apiKey: "test-key",
    fetchImpl: async (url, init) => {
      capturedUrl = String(url);
      capturedInit = init;
      return responseWithContent(validContent);
    },
  });

  const result = await generate({
    ...facts,
    owner_user_id: "owner-secret",
  } as unknown as DeterministicFacts);
  const body = JSON.parse(String(capturedInit?.body));

  assertEquals(result.summary, "Inspect B1023 before return to service.");
  assertEquals(capturedUrl, "https://api.groq.com/openai/v1/chat/completions");
  assertEquals(capturedInit?.method, "POST");
  assertEquals(capturedInit?.headers, {
    "Authorization": "Bearer test-key",
    "Content-Type": "application/json",
  });
  assertEquals(body.model, "openai/gpt-oss-20b");
  assertEquals(body.temperature, 0.1);
  assertEquals(body.max_completion_tokens, 2048);
  assertEquals(body.stream, false);
  assertEquals(body.tools, undefined);
  assertEquals(body.response_format.type, "json_schema");
  assertEquals(body.response_format.json_schema.strict, true);
  assertEquals(body.response_format.json_schema.schema.required, [
    "summary",
    "rationale",
    "limitations",
    "staffReviewChecklist",
  ]);
  assertEquals(
    body.response_format.json_schema.schema.additionalProperties,
    false,
  );
  assertEquals(JSON.stringify(body).includes(facts.id), false);
  assertEquals(JSON.stringify(body).includes("owner-secret"), false);
  assertEquals(JSON.stringify(body).includes("B1023"), true);
  assertEquals(JSON.stringify(body).includes("300"), true);
});

Deno.test("Groq generator classifies network failure without exposing the error", async () => {
  const generate = createGroqGenerator({
    apiKey: "test-key",
    fetchImpl: async () => {
      throw new Error("provider transport detail");
    },
  });

  const error = await assertRejects(
    () => generate(facts),
    GroqProviderError,
  );

  assertEquals(error.telemetry, {
    stage: "provider_request",
    code: "network_failure",
  });
  assertEquals(error.message.includes("transport detail"), false);
});

Deno.test("Groq generator aborts a timed-out request with a fixed code", async () => {
  const generate = createGroqGenerator({
    apiKey: "test-key",
    timeoutMs: 1,
    fetchImpl: (_, init) =>
      new Promise<Response>((_, reject) => {
        init?.signal?.addEventListener("abort", () =>
          reject(new Error("timeout")));
      }),
  });

  const error = await assertRejects(
    () => generate(facts),
    GroqProviderError,
  );

  assertEquals(error.telemetry, {
    stage: "provider_request",
    code: "timeout",
  });
});

for (
  const [status, code] of [
    [400, "http_400"],
    [401, "http_401"],
    [403, "http_403"],
    [429, "http_429"],
    [503, "http_5xx"],
    [418, "http_other"],
  ] as const
) {
  Deno.test(`Groq generator classifies HTTP ${status} without reading the body`, async () => {
    const generate = createGroqGenerator({
      apiKey: "test-key",
      fetchImpl: async () => new Response("provider diagnostic", { status }),
    });

    const error = await assertRejects(
      () => generate(facts),
      GroqProviderError,
    );

    assertEquals(error.telemetry, { stage: "provider_response", code });
    assertEquals(error.message.includes("provider diagnostic"), false);
  });
}

for (
  const [name, response] of [
    ["missing choices", {}],
    ["missing message", { choices: [{}] }],
    ["null content", { choices: [{ message: { content: null } }] }],
    ["empty content", { choices: [{ message: { content: "" } }] }],
    ["safety refusal", { choices: [{ message: { refusal: "refused" } }] }],
    [
      "truncated completion",
      {
        choices: [{
          finish_reason: "length",
          message: { content: validContent },
        }],
      },
    ],
    [
      "non-complete finish reason",
      {
        choices: [{
          finish_reason: "content_filter",
          message: { content: validContent },
        }],
      },
    ],
  ] as const
) {
  Deno.test(`Groq generator rejects ${name}`, async () => {
    const generate = createGroqGenerator({
      apiKey: "test-key",
      fetchImpl: async () => Response.json(response),
    });

    const error = await assertRejects(
      () => generate(facts),
      GroqProviderError,
    );

    assertEquals(error.telemetry, {
      stage: "provider_response",
      code: "invalid_structured_response",
    });
  });
}

Deno.test("Groq generator rejects malformed and contract-invalid content", async () => {
  for (
    const content of [
      "not-json",
      JSON.stringify({
        ...JSON.parse(validContent),
        summary: "Dispatch B9999 automatically.",
      }),
    ]
  ) {
    const generate = createGroqGenerator({
      apiKey: "test-key",
      fetchImpl: async () => responseWithContent(content),
    });

    const error = await assertRejects(
      () => generate(facts),
      GroqProviderError,
    );
    assertEquals(error.telemetry.code, "invalid_structured_response");
  }
});

function responseWithContent(content: string): Response {
  return Response.json({
    choices: [{ finish_reason: "stop", message: { content } }],
  });
}
