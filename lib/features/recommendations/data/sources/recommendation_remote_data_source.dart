import '../dto/recommendation_record_dto.dart';

abstract interface class RecommendationRemoteDataSource {
  Future<List<RecommendationRecordDto>> fetchAll();
  Future<RecommendationRecordDto?> fetchById(String id);
  Future<RecommendationRecordDto> decide(
    String id, {
    required String decision,
    String? note,
    required int expectedVersion,
  });
  Future<RecommendationRecordDto> generateAnalysis(String id);
}
