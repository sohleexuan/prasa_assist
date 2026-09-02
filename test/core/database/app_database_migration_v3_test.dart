import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/app_database_schema.dart';
import 'package:prasa_assist/core/database/migrations/app_database_migration_v3.dart';

import '../../support/sqlite_test_database.dart';

void main() {
  group('AppDatabase migration version 3', () {
    test('fresh install applies v1, v2 and v3 in order', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      await database.ensureOpen();
      expect(
        (await database.query(
          AppDatabaseSchema.migrationTable,
          orderBy: 'version ASC',
        )).map((row) => row['version']),
        [1, 2, 3, 4, 5, 6, 7],
      );
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN (?, ?)",
        [
          AppDatabaseMigrationV3.incidentRecordsTable,
          AppDatabaseMigrationV3.incidentHistoryTable,
        ],
      );
      expect(tables, hasLength(2));
      final indexes = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = ?",
        [AppDatabaseMigrationV3.incidentRecordsTable],
      );
      expect(
        indexes.map((row) => row['name']),
        containsAll(<String>[
          'ux_local_incidents_owner_remote_id',
          'ux_local_incidents_owner_code',
          'ix_local_incidents_owner_state_reported',
          'ix_local_incidents_owner_state_modified',
        ]),
      );
      final foreignKeys = await database.rawQuery(
        'PRAGMA foreign_key_list(${AppDatabaseMigrationV3.incidentHistoryTable})',
      );
      expect(foreignKeys, hasLength(2));
      expect(foreignKeys.every((row) => row['on_delete'] == 'CASCADE'), isTrue);
    });

    test('version-2 database upgrades with only v3 metadata added', () async {
      final directory = await Directory.systemTemp.createTemp('prasa-v3-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}upgrade.db';
      final v2 = await createVersionTwoFileDatabase(path);
      await v2.close();
      final upgraded = createFileTestDatabase(path);
      addTearDown(upgraded.close);
      expect(
        (await upgraded.query(
          AppDatabaseSchema.migrationTable,
          orderBy: 'version ASC',
        )).map((row) => row['version']),
        [1, 2, 3, 4, 5, 6, 7],
      );
    });

    test(
      'failed v3 SQL rolls back without recording migration metadata',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'prasa-v3-rollback-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final path = '${directory.path}${Platform.pathSeparator}rollback.db';
        final database = await createVersionTwoFileDatabase(path);

        await expectLater(
          database.transaction((transaction) async {
            await AppDatabaseMigrationV3.apply(transaction);
            throw StateError('Simulated migration failure.');
          }),
          throwsStateError,
        );

        expect(
          await database.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
            [AppDatabaseMigrationV3.incidentRecordsTable],
          ),
          isEmpty,
        );
        expect(
          await database.query(
            AppDatabaseSchema.migrationTable,
            where: 'version = ?',
            whereArgs: [3],
          ),
          isEmpty,
        );
        await database.close();

        final reopened = createFileTestDatabase(path);
        addTearDown(reopened.close);
        expect(
          (await reopened.query(
            AppDatabaseSchema.migrationTable,
            orderBy: 'version ASC',
          )).map((row) => row['version']),
          [1, 2, 3, 4, 5, 6, 7],
        );
      },
    );
  });
}
