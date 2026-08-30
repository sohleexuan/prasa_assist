import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_user_scope.dart';
import '../../../../core/database/migrations/app_database_migration_v5.dart';

import 'package:sqflite/sqflite.dart';

import '../dto/recommendation_record_dto.dart';
import 'recommendation_local_data_source.dart';

class SqliteRecommendationLocalDataSource
    implements RecommendationLocalDataSource {
  factory SqliteRecommendationLocalDataSource({
    required AppDatabase database,
    required LocalUserScope userScope,
  }) => SqliteRecommendationLocalDataSource._(database, userScope.ownerUserId);

  SqliteRecommendationLocalDataSource._(this._database, this._ownerUserId);

  final AppDatabase _database;
  final String _ownerUserId;

  @override
  Future<List<RecommendationRecordDto>> readAll() async {
    final rows = await _database.rawQuery(
      '''
      SELECT r.*, a.model_identifier, a.schema_version, a.summary,
        a.rationale_json, a.limitations_json, a.checklist_json,
        a.generated_at_utc
      FROM ${AppDatabaseMigrationV5.recommendationRecordsTable} r
      LEFT JOIN ${AppDatabaseMigrationV5.recommendationAnalysesTable} a
        ON a.recommendation_id = r.recommendation_id
        AND a.owner_user_id = r.owner_user_id
      WHERE r.owner_user_id = ?
      ORDER BY r.updated_at_utc DESC
    ''',
      [_ownerUserId],
    );
    return List.unmodifiable(rows.map(_fromJoinedRow));
  }

  @override
  Future<RecommendationRecordDto?> readById(String id) async {
    final records = (await readAll())
        .where((record) => record.recommendation.id == id.trim())
        .toList(growable: false);
    return records.isEmpty ? null : records.single;
  }

  @override
  Future<void> replaceAll(
    Iterable<RecommendationRecordDto> records, {
    required DateTime retrievedAt,
  }) async {
    await _database.transaction((transaction) async {
      for (final record in records) {
        if (record.recommendation.ownerUserId != _ownerUserId) {
          throw StateError('Recommendation owner scope mismatch.');
        }
        await transaction.insert(
          AppDatabaseMigrationV5.recommendationRecordsTable,
          record.toLocalRow(retrievedAt: retrievedAt),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        final analysis = record.toLocalAnalysisRow();
        if (analysis != null) {
          await transaction.insert(
            AppDatabaseMigrationV5.recommendationAnalysesTable,
            analysis,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    });
  }

  RecommendationRecordDto _fromJoinedRow(Map<String, Object?> row) {
    final map = row.map((key, value) => MapEntry<String, dynamic>(key, value));
    map['id'] = map['recommendation_id'];
    map['version'] = map['remote_version'];
    map['recommendation_analyses'] = map['model_identifier'] == null
        ? <Object>[]
        : [
            {
              'model_identifier': map['model_identifier'],
              'schema_version': map['schema_version'],
              'summary': map['summary'],
              'rationale_json': map['rationale_json'],
              'limitations_json': map['limitations_json'],
              'checklist_json': map['checklist_json'],
              'generated_at_utc': map['generated_at_utc'],
            },
          ];
    return RecommendationRecordDto.fromMap(map);
  }
}
