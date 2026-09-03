# Staff Directory and Work Order Assignment Rollout

## Release model

This change requires one controlled maintenance window. It is not a
zero-downtime or mixed-version rollout. Do not resume Work Order assignment
until the database migration, owner-controlled profile provisioning, new App
rollout, and smoke checks have all succeeded.

Do not use `supabase db push` for this production change, do not fabricate or
manually edit the production migration ledger, and do not assume the migration
can be executed more than once. The migration contains non-idempotent object
creation and must be treated as a one-time reviewed operation.

## Compatibility matrix

| Database | Staff profiles | App | Assignment result |
| --- | --- | --- | --- |
| Old | Not applicable | New | Incompatible: the new directory and UUID assignment RPCs do not exist |
| New | Provisioned or not | Old | Incompatible: the legacy free-text assignment RPC fails closed |
| New | Missing or invalid | New | Rejected: directory access and assignment fail closed |
| New | Valid minimum profiles | New | Supported after smoke verification |

Non-assignment Work Order operations remain available only as confirmed by the
maintenance-window smoke tests and the reviewed migration test evidence. Do
not use that fact to allow old and new clients to overlap for assignment.

## Minimum release prerequisites

Before the window, identify at least two distinct, approved Supabase Auth users
and prepare their profile data without placing it in source control:

- One active `supervisor` or `control_centre` profile to perform assignment.
- One active `maintenance_staff` profile to receive assignment.

Each Auth user has exactly one staff profile and one role. A single account
cannot satisfy both prerequisites. Staff codes must be trimmed, uppercase, and
unique without regard to case. Do not use an email address as a display name or
staff-facing label.

Profile provisioning is an administrative operation for the PostgreSQL owner
through a controlled Supabase SQL Editor session. The `service_role`,
`authenticated`, and `anon` roles are not provisioning paths.

## Maintenance-window procedure

1. Announce the window and pause all Work Order assignment activity. Confirm
   old App sessions cannot continue assigning during the cutover.
2. Export an access-controlled, non-sensitive backup of the existing staff and
   Work Order assignment state. Do not place credentials, Auth metadata, email
   addresses, or other identity data in logs, tickets, or source control.
3. Copy the read-only preflight statements from the top of
   `20260903100000_staff_directory_assignment.sql`, run them separately, and
   save their reviewed aggregate/catalog results in the approved release
   record. Stop if expected relations, columns, function signatures, grants,
   RLS state, or legacy assignment counts differ from the reviewed baseline.
4. Confirm the two distinct real Auth users described above already exist.
   This source change does not create or seed Auth users or staff profiles.
5. In the controlled owner session, execute the reviewed migration exactly
   once. Its schema/function/grant changes are enclosed in one explicit
   transaction. Confirm the transaction committed successfully before
   proceeding.
6. Immediately provision the approved staff profiles as the PostgreSQL owner.
   Do not grant profile writes to `service_role` or client roles.
7. Verify without exposing personal data:
   - the minimum active assigner and assignee profiles exist;
   - canonical staff codes are uppercase and case-insensitively unique;
   - `staff_profiles` RLS is enabled and client table writes are denied;
   - directory RPCs expose only user ID, staff code, display name, role, and
     version;
   - the legacy text assignment RPC returns its fail-closed error;
   - the UUID assignment RPC, expected-version check, grants, and helper
     revocations match the reviewed contract.
8. Publish the reviewed new Flutter App and require affected staff to restart
   so no old assignment client remains active.
9. Run smoke tests with approved test records:
   - the assigner sees the permitted assignment action;
   - the selector lists only active maintenance staff;
   - assignment stores a server-generated label snapshot and immutable user
     identity;
   - an unauthorized or inactive caller is rejected;
   - stale expected versions are rejected;
   - legacy Assigned and In Progress records can continue their existing legal
     start, complete, or cancel lifecycle;
   - create, update, cancel, complete, Recommendation handoff, Route 300,
     schedule, and offline-read behavior remain intact.
10. Resume Work Order assignment only after the release owner records all smoke
    checks as passed. Otherwise keep assignment paused and follow rollback.

## Failure and rollback

If any migration statement fails before commit, roll back the transaction and
leave assignment paused. Investigate and produce a newly reviewed migration;
do not edit the ledger or retry this migration under an idempotency assumption.

If a problem is found after commit, keep assignment paused. Use a separately
reviewed rollback migration or restore the approved backup according to the
production recovery procedure. App rollback alone is not a compatible recovery
because the old App's free-text assignment RPC intentionally fails closed.
