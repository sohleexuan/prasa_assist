import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_status.dart';

class OperationsRecommendation {
  OperationsRecommendation({
    required this.id,
    required this.incidentId,
    required this.vehicleId,
    required this.routeId,
    required List<RecommendationAction> actions,
    required List<RecommendationEvidence> evidence,
    required this.status,
    required this.score,
    required this.confidenceDetails,
    required DateTime createdAt,
  }) : actions = List<RecommendationAction>.unmodifiable(actions),
       evidence = List<RecommendationEvidence>.unmodifiable(evidence),
       createdAt = createdAt.toUtc() {
    if (actions.isEmpty) {
      throw ArgumentError.value(
        actions,
        'actions',
        'must contain at least one proposed action',
      );
    }
    if (evidence.isEmpty) {
      throw ArgumentError.value(
        evidence,
        'evidence',
        'must contain at least one evidence item',
      );
    }
    if (score < 0 || score > 100) {
      throw ArgumentError.value(score, 'score', 'must be from 0 through 100');
    }
  }

  final String id;
  final String incidentId;
  final String vehicleId;
  final String routeId;
  final List<RecommendationAction> actions;
  final List<RecommendationEvidence> evidence;
  final RecommendationStatus status;
  final int score;
  final RecommendationConfidence confidenceDetails;

  double get confidence => confidenceDetails.finalConfidence;

  final DateTime createdAt;
}
