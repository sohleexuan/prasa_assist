import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_evaluation.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_input.dart';

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

  RecommendationRuleEvaluation buildEvaluation({
    required List<RecommendationAction> actions,
    required List<RecommendationEvidence> evidence,
    required int score,
  }) => RecommendationRuleEvaluation(
    input: input,
    actions: actions,
    evidence: evidence,
    score: score,
    confidenceDetails: confidence,
  );

  RecommendationEvidence evidence({
    String ruleId = 'breakdown',
    String description = 'Confirmed breakdown.',
    int contribution = 50,
  }) => RecommendationEvidence(
    ruleId: ruleId,
    description: description,
    dataClassification: EvidenceDataClassification.internalOperationalData,
    contribution: contribution,
  );

  test('defensively stores a valid recommendation evaluation', () {
    final actions = <RecommendationAction>[
      InspectOrRepairVehicleAction(vehicleId: 'B1023'),
    ];
    final evidence = [
      RecommendationEvidence(
        ruleId: 'breakdown',
        description: 'Confirmed breakdown.',
        dataClassification: EvidenceDataClassification.internalOperationalData,
        contribution: 50,
      ),
    ];
    final result = RecommendationRuleEvaluation(
      input: input,
      actions: actions,
      evidence: evidence,
      score: 50,
      confidenceDetails: confidence,
    );
    actions.clear();
    evidence.clear();
    expect(result.hasRecommendation, isTrue);
    expect(result.actions, hasLength(1));
    expect(result.evidence, hasLength(1));
    expect(() => result.actions.clear(), throwsUnsupportedError);
  });

  test('allows explicit no recommendation and rejects mixed states', () {
    final none = RecommendationRuleEvaluation(
      input: input,
      actions: const [],
      evidence: const [],
      score: 0,
      confidenceDetails: confidence,
    );
    expect(none.hasRecommendation, isFalse);
    expect(
      () => RecommendationRuleEvaluation(
        input: input,
        actions: const [],
        evidence: const [],
        score: 1,
        confidenceDetails: confidence,
      ),
      throwsArgumentError,
    );
    expect(
      () => RecommendationRuleEvaluation(
        input: input,
        actions: [InspectOrRepairVehicleAction(vehicleId: 'B1023')],
        evidence: const [],
        score: 50,
        confidenceDetails: confidence,
      ),
      throwsArgumentError,
    );
    expect(
      () => RecommendationRuleEvaluation(
        input: input,
        actions: [InspectOrRepairVehicleAction(vehicleId: 'B1023')],
        evidence: [
          RecommendationEvidence(
            ruleId: 'breakdown',
            description: 'Confirmed breakdown.',
            dataClassification:
                EvidenceDataClassification.internalOperationalData,
            contribution: 50,
          ),
        ],
        score: 49,
        confidenceDetails: confidence,
      ),
      throwsArgumentError,
    );
    expect(
      () => RecommendationRuleEvaluation(
        input: input,
        actions: const [],
        evidence: const [],
        score: 101,
        confidenceDetails: confidence,
      ),
      throwsArgumentError,
    );
  });

  test('rejects blank or input-mismatched action identifiers', () {
    expect(
      () => buildEvaluation(
        actions: [InspectOrRepairVehicleAction(vehicleId: ' ')],
        evidence: [evidence()],
        score: 50,
      ),
      throwsArgumentError,
    );
    expect(
      () => buildEvaluation(
        actions: [InspectOrRepairVehicleAction(vehicleId: 'B2048')],
        evidence: [evidence()],
        score: 50,
      ),
      throwsArgumentError,
    );
    expect(
      () => buildEvaluation(
        actions: [DeployReplacementBusesAction(routeId: ' ', busCount: 2)],
        evidence: [evidence()],
        score: 50,
      ),
      throwsArgumentError,
    );
    expect(
      () => buildEvaluation(
        actions: [DeployReplacementBusesAction(routeId: '301', busCount: 2)],
        evidence: [evidence()],
        score: 50,
      ),
      throwsArgumentError,
    );
  });

  test('rejects malformed evidence text and contributions', () {
    expect(
      () => buildEvaluation(
        actions: [InspectOrRepairVehicleAction(vehicleId: 'B1023')],
        evidence: [evidence(ruleId: ' ')],
        score: 50,
      ),
      throwsArgumentError,
    );
    expect(
      () => buildEvaluation(
        actions: [InspectOrRepairVehicleAction(vehicleId: 'B1023')],
        evidence: [evidence(description: '\t')],
        score: 50,
      ),
      throwsArgumentError,
    );
    expect(
      () => buildEvaluation(
        actions: [InspectOrRepairVehicleAction(vehicleId: 'B1023')],
        evidence: [evidence(contribution: -1)],
        score: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => buildEvaluation(
        actions: [InspectOrRepairVehicleAction(vehicleId: 'B1023')],
        evidence: [evidence(contribution: 101)],
        score: 100,
      ),
      throwsArgumentError,
    );
  });
}
