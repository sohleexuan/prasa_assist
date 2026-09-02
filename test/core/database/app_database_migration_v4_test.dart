import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/app_database_schema.dart';
import 'package:prasa_assist/core/database/migrations/app_database_migration_v2.dart';
import 'package:prasa_assist/core/database/migrations/app_database_migration_v3.dart';
import 'package:prasa_assist/core/database/migrations/app_database_migration_v4.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/sqlite_test_database.dart';

void main() {
  group('AppDatabase migration version 4', () {
    test('fresh install applies v1 through v4 with exact indexes', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      await database.ensureOpen();

      expect(
        (await database.rawQuery('PRAGMA user_version')).single['user_version'],
        7,
      );
      expect(
        (await database.query(
          AppDatabaseSchema.migrationTable,
          orderBy: 'version ASC',
        )).map((row) => row['version']),
        [1, 2, 3, 4, 5, 6, 7],
      );
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN (?, ?, ?)",
        [
          AppDatabaseMigrationV2.deploymentRecordsTable,
          AppDatabaseMigrationV3.incidentRecordsTable,
          AppDatabaseMigrationV4.workOrderRecordsTable,
        ],
      );
      expect(tables, hasLength(3));
      final indexes = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = ?",
        [AppDatabaseMigrationV4.workOrderRecordsTable],
      );
      expect(
        indexes.map((row) => row['name']).toSet(),
        containsAll({
          'ux_local_work_orders_owner_remote_id',
          'ux_local_work_orders_owner_code',
          'ix_local_work_orders_owner_sync_modified',
          'ix_local_work_orders_owner_sync_schedule',
          'ix_local_work_orders_owner_status_priority',
        }),
      );
      expect(
        (await database.rawQuery('PRAGMA foreign_keys')).single['foreign_keys'],
        1,
      );
    });

    test('version-3 database upgrades only v4 and preserves data', () async {
      final directory = await Directory.systemTemp.createTemp('prasa-v4-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}upgrade.db';
      final v3 = await createVersionThreeFileDatabase(path);
      await v3.execute(
        'CREATE TABLE preserved_before_v4 (value TEXT NOT NULL)',
      );
      await v3.insert('preserved_before_v4', {'value': 'kept'});
      await v3.close();

      final upgraded = createFileTestDatabase(path);
      await upgraded.ensureOpen();
      expect(
        (await upgraded.query('preserved_before_v4')).single['value'],
        'kept',
      );
      expect(
        (await upgraded.query(
          AppDatabaseSchema.migrationTable,
          orderBy: 'version ASC',
        )).map((row) => row['version']),
        [1, 2, 3, 4, 5, 6, 7],
      );
      await upgraded.close();

      final reopened = createFileTestDatabase(path);
      addTearDown(reopened.close);
      expect(
        (await reopened.query(
          AppDatabaseSchema.migrationTable,
          where: 'version = ?',
          whereArgs: [4],
        )).length,
        1,
      );
    });

    test('malformed and incorrectly ordered UTC values are rejected', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      await database.ensureOpen();
      final base = _draftRow();

      for (final change in [
        {'local_id': 'bad-date', 'local_created_at_utc': 'not-a-dateZ'},
        {
          'local_id': 'bad-schedule',
          'scheduled_start_utc': '2026-08-29T03:00:00.000Z',
          'scheduled_end_utc': '2026-08-29T02:00:00.000Z',
        },
        {
          'local_id': 'bad-modified',
          'local_modified_at_utc': '2026-08-28T23:00:00.000Z',
        },
      ]) {
        await expectLater(
          database.insert(AppDatabaseMigrationV4.workOrderRecordsTable, {
            ...base,
            ...change,
          }),
          throwsA(anything),
        );
      }
    });

    test('rejects malformed UUID-like values for every UUID column', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      await database.ensureOpen();
      const malformed = 'gggggggg-gggg-gggg-gggg-gggggggggggg';

      for (final change in [
        {'local_id': 'bad-owner', 'owner_user_id': malformed},
        {'local_id': 'bad-creator', 'created_by_user_id': malformed},
      ]) {
        await expectLater(
          database.insert(AppDatabaseMigrationV4.workOrderRecordsTable, {
            ..._draftRow(),
            ...change,
          }),
          throwsA(anything),
        );
      }
      await expectLater(
        database.insert(AppDatabaseMigrationV4.workOrderRecordsTable, {
          ..._confirmedRow(localId: 'bad-remote'),
          'remote_storage_id': malformed,
        }),
        throwsA(anything),
      );
    });

    test(
      'enforces confirmed lifecycle ordering and identity metadata',
      () async {
        final database = createInMemoryTestDatabase();
        addTearDown(database.close);
        await database.ensureOpen();

        for (final change in [
          {
            'local_id': 'updated-before-created',
            'remote_updated_at_utc': '2026-08-29T00:59:00.000Z',
          },
          {
            'local_id': 'completed-before-created',
            'status': 'completed',
            'assigned_to': 'Staff B',
            'completed_at_utc': '2026-08-29T00:59:00.000Z',
          },
          {
            'local_id': 'cancelled-after-updated',
            'status': 'cancelled',
            'cancelled_at_utc': '2026-08-29T03:01:00.000Z',
          },
          {'local_id': 'missing-storage', 'remote_storage_id': null},
          {'local_id': 'missing-code', 'work_order_id': null},
          {'local_id': 'missing-version', 'remote_version': null},
          {'local_id': 'bad-version', 'remote_version': 0},
        ]) {
          await expectLater(
            database.insert(AppDatabaseMigrationV4.workOrderRecordsTable, {
              ..._confirmedRow(localId: 'base'),
              ...change,
            }),
            throwsA(anything),
          );
        }
      },
    );

    test('partial unique identities are owner scoped', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      await database.ensureOpen();
      final table = AppDatabaseMigrationV4.workOrderRecordsTable;
      await database.insert(table, _confirmedRow(localId: 'owner-a'));

      await expectLater(
        database.insert(table, {
          ..._confirmedRow(localId: 'same-owner-storage'),
          'work_order_id': 'WO-OTHER',
        }),
        throwsA(anything),
      );
      await expectLater(
        database.insert(table, {
          ..._confirmedRow(localId: 'same-owner-code'),
          'remote_storage_id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        }),
        throwsA(anything),
      );
      await database.insert(
        table,
        _confirmedRow(
          localId: 'owner-b',
          ownerUserId: '22222222-2222-4222-8222-222222222222',
        ),
      );
      expect(await database.query(table), hasLength(2));
    });

    test(
      'failed real v3 to v4 upgrade rolls back and reopens safely',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'prasa-v4-rollback-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final path = '${directory.path}${Platform.pathSeparator}rollback.db';
        final database = await createVersionThreeFileDatabase(path);
        await database.insert(
          AppDatabaseMigrationV2.deploymentRecordsTable,
          _deploymentDraftRow(),
        );
        await database.insert(
          AppDatabaseMigrationV3.incidentRecordsTable,
          _incidentDraftRow(),
        );
        await database.close();

        sqfliteFfiInit();
        await expectLater(
          databaseFactoryFfi.openDatabase(
            path,
            options: OpenDatabaseOptions(
              version: 4,
              singleInstance: false,
              onConfigure: AppDatabaseSchema.onConfigure,
              onUpgrade: (upgradeDatabase, oldVersion, newVersion) async {
                expect(oldVersion, 3);
                expect(newVersion, 4);
                await AppDatabaseMigrationV4.apply(upgradeDatabase);
                await upgradeDatabase.insert(AppDatabaseSchema.migrationTable, {
                  'version': 4,
                  'applied_at_utc': DateTime.utc(2026, 8, 29).toIso8601String(),
                });
                throw StateError('Simulated v4 failure after metadata.');
              },
            ),
          ),
          throwsA(anything),
        );

        final unchanged = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(version: 3, singleInstance: false),
        );
        expect(
          await unchanged.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
            [AppDatabaseMigrationV4.workOrderRecordsTable],
          ),
          isEmpty,
        );
        expect(
          await unchanged.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name LIKE '%local_work_orders%'",
          ),
          isEmpty,
        );
        expect(
          await unchanged.query(
            AppDatabaseSchema.migrationTable,
            where: 'version = ?',
            whereArgs: [4],
          ),
          isEmpty,
        );
        expect(
          (await unchanged.rawQuery('PRAGMA user_version'))
              .single['user_version'],
          3,
        );
        expect(
          await unchanged.query(AppDatabaseMigrationV2.deploymentRecordsTable),
          hasLength(1),
        );
        expect(
          await unchanged.query(AppDatabaseMigrationV3.incidentRecordsTable),
          hasLength(1),
        );
        await unchanged.close();

        final reopened = createFileTestDatabase(path);
        addTearDown(reopened.close);
        expect(
          (await reopened.query(
            AppDatabaseSchema.migrationTable,
            orderBy: 'version ASC',
          )).map((row) => row['version']),
          [1, 2, 3, 4, 5, 6, 7],
        );
        expect(
          await reopened.query(AppDatabaseMigrationV2.deploymentRecordsTable),
          hasLength(1),
        );
        expect(
          await reopened.query(AppDatabaseMigrationV3.incidentRecordsTable),
          hasLength(1),
        );
      },
    );
  });
}

