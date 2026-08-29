import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_input.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_policy.dart';
import 'package:prasa_assist/features/recommendations/services/deterministic_recommendation_rule_engine.dart';
import 'package:prasa_assist/features/recommendations/services/explainable_confidence_scorer.dart';

void main() {
  final engine = DeterministicRecommendationRuleEngine(
    policy: RecommendationRulePolicy.ownerApproved(),
    confidenceScorer: const ExplainableConfidenceScorer(),
  );
  RecommendationRuleInput input(
    VehicleCondition condition,
    OperatingPeriod period,
  ) => RecommendationRuleInput(
    incidentId: 'incident-b1023',
    vehicleId: 'B1023',
    routeId: '300',
    vehicleCondition: condition,
    operatingPeriod: period,
    vehicleConditionDataClassification:
        EvidenceDataClassification.demonstrationData,
    operatingPeriodDataClassification:
        EvidenceDataClassification.demonstrationData,
    evaluatedAt: DateTime.utc(2026, 8, 28, 8),
  );

  test('produces the exact B1023 peak recommendation in stable order', () {
    final result = engine.evaluate(
      input(VehicleCondition.breakdownConfirmed, OperatingPeriod.peak),
    );
    expect(result.actions, hasLength(2));
    expect(result.actions[0], isA<InspectOrRepairVehicleAction>());
    expect(
      (result.actions[0] as InspectOrRepairVehicleAction).vehicleId,
      'B1023',
    );
    expect(result.actions[1], isA<DeployReplacementBusesAction>());
    final deploy = result.actions[1] as DeployReplacementBusesAction;
    expect(deploy.routeId, '300');
    expect(deploy.busCount, 2);
    expect(result.evidence.map((item) => item.ruleId), [
      'confirmed-vehicle-breakdown',
      'peak-breakdown-route-continuity',
    ]);
    expect(result.evidence.map((item) => item.contribution), [50, 35]);
    expect(result.score, 85);
    expect(result.confidenceDetails.baseConfidence, 1.0);
    expect(result.confidenceDetails.penalties, hasLength(1));
    expect(result.confidenceDetails.penalties.single.amount, 0.15);
    expect(result.confidenceDetails.finalConfidence, 0.85);
    expect(
      result.actions.whereType<InspectOrRepairVehicleAction>(),
      hasLength(1),
    );
    expect(
      result.actions.whereType<DeployReplacementBusesAction>(),
      hasLength(1),
    );
    final text = result.evidence
        .map((item) => item.description)
        .join(' ')
        .toLowerCase();
    for (final unsupported in [
      'occupancy',
      'realtime passenger demand',
      'trip updates',
      'service alerts',
      'rail realtime',
    ]) {
      expect(text, isNot(contains(unsupported)));
    }
  });

  test(
    'off-peak and unknown period inspect only; other conditions do not match',
    () {
      for (final period in [OperatingPeriod.offPeak, OperatingPeriod.unknown]) {
        final result = engine.evaluate(
          input(VehicleCondition.breakdownConfirmed, period),
        );
        expect(result.actions.single, isA<InspectOrRepairVehicleAction>());
        expect(result.score, 50);
      }
      expect(
        engine
            .evaluate(input(VehicleCondition.operational, OperatingPeriod.peak))
            .hasRecommendation,
        isFalse,
      );
      expect(
        engine
            .evaluate(input(VehicleCondition.unknown, OperatingPeriod.peak))
            .hasRecommendation,
        isFalse,
      );
    },
  );

  test('clamps the deterministic contribution sum to 100', () {
    final highPolicyEngine = DeterministicRecommendationRuleEngine(
      policy: RecommendationRulePolicy(
        confirmedBreakdownContribution: 100,
        peakBreakdownContribution: 100,
        replacementBusCount: 2,
        breakdownConfidenceWeight: .6,
        operatingPeriodConfidenceWeight: .4,
        demonstrationEvidencePenalty: .15,
      ),
      confidenceScorer: const ExplainableConfidenceScorer(),
    );
    final result = highPolicyEngine.evaluate(
      input(VehicleCondition.breakdownConfirmed, OperatingPeriod.peak),
    );
    expect(result.score, 100);
    expect(result.confidenceDetails.finalConfidence, 0.85);
  });

  test('equal scores retain independently calculated confidence', () {
    final fullySupported = engine.evaluate(
      input(VehicleCondition.breakdownConfirmed, OperatingPeriod.offPeak),
    );
    final partiallySupported = engine.evaluate(
      input(VehicleCondition.breakdownConfirmed, OperatingPeriod.unknown),
    );

    expect(fullySupported.score, 50);
    expect(partiallySupported.score, 50);
    expect(fullySupported.confidenceDetails.finalConfidence, 0.85);
    expect(
      partiallySupported.confidenceDetails.finalConfidence,
      closeTo(0.45, 0.000000001),
    );
    expect(
      fullySupported.confidenceDetails.finalConfidence,
      isNot(partiallySupported.confidenceDetails.finalConfidence),
    );
  });
}
