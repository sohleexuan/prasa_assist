import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/app_database.dart';
import 'package:prasa_assist/core/database/app_database_opener.dart';
import 'package:prasa_assist/core/database/app_database_schema.dart';
import 'package:prasa_assist/core/database/local_database_exception.dart';

import '../../support/sqlite_test_database.dart';

void main() {
  group('AppDatabase', () {
    test(
      'opens the current schema with foreign keys and migration metadata',
      () async {
        final database = createInMemoryTestDatabase();
        addTearDown(database.close);

        await database.ensureOpen();

        final userVersion = await database.rawQuery('PRAGMA user_version');
        final foreignKeys = await database.rawQuery('PRAGMA foreign_keys');
        final migrations = await database.query(
          AppDatabaseSchema.migrationTable,
        );

        expect(userVersion.single['user_version'], AppDatabaseSchema.version);
        expect(foreignKeys.single['foreign_keys'], 1);
        expect(migrations.map((row) => row['version']), [1, 2, 3, 4, 5, 6, 7]);
        expect(
          migrations.every(
            (row) => DateTime.parse(row['applied_at_utc']! as String).isUtc,
          ),
          isTrue,
        );
      },
    );

    test('reopening a file database preserves local data', () async {
      final directory = await Directory.systemTemp.createTemp(
        'prasa-assist-sqlite-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}reopen.db';
      final first = createFileTestDatabase(path);
      addTearDown(first.close);

      await first.execute('CREATE TABLE reopen_check (value TEXT NOT NULL)');
      await first.insert('reopen_check', const {'value': 'preserved'});
      await first.close();

      final second = createFileTestDatabase(path);
      addTearDown(second.close);
      final rows = await second.query('reopen_check');

      expect(rows.single['value'], 'preserved');
    });

    test('commits successful transactions', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      await database.execute(
        'CREATE TABLE transaction_check (value TEXT NOT NULL)',
      );

      await database.transaction((transaction) async {
        await transaction.insert('transaction_check', const {
          'value': 'committed',
        });
      });

      final rows = await database.query('transaction_check');
      expect(rows.single['value'], 'committed');
    });

    test('rolls back failed transactions', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      await database.execute(
        'CREATE TABLE rollback_check (value TEXT NOT NULL)',
      );

      await expectLater(
        database.transaction<void>((transaction) async {
          await transaction.insert('rollback_check', const {
            'value': 'must roll back',
          });
          throw StateError('stop transaction');
        }),
        throwsStateError,
      );

      expect(await database.query('rollback_check'), isEmpty);
    });

    test('keeps separately injected in-memory databases isolated', () async {
      final first = createInMemoryTestDatabase();
      final second = createInMemoryTestDatabase();
      addTearDown(first.close);
      addTearDown(second.close);

      await first.execute('CREATE TABLE first_only (id INTEGER PRIMARY KEY)');

      final firstTables = await first.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 'first_only'",
      );
      final secondTables = await second.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 'first_only'",
      );
      expect(firstTables, hasLength(1));
      expect(secondTables, isEmpty);
    });

    test('closes idempotently and rejects later operations', () async {
      final database = createInMemoryTestDatabase();
      await database.ensureOpen();

      await database.close();
      await database.close();

      expect(database.isClosed, isTrue);
      await expectLater(
        database.rawQuery('SELECT 1'),
        throwsA(isA<LocalDatabaseClosedException>()),
      );
    });

    test('reports unsupported platforms through a safe typed error', () async {
      final database = AppDatabase(opener: AppDatabaseOpener.unsupported());
      addTearDown(database.close);

      Object? error;
      try {
        await database.ensureOpen();
      } catch (caught) {
        error = caught;
      }

      expect(error, isA<LocalDatabaseUnsupportedException>());
      expect(error.toString(), isNot(contains('UnsupportedError')));
    });
  });
}