Map<String, Object?> _draftRow() => {
  'local_id': 'draft-1',
  'owner_user_id': '11111111-1111-4111-8111-111111111111',
  'remote_storage_id': null,
  'work_order_id': null,
  'incident_id': 'INC-1',
  'recommendation_id': 'REC-1',
  'vehicle_id': 'B1023',
  'task_type': 'Inspection',
  'description': 'Inspect Route 300 breakdown.',
  'priority': 'urgent',
  'assigned_to': null,
  'scheduled_start_utc': '2026-08-29T01:00:00.000Z',
  'scheduled_end_utc': '2026-08-29T02:00:00.000Z',
  'status': 'draft',
  'notes': null,
  'created_by_user_id': '11111111-1111-4111-8111-111111111111',
  'created_by_label': 'Staff A',
  'remote_created_at_utc': null,
  'remote_updated_at_utc': null,
  'completed_at_utc': null,
  'cancelled_at_utc': null,
  'remote_version': null,
  'sync_state': 'local_draft',
  'retrieved_at_utc': null,
  'local_created_at_utc': '2026-08-29T00:00:00.000Z',
  'local_modified_at_utc': '2026-08-29T00:00:00.000Z',
  'safe_error_message': null,
};

Map<String, Object?> _confirmedRow({
  required String localId,
  String ownerUserId = '11111111-1111-4111-8111-111111111111',
}) => {
  ..._draftRow(),
  'local_id': localId,
  'owner_user_id': ownerUserId,
  'remote_storage_id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'work_order_id': 'WO-1',
  'status': 'open',
  'remote_created_at_utc': '2026-08-29T01:00:00.000Z',
  'remote_updated_at_utc': '2026-08-29T03:00:00.000Z',
  'remote_version': 1,
  'sync_state': 'cached_remote',
  'retrieved_at_utc': '2026-08-29T04:00:00.000Z',
};

