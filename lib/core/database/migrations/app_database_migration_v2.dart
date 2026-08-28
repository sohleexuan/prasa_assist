import 'package:sqflite/sqflite.dart';

/// Globally ordered schema version 2.
///
/// The physical schema lives in shared infrastructure so core never imports a
/// feature module. Module 3 may import these stable table-name constants.
abstract final class AppDatabaseMigrationV2 {
  static const String deploymentRecordsTable = 'local_deployment_records';
  static const String deploymentVehiclesTable = 'local_deployment_vehicles';

  static Future<void> apply(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE $deploymentRecordsTable (
        local_id TEXT PRIMARY KEY NOT NULL
          CHECK (trim(local_id) <> ''),
        owner_user_id TEXT NOT NULL
          CHECK (
            length(owner_user_id) = 36
            AND substr(owner_user_id, 9, 1) = '-'
            AND substr(owner_user_id, 14, 1) = '-'
            AND substr(owner_user_id, 19, 1) = '-'
            AND substr(owner_user_id, 24, 1) = '-'
          ),
        remote_storage_id TEXT
          CHECK (remote_storage_id IS NULL OR trim(remote_storage_id) <> ''),
        deployment_code TEXT
          CHECK (deployment_code IS NULL OR trim(deployment_code) <> ''),
        incident_id TEXT
          CHECK (incident_id IS NULL OR trim(incident_id) <> ''),
        recommendation_id TEXT
          CHECK (recommendation_id IS NULL OR trim(recommendation_id) <> ''),
        route_id TEXT NOT NULL CHECK (trim(route_id) <> ''),
        route_name TEXT NOT NULL CHECK (trim(route_name) <> ''),
        start_time_utc TEXT NOT NULL
          CHECK (substr(start_time_utc, -1, 1) = 'Z'),
        end_time_utc TEXT NOT NULL
          CHECK (substr(end_time_utc, -1, 1) = 'Z'),
        status TEXT NOT NULL
          CHECK (
            status IN ('draft', 'scheduled', 'active', 'completed', 'cancelled')
          ),
        purpose TEXT NOT NULL CHECK (trim(purpose) <> ''),
        created_by_label TEXT
          CHECK (created_by_label IS NULL OR trim(created_by_label) <> ''),
        remote_created_at_utc TEXT
          CHECK (
            remote_created_at_utc IS NULL
            OR substr(remote_created_at_utc, -1, 1) = 'Z'
          ),
        remote_updated_at_utc TEXT
          CHECK (
            remote_updated_at_utc IS NULL
            OR substr(remote_updated_at_utc, -1, 1) = 'Z'
          ),
        remote_version INTEGER
          CHECK (remote_version IS NULL OR remote_version >= 1),
        sync_state TEXT NOT NULL
          CHECK (
            sync_state IN (
              'cached_remote',
              'local_draft',
              'pending_publication',
              'publication_failed',
              'conflict'
            )
          ),
        retrieved_at_utc TEXT
          CHECK (
            retrieved_at_utc IS NULL
            OR substr(retrieved_at_utc, -1, 1) = 'Z'
          ),
        local_created_at_utc TEXT NOT NULL
          CHECK (substr(local_created_at_utc, -1, 1) = 'Z'),
        local_modified_at_utc TEXT NOT NULL
          CHECK (substr(local_modified_at_utc, -1, 1) = 'Z'),
        safe_error_message TEXT
          CHECK (
            safe_error_message IS NULL
            OR trim(safe_error_message) <> ''
          ),
        UNIQUE (local_id, owner_user_id),
        CHECK (
          (
            sync_state = 'cached_remote'
            AND deployment_code IS NOT NULL
            AND created_by_label IS NOT NULL
            AND remote_created_at_utc IS NOT NULL
            AND remote_updated_at_utc IS NOT NULL
            AND remote_version IS NOT NULL
            AND retrieved_at_utc IS NOT NULL
            AND safe_error_message IS NULL
          )
          OR
          (
            sync_state IN (
              'local_draft',
              'pending_publication',
              'publication_failed',
              'conflict'
            )
            AND status = 'draft'
            AND remote_storage_id IS NULL
            AND deployment_code IS NULL
            AND created_by_label IS NULL
            AND remote_created_at_utc IS NULL
            AND remote_updated_at_utc IS NULL
            AND remote_version IS NULL
            AND retrieved_at_utc IS NULL
            AND (
              (
                sync_state IN ('local_draft', 'pending_publication')
                AND safe_error_message IS NULL
              )
              OR
              (
                sync_state IN ('publication_failed', 'conflict')
                AND safe_error_message IS NOT NULL
              )
            )
          )
        )
      )
    ''');

    await database.execute('''
      CREATE TABLE $deploymentVehiclesTable (
        owner_user_id TEXT NOT NULL,
        local_deployment_id TEXT NOT NULL,
        display_order INTEGER NOT NULL CHECK (display_order >= 0),
        vehicle_id TEXT NOT NULL CHECK (trim(vehicle_id) <> ''),
        PRIMARY KEY (owner_user_id, local_deployment_id, display_order),
        UNIQUE (
          owner_user_id,
          local_deployment_id,
          vehicle_id COLLATE NOCASE
        ),
        FOREIGN KEY (local_deployment_id, owner_user_id)
          REFERENCES $deploymentRecordsTable(local_id, owner_user_id)
          ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE UNIQUE INDEX ux_local_deployments_owner_remote_id
      ON $deploymentRecordsTable(owner_user_id, remote_storage_id)
      WHERE remote_storage_id IS NOT NULL
    ''');
    await database.execute('''
      CREATE UNIQUE INDEX ux_local_deployments_owner_code
      ON $deploymentRecordsTable(
        owner_user_id,
        deployment_code COLLATE NOCASE
      )
      WHERE deployment_code IS NOT NULL
    ''');
    await database.execute('''
      CREATE INDEX ix_local_deployments_owner_sync_start
      ON $deploymentRecordsTable(owner_user_id, sync_state, start_time_utc)
    ''');
    await database.execute('''
      CREATE INDEX ix_local_deployments_owner_sync_modified
      ON $deploymentRecordsTable(
        owner_user_id,
        sync_state,
        local_modified_at_utc DESC
      )
    ''');
  }
}
