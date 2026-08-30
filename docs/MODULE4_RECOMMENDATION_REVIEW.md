# Module 4 Recommendation Review

## Data flow

Module 4's deterministic Dart rule engine creates the actions, evidence, score, and explainable `confidenceDetails`. Those values are persisted as immutable snapshots in Supabase and cached per authenticated owner in SQLite v5. Staff reviews the snapshot, then explicitly accepts or rejects it through the version-checked `decide_recommendation` RPC.

The `generate-recommendation-analysis` Edge Function authenticates the caller, verifies ownership, reads the stored deterministic facts, and asks `gemini-2.5-flash` for a structured explanation. Gemini may provide only a summary, rationale, limitations, and staff checklist. It cannot change the recommendation, make the decision, create a Work Order, or trigger an operational action. One successful analysis is immutable; a failed first attempt remains retryable and never blocks Accept or Reject.

After acceptance, staff may click **Prepare Work Order**. This opens a new editable create form with vehicle, incident/recommendation linkage, high priority, and reviewable description/notes. No Work Order exists until staff presses **Review and save**.

## Configure and deploy manually

No API key is committed. Create a free-tier Gemini key in Google AI Studio, then set it only as a Supabase Edge Function secret:

```powershell
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase secrets set GEMINI_API_KEY=YOUR_GEMINI_KEY
```

Apply the additive database migration and deploy the function:

```powershell
supabase db push --linked
supabase functions deploy generate-recommendation-analysis --project-ref YOUR_PROJECT_REF
```

For local database verification:

```powershell
supabase start
supabase test db
```

For the pure Edge Function contract tests (requires Deno):

```powershell
deno test supabase/functions/generate-recommendation-analysis/analysis_contract_test.ts
```

## End-to-end verification

1. Apply the migration and deploy the Edge Function using the commands above.
2. Sign in to PrasaAssist as a test staff user.
3. Insert or generate a caller-owned pending deterministic recommendation through the approved Module 4 persistence path; use Bus B1023, Route 300, score 85, two replacement buses, and the approved confidence snapshot for the shared demo.
4. Open **AI Recommendations** and confirm actions, evidence provenance, score, and confidence are unchanged.
5. Confirm the Gemini panel saves one explanation or shows **Analysis unavailable** with Retry while Accept and Reject remain enabled.
6. Accept the recommendation and confirm actor, UTC time, and incremented version are stored before any hand-off.
7. Click **Prepare Work Order**, edit any prefilled value, and press **Review and save** explicitly.
8. Repeat with two sessions using the same starting version; confirm the second decision returns a refresh/retry conflict instead of overwriting the first.

The application contains no Gemini secret, does not claim unsupported live occupancy or rail data, and performs no automatic deployment, maintenance, or Work Order creation.
