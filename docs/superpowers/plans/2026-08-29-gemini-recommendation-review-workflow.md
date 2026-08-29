# Gemini Recommendation Review Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist deterministic Module 4 recommendations, add immutable Gemini explanations, implement staff decisions, and hand accepted breakdowns to a new editable Module 2 Work Order form.

**Architecture:** Supabase is authoritative, SQLite v5 is an owner-scoped cache, and Flutter follows existing DTO/mapper/repository patterns. A Supabase Edge Function is the only Gemini caller and persists one validated explanation snapshot; an RPC atomically decides a pending recommendation using optimistic concurrency.

**Tech Stack:** Flutter/Dart, sqflite, supabase_flutter, PostgreSQL/RLS/PLpgSQL, Supabase Edge Functions/Deno TypeScript, Gemini REST API.

**Spec:** `docs/superpowers/specs/2026-08-29-gemini-recommendation-review-workflow-design.md`

## Global Constraints

- Preserve SQLite migrations v1-v4 byte-for-byte; the new local migration is v5.
- Do not add a Flutter production dependency or change shared architecture.
- Gemini model is exactly `gemini-2.5-flash` and may only explain stored deterministic facts.
- Gemini cannot change actions, evidence, score, confidence, status, or create a Work Order.
- Staff decisions and Work Order saves are explicit; accept is recorded before hand-off.
- All stored timestamps are UTC-normalized and deterministic logic contains no `DateTime.now()`.
- No secret, raw provider error, unsupported real-time claim, or automatic operational action is introduced.

---

### Task 1: Domain snapshots and validation

**Files:**
- Create: `lib/features/recommendations/domain/recommendation_analysis.dart`
- Create: `lib/features/recommendations/data/recommendation_serialization.dart`
- Modify: `lib/features/recommendations/domain/recommendation.dart`
- Test: `test/features/recommendations/domain/recommendation_analysis_test.dart`
- Test: `test/features/recommendations/data/recommendation_serialization_test.dart`

**Interfaces:**
- Produces `RecommendationAnalysis.fromJson`, deterministic snapshot encoders/decoders, and persistence/decision metadata on `OperationsRecommendation`.

- [ ] Write tests proving strict analysis shape validation, UTC normalization, immutable lists, and rejection of extra/malformed fields.
- [ ] Run the focused tests and confirm they fail because the types do not exist.
- [ ] Implement the minimal domain/parser code without exposing mutation of deterministic fields.
- [ ] Run the focused tests and existing deterministic recommendation tests.
- [ ] Refactor only while all focused tests remain green.

### Task 2: SQLite v5 and owner-scoped local source

**Files:**
- Create: `lib/core/database/migrations/app_database_migration_v5.dart`
- Modify: `lib/core/database/app_database_schema.dart`
- Create: `lib/features/recommendations/data/dto/recommendation_record_dto.dart`
- Create: `lib/features/recommendations/data/sources/recommendation_local_data_source.dart`
- Create: `lib/features/recommendations/data/sources/sqlite_recommendation_local_data_source.dart`
- Test: `test/core/database/app_database_migration_v5_test.dart`
- Test: `test/features/recommendations/data/sources/sqlite_recommendation_local_data_source_test.dart`

**Interfaces:**
- Produces `RecommendationRecordDto`, `readAll`, `readById`, and `upsert` with an optional one-to-one `RecommendationAnalysis`.

- [ ] Write failing fresh-v5, real-v4-upgrade, rollback, owner scope, relationship, UTC, and remote-version tests.
- [ ] Run them and confirm schema/version failures.
- [ ] Add only v5 tables/indexes and register v5 after v4.
- [ ] Implement DTO mapping and owner-qualified SQLite reads/writes.
- [ ] Run migration and source tests until green, then run all database tests.

### Task 3: Supabase schema, decision RPC, and SQL tests

**Files:**
- Create: `supabase/migrations/20260829000000_recommendation_review.sql`
- Create: `supabase/tests/recommendations_test.sql`

**Interfaces:**
- Produces owner-scoped `recommendations`, immutable `recommendation_analyses`, and `decide_recommendation(p_recommendation_id, p_decision, p_note, p_expected_version)`.

- [ ] Write pgTAP assertions for constraints, RLS ownership, one analysis, legal transitions, optional rejection note, actor/time, and stale-version conflict.
- [ ] Add tables, constraints, indexes, triggers, grants, RLS policies, and atomic decision RPC following existing SQL conventions.
- [ ] Run `supabase test db` when the local Supabase CLI/runtime is available; otherwise record the same command for manual verification.

### Task 4: Edge Function and pure validation tests

