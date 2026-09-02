import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/app_database_schema.dart';
import 'package:prasa_assist/core/database/local_user_scope.dart';
import 'package:prasa_assist/core/database/migrations/app_database_migration_v4.dart';
import 'package:prasa_assist/features/work_orders/data/sources/sqlite_work_order_local_data_source.dart';

import '../../support/sqlite_test_database.dart';

void main() {
  test(
    'v6 upgrade preserves and safely remediates legacy equality rows',
    () async {
      final directory = await Directory.systemTemp.createTemp('prasa-v7-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}upgrade.db';
      final v6 = await createVersionSixFileDatabase(path);
      await v6.insert(
        AppDatabaseMigrationV4.workOrderRecordsTable,
        _legacyEqualityRow(),
      );
      await v6.insert(
        AppDatabaseMigrationV4.workOrderRecordsTable,
        _legacyEqualityRow(localId: 'legacy-remove'),
      );
      await v6.insert(
        AppDatabaseMigrationV4.workOrderRecordsTable,
        _legacyConfirmedEqualityRow(),
      );
      await v6.close();

      final upgraded = createFileTestDatabase(path);
      addTearDown(upgraded.close);
      await upgraded.ensureOpen();

      expect(
        (await upgraded.rawQuery('PRAGMA user_version')).single['user_version'],
        7,
      );
      expect(
        (await upgraded.query(
          AppDatabaseSchema.migrationTable,
          orderBy: 'version ASC',
        )).map((row) => row['version']),
        [1, 2, 3, 4, 5, 6, 7],
      );
      final source = SqliteWorkOrderLocalDataSource(
        database: upgraded,
        userScope: LocalUserScope(_owner),
        localIdGenerator: () => 'unused',
      );
      final legacy = (await source.readLocalWorkItems()).firstWhere(
        (record) => record.localId == 'legacy-equality',
      );
      expect(legacy.draft.routeId, isNull);
      expect(legacy.draft.hasLegacyScheduleEquality, isTrue);

      await expectLater(
        upgraded.update(
          AppDatabaseMigrationV4.workOrderRecordsTable,
          {'notes': 'Cannot advance legacy equality row'},
          where: 'local_id = ?',
          whereArgs: ['legacy-equality'],
        ),
        throwsA(anything),
      );
      expect(
        await upgraded.update(
          AppDatabaseMigrationV4.workOrderRecordsTable,
          {'scheduled_end_utc': '2026-09-02T01:01:00.000Z'},
          where: 'local_id = ?',
          whereArgs: ['legacy-equality'],
        ),
        1,
      );
      await source.discardLocalDraft('legacy-remove');
      expect(await source.readLocalWorkItem('legacy-remove'), isNull);

      await expectLater(
        upgraded.update(
          AppDatabaseMigrationV4.workOrderRecordsTable,
          {'status': 'open'},
          where: 'local_id = ?',
          whereArgs: ['legacy-confirmed'],
        ),
        throwsA(anything),
      );
      expect(
        await upgraded.update(
          AppDatabaseMigrationV4.workOrderRecordsTable,
          {
            'status': 'cancelled',
            'cancelled_at_utc': '2026-09-02T02:00:00.000Z',
            'remote_updated_at_utc': '2026-09-02T02:00:00.000Z',
            'local_modified_at_utc': '2026-09-02T02:00:00.000Z',
            'remote_version': 2,
          },
          where: 'local_id = ?',
          whereArgs: ['legacy-confirmed'],
        ),
        1,
      );
      expect(
        await upgraded.update(
          AppDatabaseMigrationV4.workOrderRecordsTable,
          {
            'retrieved_at_utc': '2026-09-02T02:01:00.000Z',
            'local_modified_at_utc': '2026-09-02T02:01:00.000Z',
          },
          where: 'local_id = ?',
          whereArgs: ['legacy-confirmed'],
        ),
        1,
      );
      await expectLater(
        upgraded.insert(AppDatabaseMigrationV4.workOrderRecordsTable, {
          ..._legacyEqualityRow(),
          'local_id': 'new-equality',
          'route_id': '300',
        }),
        throwsA(anything),
      );
      await expectLater(
        upgraded.insert(AppDatabaseMigrationV4.workOrderRecordsTable, {
          ..._legacyEqualityRow(),
          'local_id': 'new-reversed',
          'route_id': '300',
          'scheduled_end_utc': '2026-09-02T00:59:00.000Z',
        }),
        throwsA(anything),
      );
      await upgraded.insert(AppDatabaseMigrationV4.workOrderRecordsTable, {
        ..._legacyEqualityRow(),
        'local_id': 'strict-after',
        'route_id': '300',
        'scheduled_end_utc': '2026-09-02T01:01:00.000Z',
      });
      await expectLater(
        upgraded.update(
          AppDatabaseMigrationV4.workOrderRecordsTable,
          {'scheduled_end_utc': '2026-09-02T01:00:00.000Z'},
          where: 'local_id = ?',
          whereArgs: ['strict-after'],
        ),
        throwsA(anything),
      );
    },
  );

  test('fresh database has route column and strict schedule triggers', () async {
    final database = createInMemoryTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    final columns = await database.rawQuery(
      'PRAGMA table_info(${AppDatabaseMigrationV4.workOrderRecordsTable})',
    );
    expect(columns.map((row) => row['name']), contains('route_id'));
    final triggers = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'trigger' AND tbl_name = ?",
      [AppDatabaseMigrationV4.workOrderRecordsTable],
    );
    expect(
      triggers.map((row) => row['name']),
      containsAll({
        'strict_local_work_order_schedule_insert',
        'strict_local_work_order_schedule_update',
      }),
    );
  });
}

const _owner = '11111111-1111-4111-8111-111111111111';

Map<String, Object?> _legacyEqualityRow({String localId = 'legacy-equality'}) =>
    {
      'local_id': localId,
      'owner_user_id': _owner,
      'remote_storage_id': null,
      'work_order_id': null,
      'incident_id': 'INC-1',
      'recommendation_id': 'REC-1',
      'vehicle_id': 'B1023',
      'task_type': 'Inspection',
      'description': 'Legacy equality schedule',
      'priority': 'urgent',
      'assigned_to': null,
      'scheduled_start_utc': '2026-09-02T01:00:00.000Z',
      'scheduled_end_utc': '2026-09-02T01:00:00.000Z',
      'status': 'draft',
      'notes': null,
      'created_by_user_id': _owner,
      'created_by_label': 'Staff A',
      'remote_created_at_utc': null,
      'remote_updated_at_utc': null,
      'completed_at_utc': null,
      'cancelled_at_utc': null,
      'remote_version': null,
      'sync_state': 'local_draft',
      'retrieved_at_utc': null,
      'local_created_at_utc': '2026-09-02T00:00:00.000Z',
      'local_modified_at_utc': '2026-09-02T00:00:00.000Z',
      'safe_error_message': null,
    };

Map<String, Object?> _legacyConfirmedEqualityRow() => {
  ..._legacyEqualityRow(localId: 'legacy-confirmed'),
  'remote_storage_id': '22222222-2222-4222-8222-222222222222',
  'work_order_id': 'WO-20260902-000001',
  'remote_created_at_utc': '2026-09-02T00:00:00.000Z',
  'remote_updated_at_utc': '2026-09-02T00:00:00.000Z',
  'remote_version': 1,
  'sync_state': 'cached_remote',
  'retrieved_at_utc': '2026-09-02T00:00:00.000Z',
};
