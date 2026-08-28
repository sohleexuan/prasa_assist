import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
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
    required this.confidence,
    required this.createdAt,
  }) : actions = List<RecommendationAction>.unmodifiable(actions),
       evidence = List<RecommendationEvidence>.unmodifiable(evidence) {
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
    if (confidence.isNaN || confidence < 0.0 || confidence > 1.0) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'must be from 0.0 through 1.0',
      );
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
  final double confidence;
  final DateTime createdAt;
}
