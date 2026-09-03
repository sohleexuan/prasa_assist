import 'package:sqflite/sqflite.dart';

import 'app_database_migration_v5.dart';

abstract final class AppDatabaseMigrationV6 {
  static const _replacementTable = 'local_recommendation_analyses_v6';

  static Future<void> apply(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE $_replacementTable (
        recommendation_id TEXT NOT NULL,
        owner_user_id TEXT NOT NULL,
        model_identifier TEXT NOT NULL CHECK (
          model_identifier IN ('gemini-2.5-flash', 'openai/gpt-oss-20b')
        ),
        schema_version INTEGER NOT NULL CHECK (schema_version >= 1),
        summary TEXT NOT NULL CHECK (trim(summary) <> ''),
        rationale_json TEXT NOT NULL CHECK (json_valid(rationale_json)),
        limitations_json TEXT NOT NULL CHECK (json_valid(limitations_json)),
        checklist_json TEXT NOT NULL CHECK (json_valid(checklist_json)),
        generated_at_utc TEXT NOT NULL CHECK (
          substr(generated_at_utc, -1, 1) = 'Z'
          AND julianday(generated_at_utc) IS NOT NULL
        ),
        PRIMARY KEY (recommendation_id, owner_user_id),
        FOREIGN KEY (recommendation_id, owner_user_id)
          REFERENCES ${AppDatabaseMigrationV5.recommendationRecordsTable}(
            recommendation_id, owner_user_id
          ) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      INSERT INTO $_replacementTable (
        recommendation_id, owner_user_id, model_identifier, schema_version,
        summary, rationale_json, limitations_json, checklist_json,
        generated_at_utc
      )
      SELECT
        recommendation_id, owner_user_id, model_identifier, schema_version,
        summary, rationale_json, limitations_json, checklist_json,
        generated_at_utc
      FROM ${AppDatabaseMigrationV5.recommendationAnalysesTable}
    ''');
    await database.execute(
      'DROP TABLE ${AppDatabaseMigrationV5.recommendationAnalysesTable}',
    );
    await database.execute('''
      ALTER TABLE $_replacementTable
      RENAME TO ${AppDatabaseMigrationV5.recommendationAnalysesTable}
    ''');
  }
}
