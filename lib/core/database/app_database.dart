import 'package:sqflite/sqflite.dart';

import 'app_database_opener.dart';
import 'local_database_exception.dart';

class AppDatabase {
  factory AppDatabase({required AppDatabaseOpener opener}) {
    return AppDatabase._(opener);
  }

  AppDatabase._(this._opener);

  final AppDatabaseOpener _opener;

  Database? _database;
  Future<Database>? _opening;
  bool _closed = false;

  bool get isOpen => _database?.isOpen ?? false;
  bool get isClosed => _closed;

  Future<void> ensureOpen() async {
    await _getDatabase();
  }

  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return _runOperation(
      (database) => database.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      ),
    );
  }

  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    return _runOperation((database) => database.rawQuery(sql, arguments));
  }

  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    return _runOperation(
      (database) =>
          database.insert(table, values, conflictAlgorithm: conflictAlgorithm),
    );
  }

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    return _runOperation(
      (database) => database.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      ),
    );
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return _runOperation(
      (database) => database.delete(table, where: where, whereArgs: whereArgs),
    );
  }

  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    await _runOperation<void>((database) => database.execute(sql, arguments));
  }

  Future<T> transaction<T>(
    Future<T> Function(AppDatabaseTransaction transaction) action,
  ) async {
    final database = await _getDatabase();
    try {
      return await database.transaction(
        (transaction) => action(AppDatabaseTransaction._(transaction)),
      );
    } on DatabaseException catch (error) {
      throw LocalDatabaseOperationException(
        'Unable to complete the local database transaction.',
        cause: error,
      );
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;

    Database? database = _database;
    final opening = _opening;
    if (database == null && opening != null) {
      try {
        database = await opening;
      } on LocalDatabaseException {
        return;
      }
    }
    _database = null;
    _opening = null;
    if (database?.isOpen ?? false) {
      await database!.close();
    }
  }

  Future<T> _runOperation<T>(
    Future<T> Function(Database database) operation,
  ) async {
    final database = await _getDatabase();
    try {
      return await operation(database);
    } on DatabaseException catch (error) {
      throw LocalDatabaseOperationException(
        'Unable to complete the local database operation.',
        cause: error,
      );
    }
  }

  Future<Database> _getDatabase() async {
    if (_closed) {
      throw const LocalDatabaseClosedException(
        'The local database has already been closed.',
      );
    }
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    final pending = _opening;
    if (pending != null) {
      return pending;
    }

    final opening = _openSafely();
    _opening = opening;
    return opening;
  }

  Future<Database> _openSafely() async {
    try {
      final database = await _opener.open();
      _database = database;
      _opening = null;
      return database;
    } on UnsupportedError catch (error) {
      _opening = null;
      throw LocalDatabaseUnsupportedException(
        'Local SQLite storage is not available on this platform.',
        cause: error,
      );
    } on LocalDatabaseException {
      _opening = null;
      rethrow;
    } catch (error) {
      _opening = null;
      throw LocalDatabaseOpenException(
        'Unable to open local application data.',
        cause: error,
      );
    }
  }
}

class AppDatabaseTransaction {
  AppDatabaseTransaction._(this._transaction);

  final Transaction _transaction;

  Future<List<Map<String, Object?>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) {
    return _transaction.query(
      table,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _transaction.insert(
      table,
      values,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _transaction.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) {
    return _transaction.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> execute(String sql, [List<Object?>? arguments]) {
    return _transaction.execute(sql, arguments);
  }

  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    return _transaction.rawQuery(sql, arguments);
  }
}
