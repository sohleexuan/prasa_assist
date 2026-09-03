import 'package:sqflite/sqflite.dart';

import 'app_database_migration_v4.dart';

abstract final class AppDatabaseMigrationV8 {
  static const String staffProfilesTable = 'local_staff_profiles';

  static Future<void> apply(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE $staffProfilesTable (
        owner_user_id TEXT NOT NULL CHECK (${_uuidCheck('owner_user_id')}),
        user_id TEXT NOT NULL CHECK (${_uuidCheck('user_id')}),
        staff_code TEXT NOT NULL CHECK (
          trim(staff_code) <> ''
          AND staff_code = upper(trim(staff_code))
        ),
        display_name TEXT NOT NULL CHECK (trim(display_name) <> ''),
        role TEXT NOT NULL CHECK (
          role IN (
            'operations_staff', 'maintenance_staff',
            'supervisor', 'control_centre'
          )
        ),
        active INTEGER NOT NULL CHECK (active IN (0, 1)),
        version INTEGER NOT NULL CHECK (version >= 1),
        retrieved_at_utc TEXT NOT NULL CHECK (
          substr(retrieved_at_utc, -1, 1) = 'Z'
          AND julianday(retrieved_at_utc) IS NOT NULL
        ),
        PRIMARY KEY (owner_user_id, user_id),
        UNIQUE (owner_user_id, staff_code COLLATE NOCASE)
      )
    ''');
    await database.execute('''
      CREATE INDEX ix_local_staff_profiles_owner_assignment
      ON $staffProfilesTable(owner_user_id, active, role, display_name)
    ''');

    await database.execute('''
      ALTER TABLE ${AppDatabaseMigrationV4.workOrderRecordsTable}
      ADD COLUMN assigned_to_user_id TEXT CHECK (
        assigned_to_user_id IS NULL OR (${_uuidCheck('assigned_to_user_id')})
      )
    ''');
    await database.execute('''
      ALTER TABLE ${AppDatabaseMigrationV4.workOrderRecordsTable}
      ADD COLUMN assigned_to_label_snapshot TEXT CHECK (
        assigned_to_label_snapshot IS NULL
        OR trim(assigned_to_label_snapshot) <> ''
      )
    ''');
    await database.execute('''
      CREATE TRIGGER enforce_local_work_order_assignment_pair_insert
      BEFORE INSERT ON ${AppDatabaseMigrationV4.workOrderRecordsTable}
      FOR EACH ROW
      WHEN (NEW.assigned_to_user_id IS NULL)
        <> (NEW.assigned_to_label_snapshot IS NULL)
      BEGIN
        SELECT RAISE(
          ABORT,
          'assigned_to_user_id and assigned_to_label_snapshot must be paired'
        );
      END
    ''');
    await database.execute('''
      CREATE TRIGGER enforce_local_work_order_assignment_pair_update
      BEFORE UPDATE OF assigned_to_user_id, assigned_to_label_snapshot
      ON ${AppDatabaseMigrationV4.workOrderRecordsTable}
      FOR EACH ROW
      WHEN (NEW.assigned_to_user_id IS NULL)
        <> (NEW.assigned_to_label_snapshot IS NULL)
      BEGIN
        SELECT RAISE(
          ABORT,
          'assigned_to_user_id and assigned_to_label_snapshot must be paired'
        );
      END
    ''');
    await database.execute('''
      CREATE INDEX ix_local_work_orders_owner_assignee_user
      ON ${AppDatabaseMigrationV4.workOrderRecordsTable}(
        owner_user_id, assigned_to_user_id
      )
      WHERE assigned_to_user_id IS NOT NULL
    ''');
  }

  static String _uuidCheck(String column) =>
      '''
    length($column) = 36
    AND substr($column, 9, 1) = '-'
    AND substr($column, 14, 1) = '-'
    AND substr($column, 19, 1) = '-'
    AND substr($column, 24, 1) = '-'
    AND length(replace($column, '-', '')) = 32
    AND lower(replace($column, '-', '')) NOT GLOB '*[^0-9a-f]*'
  ''';
}
