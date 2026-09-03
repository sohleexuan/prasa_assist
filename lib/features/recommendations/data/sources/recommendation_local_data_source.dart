import '../dto/recommendation_record_dto.dart';

abstract interface class RecommendationLocalDataSource {
  Future<List<RecommendationRecordDto>> readAll();
  Future<RecommendationRecordDto?> readById(String id);
  Future<DateTime?> readOldestRetrievedAtUtc();
  Future<void> replaceAll(
    Iterable<RecommendationRecordDto> records, {
    required DateTime retrievedAt,
  });
}
