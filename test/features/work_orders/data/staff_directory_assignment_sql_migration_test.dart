import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File(
      'supabase/migrations/20260903100000_staff_directory_assignment.sql',
    ).readAsStringSync();
  });

  test('starts with aggregate and catalog-only preflight checks', () {
    final ddl = migration.indexOf('create table public.staff_profiles');
    final preflight = migration.substring(0, ddl);
    expect(preflight, contains('route_id_exists'));
    expect(preflight, contains('auth_user_count'));
    expect(preflight, contains('distinct_assigned_to_count'));
    expect(preflight, contains('blocking_legacy_assignment_count'));
    expect(preflight, contains('role_table_grants'));
    expect(preflight, isNot(contains('select * from auth.users')));
  });

  test('keeps preflight outside one explicit migration transaction', () {
    final begin = migration.indexOf('\nbegin;\n');
    final ddl = migration.indexOf('create table public.staff_profiles');
    final commit = migration.lastIndexOf('\ncommit;');

    expect(begin, greaterThan(migration.indexOf('role_table_grants')));
    expect(begin, lessThan(ddl));
    expect(commit, greaterThan(ddl));
    expect(migration.trim(), endsWith('commit;'));
    expect(
      RegExp(r'^begin;$', multiLine: true).allMatches(migration),
      hasLength(1),
    );
    expect(
      RegExp(r'^commit;$', multiLine: true).allMatches(migration),
      hasLength(1),
    );
  });

  test(
    'defines constrained profiles without auth bootstrap or email fields',
    () {
      final table = migration.substring(
        migration.indexOf('create table public.staff_profiles'),
        migration.indexOf('create index staff_profiles_active_role_name_idx'),
      );
      expect(table, contains('references auth.users(id) on delete restrict'));
      expect(table, contains('staff_code text unique not null'));
      expect(
        table,
        contains('staff_code = pg_catalog.upper(pg_catalog.btrim(staff_code))'),
      );
      expect(table, contains('display_name text not null'));
      expect(table, contains("'operations_staff', 'maintenance_staff'"));
      expect(table, contains("'supervisor', 'control_centre'"));
      expect(table, contains('version bigint not null default 1'));
      expect(table, isNot(contains('email')));
      expect(migration, isNot(contains('insert into auth.users')));
      expect(migration, isNot(contains('insert into public.staff_profiles')));
    },
  );

  test('enables RLS and exposes only narrow authenticated directory RPCs', () {
    expect(
      migration,
      contains('alter table public.staff_profiles enable row level security'),
    );
    expect(
      migration,
      contains(
        'revoke all on table public.staff_profiles from public, anon, authenticated',
      ),
    );
    expect(
      migration,
      contains('create function public.list_staff_directory()'),
    );
    expect(
      migration,
      contains('create function public.list_assignable_staff()'),
    );
    expect(migration, contains('security definer\nset search_path = \'\''));
    expect(
      migration,
      contains('An active authenticated staff profile is required.'),
    );
    final directory = migration.substring(
      migration.indexOf('create function public.list_staff_directory()'),
      migration.indexOf('create function public.list_assignable_staff()'),
    );
    expect(directory, contains('user_id uuid'));
    expect(directory, contains('staff_code text'));
    expect(directory, contains('display_name text'));
    expect(directory, contains('role text'));
    expect(directory, contains('version bigint'));
    expect(directory, isNot(contains('email')));
    expect(directory, isNot(contains('auth.users')));
  });

  test('adds stable assignment fields and a UUID-only assignment RPC', () {
    expect(migration, contains('add column assigned_to_user_id uuid null'));
    expect(
      migration,
      contains('add column assigned_to_label_snapshot text null'),
    );
    expect(
      migration,
      contains(
        'references public.staff_profiles(user_id)\n    on delete restrict',
      ),
    );
    expect(
      migration,
      contains(
        'create function public.assign_work_order_to_staff(\n  p_work_order_id text,\n  p_assigned_to_user_id uuid,\n  p_expected_version bigint',
      ),
    );
    expect(
      migration,
      contains("caller.role in ('supervisor', 'control_centre')"),
    );
    expect(migration, contains("profile.role = 'maintenance_staff'"));
    expect(migration, contains('and profile.active'));
    expect(migration, contains('result_record.version <> p_expected_version'));
    expect(migration, contains("result_record.status <> 'open'"));
    expect(
      migration,
      contains("display_name || ' (' || profile.staff_code || ')'"),
    );
  });

  test('fails the legacy text RPC closed and preserves linkage guards', () {
    final legacy = migration.substring(
      migration.indexOf('create or replace function public.assign_work_order('),
      migration.indexOf('create function public.assign_work_order_to_staff('),
    );
    expect(legacy, contains('Free-text assignment is disabled'));
    expect(legacy, isNot(contains('update public.work_orders')));
    expect(migration, contains('new.route_id is distinct from old.route_id'));
    expect(
      migration,
      contains('new.recommendation_id is distinct from old.recommendation_id'),
    );
    expect(
      migration,
      contains('new.incident_id is distinct from old.incident_id'),
    );
  });

  test('does not grant client execution on helpers or trigger functions', () {
    expect(
      migration,
      contains(
        'revoke all on function public.enforce_staff_profile_write()\n  from public, anon, authenticated',
      ),
    );
    expect(
      migration,
      contains(
        'revoke all on function public.enforce_work_order_update()\n  from public, anon, authenticated',
      ),
    );
    expect(
      migration,
      isNot(contains('grant execute on function public.enforce_')),
    );
  });

  test(
    'keeps provisioning owner-only and revokes service role table access',
    () {
      expect(
        migration,
        contains('revoke all on table public.staff_profiles from service_role'),
      );
      expect(
        migration,
        isNot(
          contains('grant insert on public.staff_profiles to service_role'),
        ),
      );
      expect(
        migration,
        isNot(
          contains('grant update on public.staff_profiles to service_role'),
        ),
      );
    },
  );

  test('defines exactly one legacy and one verified assignment signature', () {
    expect(
      RegExp(
        r'^create or replace function public\.assign_work_order\($',
        multiLine: true,
      ).allMatches(migration),
      hasLength(1),
    );
    expect(
      RegExp(
        r'^create function public\.assign_work_order_to_staff\($',
        multiLine: true,
      ).allMatches(migration),
      hasLength(1),
    );
    expect(
      migration,
      contains(
        'grant execute on function public.assign_work_order(text, text, bigint)',
      ),
    );
    expect(
      migration,
      contains(
        'grant execute on function public.assign_work_order_to_staff(text, uuid, bigint)',
      ),
    );
  });
}
