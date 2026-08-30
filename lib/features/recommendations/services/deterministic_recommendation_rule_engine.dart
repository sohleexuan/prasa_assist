import '../domain/recommendation_action.dart';
import '../domain/recommendation_evidence.dart';
import '../domain/recommendation_rule_evaluation.dart';
import '../domain/recommendation_rule_input.dart';
import '../domain/recommendation_rule_policy.dart';
import 'explainable_confidence_scorer.dart';

class DeterministicRecommendationRuleEngine {
  const DeterministicRecommendationRuleEngine({
    required this.policy,
    required this.confidenceScorer,
  });

  final RecommendationRulePolicy policy;
  final ExplainableConfidenceScorer confidenceScorer;

  RecommendationRuleEvaluation evaluate(RecommendationRuleInput input) {
    final actions = <RecommendationAction>[];
    final evidence = <RecommendationEvidence>[];
    final actionKeys = <String>{};

    void addAction(String key, RecommendationAction action) {
      if (actionKeys.add(key)) {
        actions.add(action);
      }
    }

    if (input.vehicleCondition == VehicleCondition.breakdownConfirmed) {
      addAction(
        'inspect:${input.vehicleId}',
        InspectOrRepairVehicleAction(vehicleId: input.vehicleId),
      );
      evidence.add(
        RecommendationEvidence(
          ruleId: 'confirmed-vehicle-breakdown',
          description:
              'Bus ${input.vehicleId} has a confirmed breakdown and '
              'requires staff inspection or repair.',
          dataClassification: input.vehicleConditionDataClassification,
          contribution: policy.confirmedBreakdownContribution,
        ),
      );
      if (input.operatingPeriod == OperatingPeriod.peak) {
        addAction(
          'deploy:${input.routeId}:${policy.replacementBusCount}',
          DeployReplacementBusesAction(
            routeId: input.routeId,
            busCount: policy.replacementBusCount,
          ),
        );
        evidence.add(
          RecommendationEvidence(
            ruleId: 'peak-breakdown-route-continuity',
            description:
                'Route ${input.routeId} requires staff review for '
                '${policy.replacementBusCount} replacement buses during the '
                'supplied peak operating period.',
            dataClassification: input.operatingPeriodDataClassification,
            contribution: policy.peakBreakdownContribution,
          ),
        );
      }
    }
    final score = evidence
        .fold<int>(0, (sum, item) => sum + item.contribution)
        .clamp(0, 100)
        .toInt();
    return RecommendationRuleEvaluation(
      input: input,
      actions: actions,
      evidence: evidence,
      score: score,
      confidenceDetails: confidenceScorer.score(input: input, policy: policy),
    );
  }
}
