import { createClient } from "npm:@supabase/supabase-js@2";
import { buildGeminiPrompt, parseAnalysis } from "./analysis_contract.ts";
import {
  AnalysisDependencies,
  createAnalysisHandler,
  ProviderError,
  SavedAnalysis,
} from "./handler.ts";

const url = Deno.env.get("SUPABASE_URL");
const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const geminiKey = Deno.env.get("GEMINI_API_KEY");

if (!url || !anonKey || !serviceKey) {
  Deno.serve(() =>
    new Response(
      JSON.stringify({
        error: {
          code: "PERSISTENCE_ERROR",
          message: "Analysis service is not configured.",
        },
      }),
      { status: 503, headers: { "Content-Type": "application/json" } },
    )
  );
} else {
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false },
  });
  const handler = createAnalysisHandler(
    new AnalysisDependencies(
      async (authorization) => {
        const caller = createClient(url, anonKey, {
          global: { headers: { Authorization: authorization } },
          auth: { persistSession: false },
        });
        const { data, error } = await caller.auth.getUser();
        return { userId: data.user?.id ?? null, error };
      },
      async (recommendationId, ownerUserId) => {
        const { data, error } = await admin.from("recommendations")
          .select(
            "id,owner_user_id,vehicle_id,route_id,score,status,actions_snapshot,evidence_snapshot,confidence_details",
          )
          .eq("id", recommendationId)
          .eq("owner_user_id", ownerUserId)
          .maybeSingle();
        return { data, error };
      },
      async (recommendationId, ownerUserId) => {
        const { data, error } = await admin.from("recommendation_analyses")
          .select(
            "recommendation_id,owner_user_id,model_identifier,schema_version,summary,rationale,limitations,staff_review_checklist,generated_at",
          )
          .eq("recommendation_id", recommendationId)
          .eq("owner_user_id", ownerUserId)
          .maybeSingle();
        return { data, error };
      },
      async (recommendation) => {
        if (!geminiKey) throw new ProviderError("unavailable");
        let provider: Response;
        try {
          provider = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${
              encodeURIComponent(geminiKey)
            }`,
            {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                contents: [{
                  parts: [{ text: buildGeminiPrompt(recommendation) }],
                }],
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
                      staffReviewChecklist: {
                        type: "ARRAY",
                        items: { type: "STRING" },
                      },
                    },
                  },
                },
              }),
            },
          );
        } catch {
          throw new ProviderError("unavailable");
        }
        if (!provider.ok) throw new ProviderError("unavailable");
        try {
          const response = await provider.json();
          const raw = response?.candidates?.[0]?.content?.parts?.[0]?.text;
          return parseAnalysis(raw, {
            allowedIdentifiers: [
              recommendation.vehicle_id,
              recommendation.route_id,
            ]
              .filter((value): value is string => Boolean(value)),
          });
        } catch {
          throw new ProviderError("invalid_response");
        }
      },
      async (analysis: SavedAnalysis) => {
        const { error } = await admin.from("recommendation_analyses").insert(
          analysis,
        );
        return { data: null, error };
      },
      () => new Date(),
    ),
  );
  Deno.serve(handler);
}

const exactResponseFields = [
  "summary",
  "rationale",
  "limitations",
  "staffReviewChecklist",
];