**Files:**
- Create: `supabase/functions/generate-recommendation-analysis/analysis_contract.ts`
- Create: `supabase/functions/generate-recommendation-analysis/analysis_contract_test.ts`
- Create: `supabase/functions/generate-recommendation-analysis/index.ts`
- Create: `supabase/functions/.env.example`

**Interfaces:**
- Produces `parseAnalysis`, `buildGeminiPrompt`, and HTTP POST `{ recommendationId }` with safe error responses.

- [ ] Write Deno tests rejecting extra keys, wrong shapes, blanks, excessive lists, invented identifiers, and output that attempts deterministic changes.
- [ ] Run `deno test supabase/functions/generate-recommendation-analysis/analysis_contract_test.ts` and confirm missing implementation failure.
- [ ] Implement conservative prompt construction and strict parser.
- [ ] Implement authenticated ownership lookup, Gemini structured-output request, validation, immutable insert, and safe errors.
- [ ] Run Deno tests if Deno exists; retain the exact manual command otherwise.

### Task 5: Remote repository and review controller

**Files:**
- Create: `lib/features/recommendations/data/sources/recommendation_remote_data_source.dart`
- Create: `lib/features/recommendations/data/sources/supabase_recommendation_remote_data_source.dart`
- Create: `lib/features/recommendations/repositories/recommendation_repository.dart`
- Create: `lib/features/recommendations/repositories/hybrid_recommendation_repository.dart`
- Create: `lib/features/recommendations/repositories/recommendation_data_exception.dart`
- Create: `lib/features/recommendations/controllers/recommendation_controller.dart`
- Test: corresponding files under `test/features/recommendations/`.

**Interfaces:**
- Produces owner-safe list/read, immutable first analysis, `decide(... expectedVersion ...)`, loading states, duplicate suppression, and safe conflict messages.

- [ ] Write failing repository/controller tests for cache fallback, analysis failure/retry/success, immutable analysis, decisions, and concurrency conflict.
- [ ] Implement remote DTO mapping and safe PostgREST/Function error classification.
- [ ] Implement hybrid cache refresh/fallback and controller operation state.
- [ ] Run focused tests and refactor with green tests.

### Task 6: Minimal Module 2 prefill bridge

**Files:**
- Create: `lib/features/work_orders/models/work_order_prefill.dart`
- Modify: `lib/features/work_orders/pages/work_order_form_page.dart`
- Test: `test/features/work_orders/pages/work_order_form_page_test.dart`
- Test: `test/features/recommendations/integration/recommendation_work_order_handoff_test.dart`

**Interfaces:**
- Produces `WorkOrderPrefill` and `WorkOrderFormPage(prefill: ...)` in create mode. Existing `WorkOrdersController.createDraft` carries the already-supported optional IDs.

- [ ] Write failing tests for high-priority editable prefill, incident/recommendation linkage, create-mode title, and zero records before Save.
- [ ] Implement the typed prefill and initialize create-mode fields without altering edit mode.
- [ ] Pass linkage IDs through create submission and keep all fields editable.
- [ ] Run Module 2 focused tests and verify old call sites.

### Task 7: Recommendation list/detail UI and app wiring

**Files:**
- Create: `lib/features/recommendations/pages/recommendation_list_page.dart`
- Create: `lib/features/recommendations/pages/recommendation_detail_page.dart`
- Create: `lib/features/recommendations/widgets/recommendation_analysis_panel.dart`
- Modify: `lib/app/module_registry.dart`
- Test: corresponding widget and registry tests.

**Interfaces:**
- Consumes the controller/repository and `WorkOrderPrefill`; exposes explicit Accept, Reject, Retry, Refresh, and Prepare Work Order actions.

- [ ] Write failing widget tests for deterministic content, all analysis states, decision disabling/conflict, accepted metadata, and explicit hand-off.
- [ ] Implement accessible responsive list/detail screens using existing theme and shared widgets.
- [ ] Wire authenticated owner scope, Supabase/SQLite sources, and Work Order create-form navigation in the registry.
- [ ] Run focused widget tests and the existing app tests.

### Task 8: Documentation and final verification

**Files:**
- Create: `docs/MODULE4_RECOMMENDATION_REVIEW.md`

- [ ] Document architecture, Gemini limitations, `GEMINI_API_KEY`, migration/deploy placeholders, real free-tier verification, and no-secret/no-automatic-action guarantees.
- [ ] Run `dart format` on every touched Dart file.
- [ ] Run focused recommendation, Work Order, and migration tests.
- [ ] Run `flutter analyze` and full `flutter test`.
- [ ] Run Edge Function/SQL tests when their runtimes exist and otherwise report exact manual commands.
- [ ] Run `git diff --check`, inspect generated-file diffs, restore only allowlisted line-ending-only generated files if needed, and inspect final status.
- [ ] Commit logically complete verified milestones without pushing or creating a PR.

