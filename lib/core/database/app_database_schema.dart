import 'package:sqflite/sqflite.dart';

abstract final class AppDatabaseSchema {
  static const String filename = 'prasa_assist.db';
  static const int version = 1;
  static const String migrationTable = 'local_schema_migrations';

  static Future<void> onConfigure(Database database) async {
    await database.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> onCreate(Database database, int newVersion) async {
    await _migrate(database, fromVersion: 0, toVersion: newVersion);
  }

  static Future<void> onUpgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    await _migrate(database, fromVersion: oldVersion, toVersion: newVersion);
  }

  static Future<void> _migrate(
    DatabaseExecutor database, {
    required int fromVersion,
    required int toVersion,
  }) async {
    for (
      var nextVersion = fromVersion + 1;
      nextVersion <= toVersion;
      nextVersion++
    ) {
      switch (nextVersion) {
        case 1:
          await database.execute('''
            CREATE TABLE $migrationTable (
              version INTEGER PRIMARY KEY NOT NULL,
              applied_at_utc TEXT NOT NULL
            )
          ''');
          await database.insert(migrationTable, <String, Object?>{
            'version': 1,
            'applied_at_utc': DateTime.now().toUtc().toIso8601String(),
          });
        default:
          throw StateError(
            'No local database migration is registered for version '
            '$nextVersion.',
          );
      }
    }
  }
}