Map<String, Object?> _deploymentDraftRow() => {
  'local_id': 'deployment-before-v4',
  'owner_user_id': '11111111-1111-4111-8111-111111111111',
  'route_id': '300',
  'route_name': 'Route 300',
  'start_time_utc': '2026-08-29T01:00:00.000Z',
  'end_time_utc': '2026-08-29T02:00:00.000Z',
  'status': 'draft',
  'purpose': 'Preserve v2 data',
  'sync_state': 'local_draft',
  'local_created_at_utc': '2026-08-29T00:00:00.000Z',
  'local_modified_at_utc': '2026-08-29T00:00:00.000Z',
};

Map<String, Object?> _incidentDraftRow() => {
  'local_id': 'incident-before-v4',
  'owner_user_id': '11111111-1111-4111-8111-111111111111',
  'incident_type': 'vehicle_breakdown',
  'title': 'Bus breakdown',
  'description': 'Bus B1023 broke down on Route 300.',
  'route_id': '300',
  'location': 'Route 300',
  'reported_at_utc': '2026-08-29T00:00:00.000Z',
  'severity': 'high',
  'status': 'reported',
  'vehicle_condition': 'immobilised',
  'disruption_scope': 'partial_obstruction',
  'estimated_delay_minutes': 20,
  'impact_level': 'major',
  'estimation_reasons_json': '["Breakdown"]',
  'estimation_model_version': 1,
  'data_source': 'staff_entered',
  'reported_by_label': 'Staff A',
  'sync_state': 'local_draft',
  'local_created_at_utc': '2026-08-29T00:00:00.000Z',
  'local_modified_at_utc': '2026-08-29T00:00:00.000Z',
};
