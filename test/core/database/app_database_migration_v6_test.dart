import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/app_database_schema.dart';
import 'package:prasa_assist/core/database/migrations/app_database_migration_v5.dart';

import '../../support/sqlite_test_database.dart';

void main() {
  test('v5 upgrade preserves Gemini analyses and accepts only Gemini or Groq',
      () async {
    final directory = await Directory.systemTemp.createTemp('prasa-v6-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}upgrade.db';
    final v5 = await createVersionFiveFileDatabase(path);
    await v5.insert(
      AppDatabaseMigrationV5.recommendationRecordsTable,
      _recommendation('rec-gemini'),
    );
    await v5.insert(
      AppDatabaseMigrationV5.recommendationAnalysesTable,
      _analysis('rec-gemini', 'gemini-2.5-flash'),
    );
    await v5.close();

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
      ))
          .map((row) => row['version']),
      [1, 2, 3, 4, 5, 6, 7],
    );
    expect(
      (await upgraded.query(
        AppDatabaseMigrationV5.recommendationAnalysesTable,
        where: 'recommendation_id = ?',
        whereArgs: ['rec-gemini'],
      ))
          .single['model_identifier'],
      'gemini-2.5-flash',
    );

    await upgraded.insert(
      AppDatabaseMigrationV5.recommendationRecordsTable,
      _recommendation('rec-groq'),
    );
    await upgraded.insert(
      AppDatabaseMigrationV5.recommendationAnalysesTable,
      _analysis('rec-groq', 'openai/gpt-oss-20b'),
    );
    await upgraded.insert(
      AppDatabaseMigrationV5.recommendationRecordsTable,
      _recommendation('rec-unknown'),
    );
    await expectLater(
      upgraded.insert(
        AppDatabaseMigrationV5.recommendationAnalysesTable,
        _analysis('rec-unknown', 'unknown/model'),
      ),
      throwsA(anything),
    );
    expect(await upgraded.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
}

Map<String, Object?> _recommendation(String id) => {
      'recommendation_id': id,
      'owner_user_id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'incident_id': 'INC-1',
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

Map<String, Object?> _analysis(String recommendationId, String model) => {
      'recommendation_id': recommendationId,
      'owner_user_id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'model_identifier': model,
      'schema_version': 1,
      'summary': 'Review the recommendation.',
      'rationale_json': '["Confirmed breakdown."]',
      'limitations_json': '["Staff verification required."]',
      'checklist_json': '["Review evidence."]',
      'generated_at_utc': '2026-08-29T01:00:30.000Z',
    };
