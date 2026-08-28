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
    final expectedScore = evidence
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
