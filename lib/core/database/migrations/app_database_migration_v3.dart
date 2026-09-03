import 'package:sqflite/sqflite.dart';

abstract final class AppDatabaseMigrationV3 {
  static const String incidentRecordsTable = 'local_incident_records';
  static const String incidentHistoryTable = 'local_incident_status_history';

  static Future<void> apply(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE $incidentRecordsTable (
        local_id TEXT PRIMARY KEY NOT NULL CHECK (trim(local_id) <> ''),
        owner_user_id TEXT NOT NULL CHECK (
          length(owner_user_id) = 36
          AND substr(owner_user_id, 9, 1) = '-'
          AND substr(owner_user_id, 14, 1) = '-'
          AND substr(owner_user_id, 19, 1) = '-'
          AND substr(owner_user_id, 24, 1) = '-'
        ),
        remote_storage_id TEXT CHECK (
          remote_storage_id IS NULL OR trim(remote_storage_id) <> ''
        ),
        incident_code TEXT CHECK (incident_code IS NULL OR trim(incident_code) <> ''),
        incident_type TEXT NOT NULL CHECK (incident_type IN (
          'vehicle_breakdown', 'accident', 'service_disruption',
          'infrastructure_issue', 'safety_incident', 'other'
        )),
        title TEXT NOT NULL CHECK (trim(title) <> ''),
        description TEXT NOT NULL CHECK (trim(description) <> ''),
        route_id TEXT NOT NULL CHECK (trim(route_id) <> ''),
        route_name TEXT,
        vehicle_id TEXT,
        location TEXT NOT NULL CHECK (trim(location) <> ''),
        reported_at_utc TEXT NOT NULL CHECK (substr(reported_at_utc, -1, 1) = 'Z'),
        severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
        status TEXT NOT NULL CHECK (status IN (
          'reported', 'under_review', 'active', 'resolved', 'cancelled'
        )),
        vehicle_condition TEXT NOT NULL CHECK (vehicle_condition IN (
          'operational', 'limited_operation', 'immobilised', 'unknown'
        )),
        disruption_scope TEXT NOT NULL CHECK (disruption_scope IN (
          'no_obstruction', 'partial_obstruction', 'full_obstruction', 'unknown'
        )),
        estimated_delay_minutes INTEGER NOT NULL CHECK (estimated_delay_minutes >= 0),
        impact_level TEXT NOT NULL CHECK (impact_level IN ('minor', 'moderate', 'major', 'severe')),
        estimation_reasons_json TEXT NOT NULL CHECK (trim(estimation_reasons_json) <> ''),
        estimation_model_version INTEGER NOT NULL CHECK (estimation_model_version >= 1),
        data_source TEXT NOT NULL CHECK (data_source IN (
          'staff_entered', 'mock_demonstration', 'live_government',
          'cached_government', 'static_government'
        )),
        reported_by_label TEXT NOT NULL CHECK (trim(reported_by_label) <> ''),
        remote_created_at_utc TEXT CHECK (
          remote_created_at_utc IS NULL OR substr(remote_created_at_utc, -1, 1) = 'Z'
        ),
        remote_updated_at_utc TEXT CHECK (
          remote_updated_at_utc IS NULL OR substr(remote_updated_at_utc, -1, 1) = 'Z'
        ),
        remote_version INTEGER CHECK (remote_version IS NULL OR remote_version >= 1),
        sync_state TEXT NOT NULL CHECK (sync_state IN (
          'cached_remote', 'local_draft', 'pending_publication',
          'publication_failed', 'conflict'
        )),
        retrieved_at_utc TEXT CHECK (
          retrieved_at_utc IS NULL OR substr(retrieved_at_utc, -1, 1) = 'Z'
        ),
        local_created_at_utc TEXT NOT NULL CHECK (substr(local_created_at_utc, -1, 1) = 'Z'),
        local_modified_at_utc TEXT NOT NULL CHECK (substr(local_modified_at_utc, -1, 1) = 'Z'),
        safe_error_message TEXT CHECK (
          safe_error_message IS NULL OR trim(safe_error_message) <> ''
        ),
        UNIQUE (local_id, owner_user_id),
        CHECK (
          (sync_state = 'cached_remote'
            AND remote_storage_id IS NOT NULL AND incident_code IS NOT NULL
            AND remote_created_at_utc IS NOT NULL AND remote_updated_at_utc IS NOT NULL
            AND remote_version IS NOT NULL AND retrieved_at_utc IS NOT NULL
            AND safe_error_message IS NULL)
          OR
          (sync_state IN ('local_draft', 'pending_publication', 'publication_failed', 'conflict')
            AND status = 'reported' AND remote_storage_id IS NULL AND incident_code IS NULL
            AND remote_created_at_utc IS NULL AND remote_updated_at_utc IS NULL
            AND remote_version IS NULL AND retrieved_at_utc IS NULL
            AND ((sync_state IN ('local_draft', 'pending_publication') AND safe_error_message IS NULL)
              OR (sync_state IN ('publication_failed', 'conflict') AND safe_error_message IS NOT NULL)))
        )
      )
    ''');

    await database.execute('''
      CREATE TABLE $incidentHistoryTable (
        owner_user_id TEXT NOT NULL,
        local_incident_id TEXT NOT NULL,
        sequence_no INTEGER NOT NULL CHECK (sequence_no >= 1),
        from_status TEXT,
        to_status TEXT NOT NULL CHECK (to_status IN (
          'reported', 'under_review', 'active', 'resolved', 'cancelled'
        )),
        changed_at_utc TEXT NOT NULL CHECK (substr(changed_at_utc, -1, 1) = 'Z'),
        changed_by_label TEXT NOT NULL CHECK (trim(changed_by_label) <> ''),
        note TEXT,
        PRIMARY KEY (owner_user_id, local_incident_id, sequence_no),
        FOREIGN KEY (local_incident_id, owner_user_id)
          REFERENCES $incidentRecordsTable(local_id, owner_user_id)
          ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE UNIQUE INDEX ux_local_incidents_owner_remote_id
      ON $incidentRecordsTable(owner_user_id, remote_storage_id)
      WHERE remote_storage_id IS NOT NULL
    ''');
    await database.execute('''
      CREATE UNIQUE INDEX ux_local_incidents_owner_code
      ON $incidentRecordsTable(owner_user_id, incident_code COLLATE NOCASE)
      WHERE incident_code IS NOT NULL
    ''');
    await database.execute('''
      CREATE INDEX ix_local_incidents_owner_state_reported
      ON $incidentRecordsTable(owner_user_id, sync_state, reported_at_utc DESC)
    ''');
    await database.execute('''
      CREATE INDEX ix_local_incidents_owner_state_modified
      ON $incidentRecordsTable(owner_user_id, sync_state, local_modified_at_utc DESC)
    ''');
  }
}
