import '../data/dto/recommendation_record_dto.dart';

abstract interface class RecommendationRepository {
  Future<List<RecommendationRecordDto>> readAll();
  Future<RecommendationRecordDto?> readById(String id);
  Future<RecommendationRecordDto> decide(
    String id, {
    required String decision,
    String? note,
    required int expectedVersion,
  });
  Future<RecommendationRecordDto> generateAnalysis(String id);
}
