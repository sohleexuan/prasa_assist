# Staff Directory Assignment Remediation Plan

> **Execution constraint:** Apply this plan to the existing unstaged patch on
> `feat/staff-directory-assignment`. Do not stage, commit, push, deploy, run the
> migration, access Auth/production data, or touch protected untracked paths.

**Goal:** Close the pre-commit security and rollout findings for verified staff
directory assignment while preserving legacy Work Order lifecycle behavior and
Incident business semantics.

**Architecture:** PostgreSQL remains the remote authorization authority. The
Flutter client uses a full directory only for identity resolution and the
assignable-directory RPC for the assignment selector. SQLite is an owner-scoped
offline cache and never authorizes a remote mutation. Rollout is an explicitly
documented maintenance-window cutover, not a mixed-version bridge.

**Tech stack:** Flutter/Dart, Supabase/PostgreSQL, SQLite/sqflite, flutter_test,
pgTAP/static SQL contract tests.

**Approved specification:** User-approved remediation brief in this session.

---

## Task 1: Enforce the SQLite v8 assignment pair invariant

**Files:**

- Modify: `lib/core/database/migrations/app_database_migration_v8.dart`
- Modify: `test/core/database/app_database_migration_v8_test.dart`

Add failing fresh-schema and real v7-to-v8 tests for both invalid half-pairs,
legacy null/null rows, valid pairs, and preserved route/schedule/publication
metadata. Add explicitly named `BEFORE INSERT` and `BEFORE UPDATE` triggers,
then rerun the focused migration test.

## Task 2: Align directory normalization and cache-failure behavior

**Files:**

- Modify: `lib/shared/staff/staff_profile.dart`
- Modify: `lib/shared/staff/staff_directory_data_source.dart`
- Modify: `lib/shared/staff/supabase_staff_directory_data_source.dart`
- Modify: `lib/shared/staff/sqlite_staff_directory_data_source.dart`
- Modify: `lib/shared/staff/staff_directory_repository.dart`
- Modify: `test/shared/staff/*.dart`

Add failing tests for canonical uppercase codes, case-insensitive uniqueness,
the assignable RPC, and successful live fetch plus failed cache write. Implement
canonicalization and return live profiles with a non-sensitive cache-warning
state; only remote transport failures may use stale cache.

## Task 3: Gate assignment UI and remove free-text/dead client paths

**Files:**

- Modify: `lib/features/work_orders/controllers/work_orders_controller.dart`
- Modify: `lib/features/work_orders/pages/work_order_detail_page.dart`
- Modify: related Work Order controller/page/data-source tests

Add failing tests proving the production path uses a staff UUID, unauthorized
profiles cannot assign, the selector loads `list_assignable_staff`, and quick
dialog dismissal is safe. Remove the non-hybrid free-text assignment API and
unused label helpers. Preserve server-side final authorization.

## Task 4: Close the Incident identity privacy gap

**Files:**

- Modify: `lib/app/module_registry.dart`
- Modify: `lib/features/incidents/pages/incident_list_page.dart`
- Modify: `lib/features/incidents/pages/incident_report_page.dart`
- Modify: `lib/features/incidents/pages/incident_detail_page.dart`
- Modify: `lib/features/incidents/models/incident_query.dart`
- Modify: related app and Incident tests

Add failing UI/search tests for bare email and UUID values while proving normal
names and staff labels remain visible/searchable. Resolve the current label via
the full staff directory and fall back to `Staff profile unavailable`. Keep the
stable UUID internal and do not change Incident storage, RPCs, estimation,
status, or workflow logic.

## Task 5: Harden and test the PostgreSQL migration

**Files:**

- Modify: `supabase/migrations/20260903100000_staff_directory_assignment.sql`
- Modify: `supabase/tests/work_orders_test.sql`
- Modify: `test/features/work_orders/data/staff_directory_assignment_sql_migration_test.dart`

Add failing static/pgTAP coverage for explicit transaction boundaries,
canonical staff codes, owner-only provisioning, inactive callers, legacy
assigned/in-progress lifecycle, fail-closed legacy RPC, non-ambiguous RPC
signatures, and helper privilege revocation. Put every mutation in one explicit
transaction without provisioning users or profiles.

## Task 6: Document the controlled rollout

**Files:**

- Add: `docs/STAFF_DIRECTORY_ROLLOUT.md`

Document the maintenance-window sequence, compatibility matrix, minimum two
real profiles as a future release prerequisite, verification, smoke tests, and
transaction/committed rollback procedures. Do not include real identities or
credentials.

## Task 7: Verify the complete unstaged patch

Format only changed Dart files. Run focused tests, static SQL tests,
`flutter analyze`, the full `flutter test` suite, `git diff --check`, a
non-printing secret scan, historical-migration comparison, `toLocal()` delta
check, and final branch/HEAD/staging/status checks. Review the complete diff and
report every changed file. Commit/integration steps are intentionally omitted
because the user requires the patch to remain unstaged.
