import '../domain/recommendation.dart';
import '../domain/recommendation_rule_evaluation.dart';
import '../domain/recommendation_status.dart';

class RecommendationGenerator {
  const RecommendationGenerator();

  OperationsRecommendation? generate({
    required String recommendationId,
    required DateTime createdAt,
    required RecommendationRuleEvaluation evaluation,
  }) {
    final id = recommendationId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(recommendationId, 'recommendationId');
    }
    if (!evaluation.hasRecommendation) {
      return null;
    }
    return OperationsRecommendation(
      id: id,
      incidentId: evaluation.input.incidentId,
      vehicleId: evaluation.input.vehicleId,
      routeId: evaluation.input.routeId,
      actions: evaluation.actions,
      evidence: evaluation.evidence,
      status: RecommendationStatus.pendingReview,
      score: evaluation.score,
      confidenceDetails: evaluation.confidenceDetails,
      createdAt: createdAt.toUtc(),
    );
  }
}
