import { createClient } from "npm:@supabase/supabase-js@2";
import { buildGeminiPrompt, parseAnalysis } from "./analysis_contract.ts";

const headers = { "Content-Type": "application/json" };
const safe = (status: number, code: string, message: string) =>
  new Response(JSON.stringify({ error: { code, message } }), { status, headers });

Deno.serve(async (request) => {
  if (request.method !== "POST") return safe(405, "INVALID_REQUEST", "Use POST.");
  const authorization = request.headers.get("Authorization");
  if (!authorization) return safe(401, "AUTH_REQUIRED", "Sign in is required.");
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (!url || !anonKey || !serviceKey || !geminiKey) {
    return safe(503, "PERSISTENCE_ERROR", "Analysis service is not configured.");
  }
  const caller = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: authData } = await caller.auth.getUser();
  const user = authData.user;
  if (!user) return safe(401, "AUTH_REQUIRED", "Sign in is required.");
  let body: unknown;
  try { body = await request.json(); } catch { return safe(400, "INVALID_REQUEST", "Invalid request body."); }
  const recommendationId = typeof (body as Record<string, unknown>)?.recommendationId === "string"
    ? ((body as Record<string, string>).recommendationId).trim()
    : "";
  if (!recommendationId) return safe(400, "INVALID_REQUEST", "Recommendation ID is required.");

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: existing } = await admin.from("recommendation_analyses")
    .select("recommendation_id").eq("recommendation_id", recommendationId).maybeSingle();
  if (existing) return safe(409, "ANALYSIS_EXISTS", "Analysis is already saved.");
  const { data: recommendation } = await admin.from("recommendations")
    .select("id,owner_user_id,vehicle_id,route_id,score,actions_snapshot,evidence_snapshot,confidence_details")
    .eq("id", recommendationId).eq("owner_user_id", user.id).maybeSingle();
  if (!recommendation) return safe(404, "NOT_FOUND", "Recommendation was not found.");

  const prompt = buildGeminiPrompt(recommendation);
  let provider: Response;
  try {
    provider = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${encodeURIComponent(geminiKey)}`,
      {
        method: "POST",
        headers,
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.1,
            responseMimeType: "application/json",
            responseSchema: {
              type: "OBJECT",
              required: exactResponseFields,
              properties: {
                summary: { type: "STRING" },
                rationale: { type: "ARRAY", items: { type: "STRING" } },
                limitations: { type: "ARRAY", items: { type: "STRING" } },
                staffReviewChecklist: { type: "ARRAY", items: { type: "STRING" } },
              },
            },
          },
        }),
      },
    );
  } catch {
    return safe(503, "PROVIDER_UNAVAILABLE", "AI analysis is temporarily unavailable.");
  }
  if (!provider.ok) return safe(503, "PROVIDER_UNAVAILABLE", "AI analysis is temporarily unavailable.");
  let analysis;
  try {
    const response = await provider.json();
    const raw = response?.candidates?.[0]?.content?.parts?.[0]?.text;
    analysis = parseAnalysis(raw, {
      allowedIdentifiers: [recommendation.vehicle_id, recommendation.route_id].filter(Boolean),
    });
  } catch {
    return safe(502, "INVALID_MODEL_RESPONSE", "AI analysis could not be validated.");
  }
  const generatedAt = new Date().toISOString();
  const { error } = await admin.from("recommendation_analyses").insert({
    recommendation_id: recommendation.id,
    owner_user_id: user.id,
    model_identifier: "gemini-2.5-flash",
    schema_version: 1,
    summary: analysis.summary,
    rationale: analysis.rationale,
    limitations: analysis.limitations,
    staff_review_checklist: analysis.staffReviewChecklist,
    generated_at: generatedAt,
  });
  if (error?.code === "23505") return safe(409, "ANALYSIS_EXISTS", "Analysis is already saved.");
  if (error) return safe(500, "PERSISTENCE_ERROR", "Unable to save AI analysis.");
  return new Response(JSON.stringify({ ...analysis, modelIdentifier: "gemini-2.5-flash", schemaVersion: 1, generatedAt }), { status: 201, headers });
});

const exactResponseFields = ["summary", "rationale", "limitations", "staffReviewChecklist"];
