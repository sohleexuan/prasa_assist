import { createClient } from "npm:@supabase/supabase-js@2";
import {
  AnalysisDependencies,
  createAnalysisHandler,
  SavedAnalysis,
} from "./handler.ts";
import { createGroqGenerator } from "./groq_provider.ts";

const url = Deno.env.get("SUPABASE_URL");
const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const groqKey = Deno.env.get("GROQ_API_KEY");

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
  const generate = createGroqGenerator({ apiKey: groqKey });
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
      generate,
      async (analysis: SavedAnalysis) => {
        const { error } = await admin.from("recommendation_analyses").insert(
          analysis,
        );
        return { data: null, error };
      },
      () => new Date(),
      (event) => console.error(JSON.stringify(event)),
    ),
  );
  Deno.serve(handler);
}
