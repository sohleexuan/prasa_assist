import 'recommendation_action.dart';
import 'recommendation_confidence.dart';
import 'recommendation_evidence.dart';
import 'recommendation_rule_input.dart';

class RecommendationRuleEvaluation {
  RecommendationRuleEvaluation({
    required this.input,
    required List<RecommendationAction> actions,
    required List<RecommendationEvidence> evidence,
    required this.score,
    required this.confidenceDetails,
  }) : actions = List.unmodifiable(actions),
       evidence = List.unmodifiable(evidence) {
    if (score < 0 || score > 100) {
      throw ArgumentError.value(score, 'score');
    }
    if (actions.isEmpty != evidence.isEmpty) {
      throw ArgumentError(
        'Actions and evidence must both be empty or nonempty.',
      );
    }
    _validateActions(input, this.actions);
    _validateEvidence(this.evidence);
    final expectedScore = this.evidence
        .fold<int>(0, (sum, item) => sum + item.contribution)
        .clamp(0, 100)
        .toInt();
    if (score != expectedScore) {
      throw ArgumentError.value(
        score,
        'score',
        'must equal the clamped evidence contribution sum $expectedScore',
      );
    }
  }

  final RecommendationRuleInput input;
  final List<RecommendationAction> actions;
  final List<RecommendationEvidence> evidence;
  final int score;
  final RecommendationConfidence confidenceDetails;

  bool get hasRecommendation => actions.isNotEmpty;
}

void _validateActions(
  RecommendationRuleInput input,
  List<RecommendationAction> actions,
) {
  for (final action in actions) {
    switch (action) {
      case InspectOrRepairVehicleAction():
        if (action.vehicleId.trim().isEmpty ||
            action.vehicleId != input.vehicleId) {
          throw ArgumentError.value(
            action.vehicleId,
            'actions',
            'inspection vehicleId must equal input.vehicleId',
          );
        }
        break;
      case DeployReplacementBusesAction():
        if (action.routeId.trim().isEmpty || action.routeId != input.routeId) {
          throw ArgumentError.value(
            action.routeId,
            'actions',
            'deployment routeId must equal input.routeId',
          );
        }
        break;
    }
  }
}

void _validateEvidence(List<RecommendationEvidence> evidence) {
  for (final item in evidence) {
    if (item.ruleId.trim().isEmpty) {
      throw ArgumentError.value(item.ruleId, 'evidence', 'ruleId is required');
    }
    if (item.description.trim().isEmpty) {
      throw ArgumentError.value(
        item.description,
        'evidence',
        'description is required',
      );
    }
    if (item.contribution < 0 || item.contribution > 100) {
      throw ArgumentError.value(
        item.contribution,
        'evidence',
        'contribution must be from 0 through 100',
      );
    }
  }
}
