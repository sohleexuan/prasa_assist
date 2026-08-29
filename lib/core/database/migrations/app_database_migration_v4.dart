import 'package:sqflite/sqflite.dart';

/// Globally ordered schema version 4: Module 2 local WorkOrder storage.
///
/// Supabase remains authoritative. This table stores owner-scoped confirmed
/// cache records and explicitly unpublished local staff drafts.
abstract final class AppDatabaseMigrationV4 {
  static const String workOrderRecordsTable = 'local_work_order_records';

  static Future<void> apply(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE $workOrderRecordsTable (
        local_id TEXT PRIMARY KEY NOT NULL CHECK (trim(local_id) <> ''),
        owner_user_id TEXT NOT NULL CHECK (
          length(owner_user_id) = 36
          AND substr(owner_user_id, 9, 1) = '-'
          AND substr(owner_user_id, 14, 1) = '-'
          AND substr(owner_user_id, 19, 1) = '-'
          AND substr(owner_user_id, 24, 1) = '-'
          AND length(replace(owner_user_id, '-', '')) = 32
          AND lower(replace(owner_user_id, '-', ''))
            NOT GLOB '*[^0-9a-f]*'
        ),
        remote_storage_id TEXT CHECK (
          remote_storage_id IS NULL OR (
            trim(remote_storage_id) <> ''
            AND length(remote_storage_id) = 36
            AND substr(remote_storage_id, 9, 1) = '-'
            AND substr(remote_storage_id, 14, 1) = '-'
            AND substr(remote_storage_id, 19, 1) = '-'
            AND substr(remote_storage_id, 24, 1) = '-'
            AND length(replace(remote_storage_id, '-', '')) = 32
            AND lower(replace(remote_storage_id, '-', ''))
              NOT GLOB '*[^0-9a-f]*'
          )
        ),
        work_order_id TEXT CHECK (
          work_order_id IS NULL OR trim(work_order_id) <> ''
        ),
        incident_id TEXT CHECK (
          incident_id IS NULL OR trim(incident_id) <> ''
        ),
        recommendation_id TEXT CHECK (
          recommendation_id IS NULL OR trim(recommendation_id) <> ''
        ),
        vehicle_id TEXT NOT NULL CHECK (trim(vehicle_id) <> ''),
        task_type TEXT NOT NULL CHECK (trim(task_type) <> ''),
        description TEXT NOT NULL CHECK (trim(description) <> ''),
        priority TEXT NOT NULL CHECK (
          priority IN ('low', 'medium', 'high', 'urgent')
        ),
        assigned_to TEXT CHECK (
          assigned_to IS NULL OR trim(assigned_to) <> ''
        ),
        scheduled_start_utc TEXT CHECK (
          scheduled_start_utc IS NULL OR (
            substr(scheduled_start_utc, -1, 1) = 'Z'
            AND julianday(scheduled_start_utc) IS NOT NULL
          )
        ),
        scheduled_end_utc TEXT CHECK (
          scheduled_end_utc IS NULL OR (
            substr(scheduled_end_utc, -1, 1) = 'Z'
            AND julianday(scheduled_end_utc) IS NOT NULL
          )
        ),
        status TEXT NOT NULL CHECK (
          status IN (
            'draft', 'open', 'assigned', 'in_progress', 'completed', 'cancelled'
          )
        ),
        notes TEXT CHECK (notes IS NULL OR trim(notes) <> ''),
        created_by_user_id TEXT NOT NULL CHECK (
          length(created_by_user_id) = 36
          AND substr(created_by_user_id, 9, 1) = '-'
          AND substr(created_by_user_id, 14, 1) = '-'
          AND substr(created_by_user_id, 19, 1) = '-'
          AND substr(created_by_user_id, 24, 1) = '-'
          AND length(replace(created_by_user_id, '-', '')) = 32
          AND lower(replace(created_by_user_id, '-', ''))
            NOT GLOB '*[^0-9a-f]*'
        ),
        created_by_label TEXT NOT NULL CHECK (trim(created_by_label) <> ''),
        remote_created_at_utc TEXT CHECK (
          remote_created_at_utc IS NULL OR (
            substr(remote_created_at_utc, -1, 1) = 'Z'
            AND julianday(remote_created_at_utc) IS NOT NULL
          )
        ),
        remote_updated_at_utc TEXT CHECK (
          remote_updated_at_utc IS NULL OR (
            substr(remote_updated_at_utc, -1, 1) = 'Z'
            AND julianday(remote_updated_at_utc) IS NOT NULL
          )
        ),
        completed_at_utc TEXT CHECK (
          completed_at_utc IS NULL OR (
            substr(completed_at_utc, -1, 1) = 'Z'
            AND julianday(completed_at_utc) IS NOT NULL
          )
        ),
        cancelled_at_utc TEXT CHECK (
          cancelled_at_utc IS NULL OR (
            substr(cancelled_at_utc, -1, 1) = 'Z'
            AND julianday(cancelled_at_utc) IS NOT NULL
          )
        ),
        remote_version INTEGER CHECK (
          remote_version IS NULL OR remote_version >= 1
        ),
        sync_state TEXT NOT NULL CHECK (
          sync_state IN (
            'cached_remote', 'local_draft', 'pending_publication',
            'publication_failed', 'conflict'
          )
        ),
        retrieved_at_utc TEXT CHECK (
          retrieved_at_utc IS NULL OR (
            substr(retrieved_at_utc, -1, 1) = 'Z'
            AND julianday(retrieved_at_utc) IS NOT NULL
          )
        ),
        local_created_at_utc TEXT NOT NULL CHECK (
          substr(local_created_at_utc, -1, 1) = 'Z'
          AND julianday(local_created_at_utc) IS NOT NULL
        ),
        local_modified_at_utc TEXT NOT NULL CHECK (
          substr(local_modified_at_utc, -1, 1) = 'Z'
          AND julianday(local_modified_at_utc) IS NOT NULL
        ),
        safe_error_message TEXT CHECK (
          safe_error_message IS NULL OR trim(safe_error_message) <> ''
        ),
        UNIQUE (local_id, owner_user_id),
        CHECK (
          (scheduled_start_utc IS NULL AND scheduled_end_utc IS NULL)
          OR (
            scheduled_start_utc IS NOT NULL
            AND scheduled_end_utc IS NOT NULL
            AND julianday(scheduled_end_utc) >= julianday(scheduled_start_utc)
          )
        ),
        CHECK (
          julianday(local_modified_at_utc) >= julianday(local_created_at_utc)
        ),
        CHECK (
          remote_created_at_utc IS NULL
          OR remote_updated_at_utc IS NULL
          OR julianday(remote_updated_at_utc) >= julianday(remote_created_at_utc)
        ),
        CHECK (
          (status = 'completed' AND completed_at_utc IS NOT NULL
            AND cancelled_at_utc IS NULL)
          OR (status = 'cancelled' AND cancelled_at_utc IS NOT NULL
            AND completed_at_utc IS NULL)
          OR (status NOT IN ('completed', 'cancelled')
            AND completed_at_utc IS NULL AND cancelled_at_utc IS NULL)
        ),
        CHECK (
          completed_at_utc IS NULL OR (
            remote_created_at_utc IS NOT NULL
            AND remote_updated_at_utc IS NOT NULL
            AND julianday(completed_at_utc) >= julianday(remote_created_at_utc)
            AND julianday(completed_at_utc) <= julianday(remote_updated_at_utc)
          )
        ),
        CHECK (
          cancelled_at_utc IS NULL OR (
            remote_created_at_utc IS NOT NULL
            AND remote_updated_at_utc IS NOT NULL
            AND julianday(cancelled_at_utc) >= julianday(remote_created_at_utc)
            AND julianday(cancelled_at_utc) <= julianday(remote_updated_at_utc)
          )
        ),
        CHECK (
          (status IN ('assigned', 'in_progress', 'completed')
            AND assigned_to IS NOT NULL)
          OR status NOT IN ('assigned', 'in_progress', 'completed')
        ),
        CHECK (
          (sync_state = 'cached_remote'
            AND remote_storage_id IS NOT NULL
            AND work_order_id IS NOT NULL
            AND remote_created_at_utc IS NOT NULL
            AND remote_updated_at_utc IS NOT NULL
            AND remote_version IS NOT NULL
            AND retrieved_at_utc IS NOT NULL
            AND safe_error_message IS NULL)
          OR
          (sync_state IN (
              'local_draft', 'pending_publication',
              'publication_failed', 'conflict'
            )
            AND status = 'draft'
            AND assigned_to IS NULL
            AND remote_storage_id IS NULL
            AND work_order_id IS NULL
            AND remote_created_at_utc IS NULL
            AND remote_updated_at_utc IS NULL
            AND completed_at_utc IS NULL
            AND cancelled_at_utc IS NULL
            AND remote_version IS NULL
            AND retrieved_at_utc IS NULL
            AND (
              (sync_state IN ('local_draft', 'pending_publication')
                AND safe_error_message IS NULL)
              OR (sync_state IN ('publication_failed', 'conflict')
                AND safe_error_message IS NOT NULL)
            ))
        )
      )
    ''');

    await database.execute('''
      CREATE UNIQUE INDEX ux_local_work_orders_owner_remote_id
      ON $workOrderRecordsTable(owner_user_id, remote_storage_id COLLATE NOCASE)
      WHERE remote_storage_id IS NOT NULL
    ''');
    await database.execute('''
      CREATE UNIQUE INDEX ux_local_work_orders_owner_code
      ON $workOrderRecordsTable(owner_user_id, work_order_id COLLATE NOCASE)
      WHERE work_order_id IS NOT NULL
    ''');
    await database.execute('''
      CREATE INDEX ix_local_work_orders_owner_sync_modified
      ON $workOrderRecordsTable(
        owner_user_id, sync_state, local_modified_at_utc DESC
      )
    ''');
    await database.execute('''
      CREATE INDEX ix_local_work_orders_owner_sync_schedule
      ON $workOrderRecordsTable(
        owner_user_id, sync_state, scheduled_start_utc
      )
    ''');
    await database.execute('''
      CREATE INDEX ix_local_work_orders_owner_status_priority
      ON $workOrderRecordsTable(
        owner_user_id, status, priority, remote_updated_at_utc DESC
      )
    ''');
  }
}
