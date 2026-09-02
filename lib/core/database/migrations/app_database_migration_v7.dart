import 'package:sqflite/sqflite.dart';

import 'app_database_migration_v4.dart';

/// Globally ordered schema version 7: Work Order route linkage and strict
/// schedule writes.
///
/// The table is not rebuilt, so legacy equality rows remain readable. The
/// triggers reject equality or reversed schedules on new writes while allowing
/// an upgraded equality row to be corrected, cancelled, or refreshed after
/// cancellation.
abstract final class AppDatabaseMigrationV7 {
  static const _table = AppDatabaseMigrationV4.workOrderRecordsTable;

  static Future<void> apply(DatabaseExecutor database) async {
    await database.execute('''
      ALTER TABLE $_table
      ADD COLUMN route_id TEXT CHECK (
        route_id IS NULL OR trim(route_id) <> ''
      )
    ''');
    await database.execute('''
      CREATE TRIGGER strict_local_work_order_schedule_insert
      BEFORE INSERT ON $_table
      FOR EACH ROW
      WHEN NEW.scheduled_start_utc IS NOT NULL
        AND NEW.scheduled_end_utc IS NOT NULL
        AND julianday(NEW.scheduled_end_utc)
          <= julianday(NEW.scheduled_start_utc)
      BEGIN
        SELECT RAISE(
          ABORT,
          'scheduled_end_utc must be later than scheduled_start_utc'
        );
      END
    ''');
    await database.execute('''
      CREATE TRIGGER strict_local_work_order_schedule_update
      BEFORE UPDATE ON $_table
      FOR EACH ROW
      WHEN NEW.scheduled_start_utc IS NOT NULL
        AND NEW.scheduled_end_utc IS NOT NULL
        AND julianday(NEW.scheduled_end_utc)
          <= julianday(NEW.scheduled_start_utc)
        AND NOT (
          OLD.scheduled_start_utc IS NOT NULL
          AND OLD.scheduled_end_utc IS NOT NULL
          AND julianday(OLD.scheduled_end_utc)
            <= julianday(OLD.scheduled_start_utc)
          AND NEW.scheduled_start_utc = OLD.scheduled_start_utc
          AND NEW.scheduled_end_utc = OLD.scheduled_end_utc
          AND NEW.status = 'cancelled'
        )
      BEGIN
        SELECT RAISE(
          ABORT,
          'scheduled_end_utc must be later than scheduled_start_utc'
        );
      END
    ''');
  }
}
