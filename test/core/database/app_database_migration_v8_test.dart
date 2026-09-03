import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/app_database.dart';
import 'package:prasa_assist/core/database/app_database_schema.dart';
import 'package:prasa_assist/core/database/local_database_exception.dart';
import 'package:prasa_assist/core/database/migrations/app_database_migration_v4.dart';
import 'package:prasa_assist/core/database/migrations/app_database_migration_v8.dart';

import '../../support/sqlite_test_database.dart';

void main() {
  test(
    'fresh v8 database contains staff cache and assignment fields',
    () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      await database.ensureOpen();

      expect(
        (await database.rawQuery('PRAGMA user_version')).single['user_version'],
        8,
      );
      final staffColumns = await database.rawQuery(
        'PRAGMA table_info(${AppDatabaseMigrationV8.staffProfilesTable})',
      );
      expect(
        staffColumns.map((row) => row['name']),
        containsAll([
          'owner_user_id',
          'user_id',
          'staff_code',
          'display_name',
          'role',
          'active',
          'version',
          'retrieved_at_utc',
        ]),
      );
      final workOrderColumns = await database.rawQuery(
        'PRAGMA table_info(${AppDatabaseMigrationV4.workOrderRecordsTable})',
      );
      expect(
        workOrderColumns.map((row) => row['name']),
        containsAll(['assigned_to_user_id', 'assigned_to_label_snapshot']),
      );
      final triggers = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'trigger'",
      );
      expect(
        triggers.map((row) => row['name']),
        containsAll([
          'enforce_local_work_order_assignment_pair_insert',
          'enforce_local_work_order_assignment_pair_update',
        ]),
      );

      await database.insert(
        AppDatabaseMigrationV4.workOrderRecordsTable,
        _freshWorkOrderRow('fresh-null-pair'),
      );
      await database.insert(
        AppDatabaseMigrationV4.workOrderRecordsTable,
        _freshWorkOrderRow('fresh-valid-pair', assigned: true),
      );
      await expectLater(
        database.insert(
          AppDatabaseMigrationV4.workOrderRecordsTable,
          _freshWorkOrderRow('fresh-user-only')
            ..['assigned_to_user_id'] = _assignee,
        ),
        throwsA(isA<LocalDatabaseOperationException>()),
      );
      await expectLater(
        database.insert(
          AppDatabaseMigrationV4.workOrderRecordsTable,
          _freshWorkOrderRow('fresh-label-only')
            ..['assigned_to_label_snapshot'] = 'Maintenance One (M-002)',
        ),
        throwsA(isA<LocalDatabaseOperationException>()),
      );
    },
  );

  test('actual v7 to v8 upgrade preserves route and schedule data', () async {
    final directory = await Directory.systemTemp.createTemp('prasa-v8-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}upgrade.db';
    final v7 = await createVersionSevenFileDatabase(path);
    await v7.insert(
      AppDatabaseMigrationV4.workOrderRecordsTable,
      _v7WorkOrderRow,
    );
    await v7.close();

    final upgraded = createFileTestDatabase(path);
    addTearDown(upgraded.close);
    await upgraded.ensureOpen();

    final row = (await upgraded.query(
      AppDatabaseMigrationV4.workOrderRecordsTable,
      where: 'local_id = ?',
      whereArgs: ['v7-route-work-order'],
    )).single;
    expect(row['route_id'], '300');
    expect(row['scheduled_start_utc'], '2026-09-03T01:00:00.000Z');
    expect(row['scheduled_end_utc'], '2026-09-03T02:00:00.000Z');
    expect(row['assigned_to_user_id'], isNull);
    expect(row['assigned_to_label_snapshot'], isNull);
    expect(row['remote_storage_id'], _remoteStorageId);
    expect(row['work_order_id'], 'WO-ROUTE-300');
    expect(row['remote_version'], 7);
    expect(row['sync_state'], 'cached_remote');
    expect(row['retrieved_at_utc'], '2026-09-03T02:30:00.000Z');

    await upgraded.update(
      AppDatabaseMigrationV4.workOrderRecordsTable,
      {
        'assigned_to': 'Maintenance One (M-002)',
        'assigned_to_user_id': _assignee,
        'assigned_to_label_snapshot': 'Maintenance One (M-002)',
      },
      where: 'local_id = ?',
      whereArgs: ['v7-route-work-order'],
    );
    await upgraded.update(
      AppDatabaseMigrationV4.workOrderRecordsTable,
      {
        'assigned_to': null,
        'assigned_to_user_id': null,
        'assigned_to_label_snapshot': null,
      },
      where: 'local_id = ?',
      whereArgs: ['v7-route-work-order'],
    );
    await expectLater(
      upgraded.update(
        AppDatabaseMigrationV4.workOrderRecordsTable,
        {'assigned_to_user_id': _assignee},
        where: 'local_id = ?',
        whereArgs: ['v7-route-work-order'],
      ),
      throwsA(isA<LocalDatabaseOperationException>()),
    );
    await expectLater(
      upgraded.update(
        AppDatabaseMigrationV4.workOrderRecordsTable,
        {'assigned_to_label_snapshot': 'Maintenance One (M-002)'},
        where: 'local_id = ?',
        whereArgs: ['v7-route-work-order'],
      ),
      throwsA(isA<LocalDatabaseOperationException>()),
    );
    expect(
      (await upgraded.query(
        AppDatabaseSchema.migrationTable,
        orderBy: 'version ASC',
      )).map((item) => item['version']),
      [1, 2, 3, 4, 5, 6, 7, 8],
    );
  });

  test('fresh creation and real v7 upgrade produce the same schema', () async {
    final fresh = createInMemoryTestDatabase();
    addTearDown(fresh.close);
    await fresh.ensureOpen();

    final directory = await Directory.systemTemp.createTemp('prasa-v8-schema-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}upgrade.db';
    final v7 = await createVersionSevenFileDatabase(path);
    await v7.close();
    final upgraded = createFileTestDatabase(path);
    addTearDown(upgraded.close);
    await upgraded.ensureOpen();

    expect(await _schemaObjects(upgraded), await _schemaObjects(fresh));
  });
}

Future<List<Map<String, Object?>>> _schemaObjects(AppDatabase database) =>
    database.rawQuery('''
      SELECT type, name, tbl_name, sql
      FROM sqlite_master
      WHERE name NOT LIKE 'sqlite_%'
      ORDER BY type, name
    ''');

const _owner = '11111111-1111-4111-8111-111111111111';
const _remoteStorageId = '99999999-9999-4999-8999-999999999999';
const _assignee = '22222222-2222-4222-8222-222222222222';

const Map<String, Object?> _v7WorkOrderRow = {
  'local_id': 'v7-route-work-order',
  'owner_user_id': _owner,
  'remote_storage_id': _remoteStorageId,
  'work_order_id': 'WO-ROUTE-300',
  'incident_id': 'INC-B1023',
  'recommendation_id': 'REC-B1023',
  'route_id': '300',
  'vehicle_id': 'B1023',
  'task_type': 'Inspection',
  'description': 'Preserve Route 300 schedule through v8.',
  'priority': 'urgent',
  'assigned_to': null,
  'scheduled_start_utc': '2026-09-03T01:00:00.000Z',
  'scheduled_end_utc': '2026-09-03T02:00:00.000Z',
  'status': 'draft',
  'notes': null,
  'created_by_user_id': _owner,
  'created_by_label': 'Staff profile unavailable',
  'remote_created_at_utc': '2026-09-03T00:30:00.000Z',
  'remote_updated_at_utc': '2026-09-03T02:00:00.000Z',
  'completed_at_utc': null,
  'cancelled_at_utc': null,
  'remote_version': 7,
  'sync_state': 'cached_remote',
  'retrieved_at_utc': '2026-09-03T02:30:00.000Z',
  'local_created_at_utc': '2026-09-03T00:00:00.000Z',
  'local_modified_at_utc': '2026-09-03T00:00:00.000Z',
  'safe_error_message': null,
};

Map<String, Object?> _freshWorkOrderRow(
  String localId, {
  bool assigned = false,
}) {
  return <String, Object?>{
    ..._v7WorkOrderRow,
    'local_id': localId,
    'remote_storage_id': null,
    'work_order_id': null,
    'status': 'draft',
    'assigned_to': null,
    'assigned_to_user_id': assigned ? _assignee : null,
    'assigned_to_label_snapshot': assigned ? 'Maintenance One (M-002)' : null,
    'remote_created_at_utc': null,
    'remote_updated_at_utc': null,
    'remote_version': null,
    'sync_state': 'local_draft',
    'retrieved_at_utc': null,
  };
}
