import '../data/dto/recommendation_record_dto.dart';
import '../models/recommendation_read_result.dart';

abstract interface class RecommendationHybridOperations {
  Future<RecommendationReadResult<List<RecommendationRecordDto>>>
  readAllWithProvenance();
}
