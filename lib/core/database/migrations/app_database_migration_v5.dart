import 'package:sqflite/sqflite.dart';

abstract final class AppDatabaseMigrationV5 {
  static const recommendationRecordsTable = 'local_recommendation_records';
  static const recommendationAnalysesTable = 'local_recommendation_analyses';

  static Future<void> apply(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE $recommendationRecordsTable (
        recommendation_id TEXT NOT NULL CHECK (trim(recommendation_id) <> ''),
        owner_user_id TEXT NOT NULL CHECK (length(owner_user_id) = 36),
        incident_id TEXT,
        vehicle_id TEXT NOT NULL CHECK (trim(vehicle_id) <> ''),
        route_id TEXT,
        actions_json TEXT NOT NULL CHECK (json_valid(actions_json)),
        evidence_json TEXT NOT NULL CHECK (json_valid(evidence_json)),
        score INTEGER NOT NULL CHECK (score BETWEEN 0 AND 100),
        confidence_details_json TEXT NOT NULL
          CHECK (json_valid(confidence_details_json)),
        status TEXT NOT NULL CHECK (
          status IN ('pending_review', 'accepted', 'rejected')
        ),
        decision_user_id TEXT,
        decision_at_utc TEXT CHECK (
          decision_at_utc IS NULL OR (
            substr(decision_at_utc, -1, 1) = 'Z'
            AND julianday(decision_at_utc) IS NOT NULL
          )
        ),
        decision_note TEXT CHECK (
          decision_note IS NULL OR trim(decision_note) <> ''
        ),
        remote_version INTEGER NOT NULL CHECK (remote_version >= 1),
        sync_state TEXT NOT NULL CHECK (
          sync_state IN (
            'cached_remote', 'local_draft', 'pending_publication',
            'publication_failed', 'conflict'
          )
        ),
        created_at_utc TEXT NOT NULL CHECK (
          substr(created_at_utc, -1, 1) = 'Z'
          AND julianday(created_at_utc) IS NOT NULL
        ),
        updated_at_utc TEXT NOT NULL CHECK (
          substr(updated_at_utc, -1, 1) = 'Z'
          AND julianday(updated_at_utc) IS NOT NULL
        ),
        retrieved_at_utc TEXT NOT NULL CHECK (
          substr(retrieved_at_utc, -1, 1) = 'Z'
          AND julianday(retrieved_at_utc) IS NOT NULL
        ),
        safe_error_message TEXT,
        PRIMARY KEY (recommendation_id, owner_user_id),
        CHECK (julianday(updated_at_utc) >= julianday(created_at_utc)),
        CHECK (
          (status = 'pending_review' AND decision_user_id IS NULL
            AND decision_at_utc IS NULL AND decision_note IS NULL)
          OR (status IN ('accepted', 'rejected')
            AND decision_user_id IS NOT NULL AND decision_at_utc IS NOT NULL)
        )
      )
    ''');
    await database.execute('''
      CREATE TABLE $recommendationAnalysesTable (
        recommendation_id TEXT NOT NULL,
        owner_user_id TEXT NOT NULL,
        model_identifier TEXT NOT NULL CHECK (
          model_identifier = 'gemini-2.5-flash'
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
          REFERENCES $recommendationRecordsTable(
            recommendation_id, owner_user_id
          ) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE INDEX ix_local_recommendations_owner_updated
      ON $recommendationRecordsTable(owner_user_id, updated_at_utc DESC)
    ''');
    await database.execute('''
      CREATE INDEX ix_local_recommendations_owner_status
      ON $recommendationRecordsTable(owner_user_id, status)
    ''');
  }
}
