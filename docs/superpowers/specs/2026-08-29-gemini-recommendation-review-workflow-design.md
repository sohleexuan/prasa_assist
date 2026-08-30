# Gemini Recommendation Review Workflow Design

## Purpose and boundaries

This milestone turns Module 4's existing deterministic recommendation output into a persisted staff-review workflow. The deterministic rule engine remains authoritative for actions, evidence, score, and `confidenceDetails`. Gemini 2.5 Flash adds only a short explanatory snapshot. The governing interaction remains: **AI recommends. Staff decides.** No recommendation decision, deployment, maintenance action, navigation, or Work Order creation happens automatically.

The approved Bus B1023 / Route 300 policy remains byte-for-byte equivalent in behaviour: a confirmed breakdown contributes 50, peak Route 300 deployment contributes 35, the score is 85, two replacement buses are recommended, confidence weights are 0.60 and 0.40 with one demonstration penalty of 0.15, and off-peak recommendations inspect/repair only. Score and confidence remain independent, and `confidenceDetails` is the only confidence source.

## Architecture

The Flutter client uses a Module 4 repository boundary with Supabase as the remote authority and SQLite v5 as owner-scoped offline cache. Storage-neutral DTOs and mappers serialize deterministic actions, evidence, and confidence details as validated JSON snapshots. Recommendation decisions are sent through an atomic Supabase RPC with the currently displayed remote version. A version mismatch is surfaced as a safe conflict that requires refresh.

One immutable `recommendation_analyses` row may belong to each recommendation. Flutter invokes the `generate-recommendation-analysis` Edge Function. The function authenticates the JWT, loads the caller-owned recommendation from the database, constructs a conservative prompt from stored deterministic facts, calls `gemini-2.5-flash`, validates the structured JSON response, and inserts the first successful snapshot. A unique foreign key enforces one snapshot. Failed calls do not create a row, so Retry remains available; a saved snapshot disables regeneration.

The recommendation detail screen is the decision surface. It displays deterministic actions, score, explainable confidence factors and penalties, evidence classifications, current status, and the separate AI-generated explanation panel. Accept and Reject remain available when analysis is unavailable. Accept is persisted before the UI exposes a separate `Prepare Work Order` control.

## Persistence model

`recommendations` stores:

- UUID `id`, owner UUID, optional incident identifier, vehicle identifier, and optional route identifier.
- JSON arrays for immutable deterministic action and evidence snapshots.
- integer deterministic score and JSON confidence-details snapshot.
- `pending_review`, `accepted`, or `rejected` status.
- decision user UUID, UTC decision timestamp, and optional decision note.
- positive `version` for optimistic concurrency and UTC created/updated timestamps.

`recommendation_analyses` stores one row per recommendation using `recommendation_id` as both primary key and foreign key, plus owner UUID, `gemini-2.5-flash`, response schema/prompt version `1`, summary, rationale, limitations, staff-review checklist, and UTC generation time. Database triggers reject updates and owner mismatches. RLS restricts both tables to `auth.uid() = owner_user_id`; direct analysis insertion is not granted to authenticated clients, because the Edge Function uses its server client after independently authenticating and authorizing the caller.

SQLite v5 adds `local_recommendation_records` and `local_recommendation_analyses`. Both are owner-scoped; the analysis has a composite foreign key to its owner-matched recommendation and uses `ON DELETE CASCADE`. Remote timestamps and versions are preserved as UTC strings. Recommendation rows use the established `cached_remote`, `local_draft`, `pending_publication`, `publication_failed`, and `conflict` states, although this milestone normally writes confirmed remote records and caches them. Versions 1 through 4 are not edited.

## Domain and client behaviour

`OperationsRecommendation` gains persistence metadata and optional decision fields without changing the deterministic rule engine inputs or calculations. Invariants require pending recommendations to have no decision metadata and decided recommendations to have actor and timestamp. `RecommendationAnalysis` validates non-empty, bounded lists and normalizes its generated timestamp to UTC. The response parser accepts only the four contract keys, rejects additional keys, wrong types, blanks, excessive items, and operational claims that introduce unsupported facts or attempt to change deterministic outputs.

The repository provides owner-scoped list/read, first-analysis generation, and `decide` operations. It maps PostgREST conflict code `40001` to a safe refresh message and never forwards raw provider errors. Analysis failure is represented separately from recommendation failure so staff can still decide.

The Module 4 controller injects a clock only for local state/test orchestration; deterministic rule evaluation never calls `DateTime.now()`. It suppresses duplicate decision and analysis requests and refreshes the affected record after successful remote writes.

## Work Order hand-off

Module 2 receives a typed `WorkOrderPrefill` with optional incident/recommendation IDs, vehicle, task type, description, notes, and priority. `WorkOrderFormPage` accepts it only when `workOrder == null`; edit mode remains driven exclusively by an existing `WorkOrder`. Initial controllers use the prefill, remain editable, and the create submission passes both linkage IDs through the existing controller and v4-backed DTO/mapper path. The accepted recommendation creates no record until staff opens the form and explicitly presses Save. Confirmed breakdown defaults to high priority and inspection task wording; a saved Gemini summary may be appended as clearly AI-generated reviewable text.

## UI and error handling

The list uses concise status chips and deterministic score/confidence summaries. Detail content uses existing theme tokens and section cards. The Gemini panel has loading, saved, and safe unavailable states; Retry appears only without a saved snapshot. Copy labels the panel AI-generated and states that staff must decide. Accept and Reject buttons are disabled during a decision. Rejection note is optional. A stale version shows a refresh-and-retry message without overwriting the newer decision.

After acceptance, `Prepare Work Order` is explicit and opens a new form. Rejection never offers the hand-off. Actor and UTC decision time are shown when present.

## Edge Function contract and safety

The request body contains only `recommendationId`. The function obtains the caller from the Authorization header through Supabase Auth, queries the owner-scoped stored snapshot, and never trusts deterministic facts supplied by Flutter. It requests JSON with exactly `summary`, `rationale`, `limitations`, and `staffReviewChecklist`. The prompt forbids new facts, operational execution, decisions, and changes to actions/evidence/score/confidence. Server validation runs before persistence.

Safe response codes include `AUTH_REQUIRED`, `NOT_FOUND`, `ANALYSIS_EXISTS`, `INVALID_REQUEST`, `PROVIDER_UNAVAILABLE`, `INVALID_MODEL_RESPONSE`, and `PERSISTENCE_ERROR`. Provider bodies, API keys, prompts containing secrets, and chain-of-thought are never returned. The only secret is `GEMINI_API_KEY`, configured in Supabase. No secret is committed.

## Verification

TDD covers JSON parsing and isolation from deterministic data; immutable success/failure/retry; decision transitions, optional notes, actor/time, and conflict; SQLite fresh v5 and actual v4-to-v5 upgrade; relationship and owner scoping; DTO UTC/version round trips; accepted recommendation hand-off; editable create-mode prefill; and absence of automatic Work Order creation. Existing deterministic tests remain unchanged and green.

Final verification runs `dart format` on touched Dart files, focused tests during each red/green cycle, `flutter analyze`, full `flutter test`, `git diff --check`, and final status inspection. Edge Function pure helper tests run with `deno test` when Deno is installed; otherwise the exact command is documented for manual execution.

