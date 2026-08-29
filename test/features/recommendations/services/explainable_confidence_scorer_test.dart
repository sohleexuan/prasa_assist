import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_input.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_policy.dart';
import 'package:prasa_assist/features/recommendations/services/explainable_confidence_scorer.dart';

void main() {
  RecommendationRuleInput input({
    VehicleCondition condition = VehicleCondition.breakdownConfirmed,
    OperatingPeriod period = OperatingPeriod.peak,
    EvidenceDataClassification vehicleClass =
        EvidenceDataClassification.demonstrationData,
    EvidenceDataClassification periodClass =
        EvidenceDataClassification.demonstrationData,
  }) => RecommendationRuleInput(
    incidentId: 'incident-1',
    vehicleId: 'B1023',
    routeId: '300',
    vehicleCondition: condition,
    operatingPeriod: period,
    vehicleConditionDataClassification: vehicleClass,
    operatingPeriodDataClassification: periodClass,
    evaluatedAt: DateTime.utc(2026, 8, 28),
  );

  test('calculates both factors and one demonstration penalty', () {
    final result = const ExplainableConfidenceScorer().score(
      input: input(),
      policy: RecommendationRulePolicy.ownerApproved(),
    );
    expect(result.baseConfidence, 1.0);
    expect(result.finalConfidence, 0.85);
    expect(result.factors.map((item) => item.factorId), [
      'vehicle-condition',
      'operating-period',
    ]);
    expect(result.penalties.single.penaltyId, 'demonstration-evidence');
    expect(result.penalties.single.amount, 0.15);
  });

  test('unknown period leaves only vehicle weight supported', () {
    final result = const ExplainableConfidenceScorer().score(
      input: input(
        period: OperatingPeriod.unknown,
        vehicleClass: EvidenceDataClassification.staticGovernmentData,
        periodClass: EvidenceDataClassification.cachedData,
      ),
      policy: RecommendationRulePolicy.ownerApproved(),
    );
    expect(result.baseConfidence, 0.60);
    expect(result.penalties, isEmpty);
    expect(
      input(vehicleClass: EvidenceDataClassification.staticGovernmentData)
          .vehicleConditionDataClassification,
      EvidenceDataClassification.staticGovernmentData,
    );
  });
}
