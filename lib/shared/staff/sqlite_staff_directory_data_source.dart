import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/database/local_database_exception.dart';
import '../../core/database/local_user_scope.dart';
import '../../core/database/migrations/app_database_migration_v8.dart';
import 'staff_directory_data_source.dart';
import 'staff_directory_exception.dart';
import 'staff_profile.dart';

class SqliteStaffDirectoryDataSource implements StaffDirectoryLocalDataSource {
  factory SqliteStaffDirectoryDataSource({
    required AppDatabase database,
    required LocalUserScope userScope,
  }) => SqliteStaffDirectoryDataSource._(database, userScope.ownerUserId);

  SqliteStaffDirectoryDataSource._(this._database, this._ownerUserId);

  static const _table = AppDatabaseMigrationV8.staffProfilesTable;

  final AppDatabase _database;
  final String _ownerUserId;

  @override
  Future<List<CachedStaffProfile>> readAll() => _guard(() async {
    final rows = await _database.query(
      _table,
      where: 'owner_user_id = ?',
      whereArgs: [_ownerUserId],
      orderBy:
          'active DESC, display_name COLLATE NOCASE, staff_code COLLATE NOCASE',
    );
    return List<CachedStaffProfile>.unmodifiable(rows.map(_fromRow));
  });

  @override
  Future<void> replaceActiveDirectory(
    Iterable<StaffProfile> profiles, {
    required DateTime retrievedAt,
  }) => _guard(() async {
    final values = _validateUnique(profiles);
    final retrieved = retrievedAt.toUtc();
    await _database.transaction((transaction) async {
      await transaction.update(
        _table,
        {'active': 0},
        where: 'owner_user_id = ?',
        whereArgs: [_ownerUserId],
      );
      for (final profile in values) {
        await transaction.insert(
          _table,
          _row(profile, retrieved),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  });

  @override
  Future<void> upsert(
    Iterable<StaffProfile> profiles, {
    required DateTime retrievedAt,
  }) => _guard(() async {
    final values = _validateUnique(profiles);
    final retrieved = retrievedAt.toUtc();
    await _database.transaction((transaction) async {
      for (final profile in values) {
        await transaction.insert(
          _table,
          _row(profile, retrieved),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  });

  List<StaffProfile> _validateUnique(Iterable<StaffProfile> profiles) {
    final values = profiles.toList(growable: false);
    final userIds = values.map((profile) => profile.userId).toSet();
    final staffCodes = values
        .map((profile) => profile.staffCode.toUpperCase())
        .toSet();
    if (userIds.length != values.length || staffCodes.length != values.length) {
      throw const StaffDirectoryMappingException(
        'The staff directory cache input contains duplicate identities.',
      );
    }
    return values;
  }

  Map<String, Object?> _row(StaffProfile profile, DateTime retrievedAt) => {
    'owner_user_id': _ownerUserId,
    'user_id': profile.userId,
    'staff_code': profile.staffCode,
    'display_name': profile.displayName,
    'role': profile.role.storageValue,
    'active': profile.active ? 1 : 0,
    'version': profile.version,
    'retrieved_at_utc': retrievedAt.toIso8601String(),
  };

  CachedStaffProfile _fromRow(Map<String, Object?> row) {
    try {
      return CachedStaffProfile(
        profile: StaffProfile(
          userId: row['user_id']! as String,
          staffCode: row['staff_code']! as String,
          displayName: row['display_name']! as String,
          role: StaffRole.fromStorage(row['role']),
          active: row['active'] == 1,
          version: row['version']! as int,
        ),
        retrievedAt: DateTime.parse(row['retrieved_at_utc']! as String).toUtc(),
      );
    } catch (error) {
      throw StaffDirectoryMappingException(
        'The cached staff directory contains invalid data.',
        cause: error,
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on StaffDirectoryException {
      rethrow;
    } on LocalDatabaseException catch (error) {
      throw StaffDirectoryException(
        'The offline staff directory cache is unavailable.',
        cause: error,
      );
    }
  }
}
