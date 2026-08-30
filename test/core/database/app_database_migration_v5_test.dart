import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/app_database_schema.dart';
import 'package:prasa_assist/core/database/migrations/app_database_migration_v5.dart';

import '../../support/sqlite_test_database.dart';

void main() {
  test('fresh database reaches v5 with recommendation relationship', () async {
    final database = createInMemoryTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    expect(
      (await database.rawQuery('PRAGMA user_version')).single['user_version'],
      5,
    );
    expect(
      (await database.query(
        AppDatabaseSchema.migrationTable,
        orderBy: 'version ASC',
      )).map((row) => row['version']),
      [1, 2, 3, 4, 5],
    );
    await database.insert(
      AppDatabaseMigrationV5.recommendationRecordsTable,
      _recommendation('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'rec-1'),
    );
    await database.insert(
      AppDatabaseMigrationV5.recommendationAnalysesTable,
      _analysis('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'rec-1'),
    );
    await expectLater(
      database.insert(
        AppDatabaseMigrationV5.recommendationAnalysesTable,
        _analysis('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'rec-1'),
      ),
      throwsA(anything),
    );
  });

  test('actual v4 database upgrades to v5 and preserves v4 data', () async {
    final directory = await Directory.systemTemp.createTemp('prasa-v5-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}upgrade.db';
    final v4 = await createVersionFourFileDatabase(path);
    await v4.execute('CREATE TABLE preserved_v4 (value TEXT NOT NULL)');
    await v4.insert('preserved_v4', {'value': 'kept'});
    await v4.close();

    final upgraded = createFileTestDatabase(path);
    addTearDown(upgraded.close);
    await upgraded.ensureOpen();
    expect((await upgraded.query('preserved_v4')).single['value'], 'kept');
    expect(
      (await upgraded.rawQuery('PRAGMA user_version')).single['user_version'],
      5,
    );
  });
}

Map<String, Object?> _recommendation(String owner, String id) => {
  'recommendation_id': id,
  'owner_user_id': owner,
  'incident_id': 'incident-1',
  'vehicle_id': 'B1023',
  'route_id': '300',
  'actions_json': '[{"type":"inspect_or_repair_vehicle","vehicleId":"B1023"}]',
  'evidence_json': '[{"ruleId":"breakdown"}]',
  'score': 85,
  'confidence_details_json': '{"factors":[],"penalties":[]}',
  'status': 'pending_review',
  'remote_version': 1,
  'sync_state': 'cached_remote',
  'created_at_utc': '2026-08-29T01:00:00.000Z',
  'updated_at_utc': '2026-08-29T01:00:00.000Z',
  'retrieved_at_utc': '2026-08-29T01:01:00.000Z',
};

Map<String, Object?> _analysis(String owner, String id) => {
  'recommendation_id': id,
  'owner_user_id': owner,
  'model_identifier': 'gemini-2.5-flash',
  'schema_version': 1,
  'summary': 'Review the recommendation.',
  'rationale_json': '["Confirmed breakdown."]',
  'limitations_json': '["Staff verification required."]',
  'checklist_json': '["Review evidence."]',
  'generated_at_utc': '2026-08-29T01:00:30.000Z',
};
