import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/app_database_schema.dart';
import 'package:prasa_assist/core/database/migrations/app_database_migration_v2.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/sqlite_test_database.dart';

void main() {
  group('AppDatabase migration version 2', () {
    test('new database creates both ordered migrations and tables', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);

      await database.ensureOpen();

      final version = await database.rawQuery('PRAGMA user_version');
      final foreignKeys = await database.rawQuery('PRAGMA foreign_keys');
      final migrations = await database.query(
        AppDatabaseSchema.migrationTable,
        orderBy: 'version ASC',
      );
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        'AND name IN (?, ?) ORDER BY name',
        [
          AppDatabaseMigrationV2.deploymentRecordsTable,
          AppDatabaseMigrationV2.deploymentVehiclesTable,
        ],
      );

      expect(version.single['user_version'], 4);
      expect(foreignKeys.single['foreign_keys'], 1);
      expect(migrations.map((row) => row['version']), [1, 2, 3, 4]);
      expect(tables, hasLength(2));
      final indexes = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND (name LIKE 'ux_local_deployments_%' "
        "OR name LIKE 'ix_local_deployments_%') ORDER BY name",
      );
      expect(indexes.map((row) => row['name']).toSet(), {
        'ix_local_deployments_owner_sync_modified',
        'ix_local_deployments_owner_sync_start',
        'ux_local_deployments_owner_code',
        'ux_local_deployments_owner_remote_id',
      });
    });

    test(
      'existing version-1 database upgrades once without data loss',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'prasa-assist-migration-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final path = '${directory.path}${Platform.pathSeparator}upgrade.db';
        final versionOne = await createVersionOneFileDatabase(path);
        await versionOne.execute(
          'CREATE TABLE preserved_before_v2 (value TEXT NOT NULL)',
        );
        await versionOne.insert('preserved_before_v2', {'value': 'kept'});
        await versionOne.close();

        final upgraded = createFileTestDatabase(path);
        await upgraded.ensureOpen();
        expect(
          (await upgraded.query('preserved_before_v2')).single['value'],
          'kept',
        );
        expect(
          (await upgraded.query(
            AppDatabaseSchema.migrationTable,
            orderBy: 'version ASC',
          )).map((row) => row['version']),
          [1, 2, 3, 4],
        );
        await upgraded.close();

        final reopened = createFileTestDatabase(path);
        addTearDown(reopened.close);
        expect(
          (await reopened.query(
            AppDatabaseSchema.migrationTable,
            orderBy: 'version ASC',
          )).map((row) => row['version']),
          [1, 2, 3, 4],
        );
        expect(
          (await reopened.query('preserved_before_v2')).single['value'],
          'kept',
        );
      },
    );

    test('failed version-2 transaction leaves no partial tables', () async {
      sqfliteFfiInit();
      final database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(database.close);

      await expectLater(
        database.transaction<void>((transaction) async {
          await AppDatabaseMigrationV2.apply(transaction);
          throw StateError('inject migration failure');
        }),
        throwsStateError,
      );

      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        'AND name IN (?, ?)',
        [
          AppDatabaseMigrationV2.deploymentRecordsTable,
          AppDatabaseMigrationV2.deploymentVehiclesTable,
        ],
      );
      expect(tables, isEmpty);
    });
  });
}
