import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File(
      'supabase/migrations/'
      '20260902120000_work_order_handoff_integrity.sql',
    ).readAsStringSync();
  });

  test('adds nullable Route linkage with provable backfill only', () {
    expect(migration, contains('add column route_id text'));
    expect(migration, contains('on w.recommendation_id = r.id::text'));
    expect(migration, contains('having count(r.id) = 1'));
    expect(migration, isNot(contains('coalesce(r.route_id')));
  });

  test('preserves historical publication evidence exactly', () {
    final beforeFunctions = migration.substring(
      0,
      migration.indexOf('create or replace function public.work_order_result'),
    );
    expect(
      beforeFunctions,
      isNot(contains('set publication_request_snapshot')),
    );
    expect(beforeFunctions, isNot(contains('publication_request_sha256 =')));
  });

  test('supports fail-closed legacy and versioned publication retries', () {
    expect(migration, contains("'route_id', p.route_id"));
    expect(migration, contains("canonical_snapshot ->> 'route_id'"));
    expect(
      migration,
      contains("existing.publication_request_snapshot ? 'route_id'"),
    );
    expect(migration, contains("canonical_snapshot - 'route_id'"));
    expect(migration, contains('existing.route_id = incoming_route_id'));
    expect(migration, contains('incoming_route_id is null'));
  });

  test('makes linkage immutable and update payload linkage-free', () {
    expect(migration, contains('new.route_id is distinct from old.route_id'));
    final updateFunction = migration.substring(
      migration.indexOf('create or replace function public.update_work_order'),
    );
    final updateWhitelist = updateFunction.substring(
      updateFunction.indexOf('where payload_key not in'),
      updateFunction.indexOf(') then'),
    );
    expect(updateWhitelist, isNot(contains("'incident_id'")));
    expect(updateWhitelist, isNot(contains("'recommendation_id'")));
    expect(updateWhitelist, isNot(contains("'route_id'")));
  });

  test('uses strict RPC ordering and lifecycle-aware database trigger', () {
    expect(
      RegExp('schedule_end <= schedule_start').allMatches(migration),
      hasLength(2),
    );
    expect(migration, contains('enforce_work_order_schedule_integrity'));
    expect(migration, contains("new.status = 'cancelled'"));
    expect(migration, contains('schedule_unchanged'));
    expect(
      migration,
      isNot(contains('work_orders_schedule_strict_order_check')),
    );
    expect(migration, contains('legacy_equal_schedule_rows'));
  });
}
