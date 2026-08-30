import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_evaluation.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_input.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_policy.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_status.dart';
import 'package:prasa_assist/features/recommendations/services/deterministic_recommendation_rule_engine.dart';
import 'package:prasa_assist/features/recommendations/services/explainable_confidence_scorer.dart';
import 'package:prasa_assist/features/recommendations/services/recommendation_generator.dart';

void main() {
  final input = RecommendationRuleInput(
    incidentId: 'incident-1',
    vehicleId: 'B1023',
    routeId: '300',
    vehicleCondition: VehicleCondition.breakdownConfirmed,
    operatingPeriod: OperatingPeriod.offPeak,
    vehicleConditionDataClassification:
        EvidenceDataClassification.internalOperationalData,
    operatingPeriodDataClassification:
        EvidenceDataClassification.internalOperationalData,
    evaluatedAt: DateTime.utc(2026, 8, 28),
  );
  final confidence = RecommendationConfidence(
    factors: [
      RecommendationConfidenceFactor(
        factorId: 'vehicle-condition',
        description: 'Known.',
        weight: 1,
        isSupported: true,
      ),
    ],
    penalties: const [],
  );
  final engine = DeterministicRecommendationRuleEngine(
    policy: RecommendationRulePolicy.ownerApproved(),
    confidenceScorer: const ExplainableConfidenceScorer(),
  );
  RecommendationRuleInput ruleInput({
    required VehicleCondition condition,
    required OperatingPeriod period,
    EvidenceDataClassification vehicleClass =
        EvidenceDataClassification.demonstrationData,
    EvidenceDataClassification periodClass =
        EvidenceDataClassification.demonstrationData,
  }) => RecommendationRuleInput(
    incidentId: 'incident-b1023',
    vehicleId: 'B1023',
    routeId: '300',
    vehicleCondition: condition,
    operatingPeriod: period,
    vehicleConditionDataClassification: vehicleClass,
    operatingPeriodDataClassification: periodClass,
    evaluatedAt: DateTime(2026, 8, 28, 8),
  );

  test('maps a valid evaluation to pending review without side effects', () {
    final action = InspectOrRepairVehicleAction(vehicleId: 'B1023');
    final evidence = RecommendationEvidence(
      ruleId: 'breakdown',
      description: 'Confirmed breakdown.',
      dataClassification: EvidenceDataClassification.internalOperationalData,
      contribution: 50,
    );
    final evaluation = RecommendationRuleEvaluation(
      input: input,
      actions: [action],
      evidence: [evidence],
      score: 50,
      confidenceDetails: confidence,
    );
    final result = const RecommendationGenerator().generate(
      recommendationId: ' recommendation-1 ',
      createdAt: DateTime(2026, 8, 28, 10),
      evaluation: evaluation,
    )!;
    expect(result.id, 'recommendation-1');
    expect(result.incidentId, input.incidentId);
    expect(result.vehicleId, input.vehicleId);
    expect(result.routeId, input.routeId);
    expect(identical(result.actions.single, action), isTrue);
    expect(identical(result.evidence.single, evidence), isTrue);
    expect(identical(result.confidenceDetails, confidence), isTrue);
    expect(result.score, 50);
    expect(result.status, RecommendationStatus.pendingReview);
    expect(result.createdAt.isUtc, isTrue);
  });

  test('returns null for no recommendation and rejects blank ID', () {
    final none = RecommendationRuleEvaluation(
      input: input,
      actions: const [],
      evidence: const [],
      score: 0,
      confidenceDetails: confidence,
    );
    expect(
      const RecommendationGenerator().generate(
        recommendationId: 'recommendation-1',
        createdAt: DateTime.utc(2026, 8, 28),
        evaluation: none,
      ),
      isNull,
    );
    expect(
      () => const RecommendationGenerator().generate(
        recommendationId: ' ',
        createdAt: DateTime.utc(2026, 8, 28),
        evaluation: none,
      ),
      throwsArgumentError,
    );
  });

  test('generates the complete B1023 peak recommendation', () {
    final evaluation = engine.evaluate(
      ruleInput(
        condition: VehicleCondition.breakdownConfirmed,
        period: OperatingPeriod.peak,
      ),
    );
    final result = const RecommendationGenerator().generate(
      recommendationId: 'recommendation-b1023-route-300',
      createdAt: DateTime(2026, 8, 28, 8),
      evaluation: evaluation,
    )!;
    expect(result.actions[0], isA<InspectOrRepairVehicleAction>());
    expect(
      (result.actions[0] as InspectOrRepairVehicleAction).vehicleId,
      'B1023',
    );
    final deploy = result.actions[1] as DeployReplacementBusesAction;
    expect(deploy.routeId, '300');
    expect(deploy.busCount, 2);
    expect(result.score, 85);
    expect(result.confidenceDetails.baseConfidence, 1.0);
    expect(result.confidenceDetails.penalties, hasLength(1));
    expect(result.confidenceDetails.penalties.single.amount, 0.15);
    expect(result.confidence, 0.85);
    expect(result.status, RecommendationStatus.pendingReview);
    expect(
      result.evidence.map((item) => item.dataClassification),
      everyElement(EvidenceDataClassification.demonstrationData),
    );
  });

  test('generates inspect only for a confirmed off-peak breakdown', () {
    final evaluation = engine.evaluate(
      ruleInput(
        condition: VehicleCondition.breakdownConfirmed,
        period: OperatingPeriod.offPeak,
      ),
    );
    final result = const RecommendationGenerator().generate(
      recommendationId: 'recommendation-off-peak',
      createdAt: DateTime.utc(2026, 8, 28),
      evaluation: evaluation,
    )!;
    expect(result.actions, hasLength(1));
    expect(result.actions.single, isA<InspectOrRepairVehicleAction>());
    expect(result.actions.whereType<DeployReplacementBusesAction>(), isEmpty);
    expect(result.score, 50);
  });

  test('returns null for operational and unknown vehicle conditions', () {
    for (final condition in [
      VehicleCondition.operational,
      VehicleCondition.unknown,
    ]) {
      final evaluation = engine.evaluate(
        ruleInput(condition: condition, period: OperatingPeriod.peak),
      );
      expect(evaluation.hasRecommendation, isFalse);
      expect(
        const RecommendationGenerator().generate(
          recommendationId: 'recommendation-none',
          createdAt: DateTime.utc(2026, 8, 28),
          evaluation: evaluation,
        ),
        isNull,
      );
    }
  });

  test('preserves supplied classifications without unsupported claims', () {
    final evaluation = engine.evaluate(
      ruleInput(
        condition: VehicleCondition.breakdownConfirmed,
        period: OperatingPeriod.peak,
        vehicleClass: EvidenceDataClassification.staticGovernmentData,
        periodClass: EvidenceDataClassification.demonstrationData,
      ),
    );
    expect(evaluation.evidence.map((item) => item.dataClassification), [
      EvidenceDataClassification.staticGovernmentData,
      EvidenceDataClassification.demonstrationData,
    ]);
    final text = evaluation.evidence
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
}
