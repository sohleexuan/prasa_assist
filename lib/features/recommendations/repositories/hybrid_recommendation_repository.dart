import '../data/dto/recommendation_record_dto.dart';
import '../data/sources/recommendation_local_data_source.dart';
import '../data/sources/recommendation_remote_data_source.dart';
import '../models/recommendation_read_result.dart';
import 'recommendation_data_exception.dart';
import 'recommendation_hybrid_operations.dart';
import 'recommendation_repository.dart';

class HybridRecommendationRepository
    implements RecommendationRepository, RecommendationHybridOperations {
  factory HybridRecommendationRepository({
    required RecommendationRemoteDataSource remote,
    required RecommendationLocalDataSource local,
    DateTime Function()? clock,
  }) => HybridRecommendationRepository._(remote, local, clock ?? DateTime.now);

  HybridRecommendationRepository._(this._remote, this._local, this._clock);

  final RecommendationRemoteDataSource _remote;
  final RecommendationLocalDataSource _local;
  final DateTime Function() _clock;

  @override
  Future<List<RecommendationRecordDto>> readAll() async =>
      (await readAllWithProvenance()).data;

  @override
  Future<RecommendationReadResult<List<RecommendationRecordDto>>>
  readAllWithProvenance() async {
    try {
      final records = await _remote.fetchAll();
      final retrievedAtUtc = _clock().toUtc();
      await _local.replaceAll(records, retrievedAt: retrievedAtUtc);
      return RecommendationReadResult(
        data: records,
        provenance: RecommendationReadProvenance(
          source: RecommendationReadSource.liveSupabase,
          retrievedAtUtc: retrievedAtUtc,
        ),
      );
    } on RecommendationOfflineException {
      final cached = await _local.readAll();
      if (cached.isEmpty) rethrow;
      final retrievedAtUtc = await _local.readOldestRetrievedAtUtc();
      if (retrievedAtUtc == null) {
        throw const RecommendationMappingException(
          'Cached recommendation retrieval time is unavailable.',
        );
      }
      return RecommendationReadResult(
        data: cached,
        provenance: RecommendationReadProvenance(
          source: RecommendationReadSource.cachedSqlite,
          retrievedAtUtc: retrievedAtUtc,
          warningMessage:
              'Showing cached/offline SQLite recommendation data — not live.',
        ),
      );
    }
  }

  @override
  Future<RecommendationRecordDto?> readById(String id) async {
    try {
      final record = await _remote.fetchById(id);
      if (record != null) {
        await _local.replaceAll([record], retrievedAt: _clock().toUtc());
      }
      return record;
    } on RecommendationOfflineException {
      return _local.readById(id);
    }
  }

  @override
  Future<RecommendationRecordDto> createPending(
    RecommendationRecordDto record,
  ) async {
    final authoritative = await _remote.createPending(record);
    await _local.replaceAll([authoritative], retrievedAt: _clock().toUtc());
    return authoritative;
  }

  @override
  Future<RecommendationRecordDto> decide(
    String id, {
    required String decision,
    String? note,
    required int expectedVersion,
  }) async {
    final record = await _remote.decide(
      id,
      decision: decision,
      note: note,
      expectedVersion: expectedVersion,
    );
    await _local.replaceAll([record], retrievedAt: _clock().toUtc());
    return record;
  }

  @override
  Future<RecommendationRecordDto> generateAnalysis(String id) async {
    final current = await readById(id);
    if (current?.analysis != null) {
      return current!;
    }
    final record = await _remote.generateAnalysis(id);
    await _local.replaceAll([record], retrievedAt: _clock().toUtc());
    return record;
  }
}
