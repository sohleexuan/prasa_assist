import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_input.dart';

void main() {
  test('stores normalized facts, classifications, and UTC evaluation time', () {
    final input = RecommendationRuleInput(
      incidentId: ' incident-1 ',
      vehicleId: ' B1023 ',
      routeId: ' 300 ',
      vehicleCondition: VehicleCondition.breakdownConfirmed,
      operatingPeriod: OperatingPeriod.peak,
      vehicleConditionDataClassification:
          EvidenceDataClassification.demonstrationData,
      operatingPeriodDataClassification:
          EvidenceDataClassification.staticGovernmentData,
      evaluatedAt: DateTime(2026, 8, 28, 10),
    );

    expect(input.incidentId, 'incident-1');
    expect(input.vehicleId, 'B1023');
    expect(input.routeId, '300');
    expect(input.vehicleCondition, VehicleCondition.breakdownConfirmed);
    expect(input.operatingPeriod, OperatingPeriod.peak);
    expect(
      input.vehicleConditionDataClassification,
      EvidenceDataClassification.demonstrationData,
    );
    expect(
      input.operatingPeriodDataClassification,
      EvidenceDataClassification.staticGovernmentData,
    );
    expect(input.evaluatedAt.isUtc, isTrue);
  });

  test('rejects blank identifiers', () {
    RecommendationRuleInput build({
      String incidentId = 'incident-1',
      String vehicleId = 'B1023',
      String routeId = '300',
    }) => RecommendationRuleInput(
      incidentId: incidentId,
      vehicleId: vehicleId,
      routeId: routeId,
      vehicleCondition: VehicleCondition.unknown,
      operatingPeriod: OperatingPeriod.unknown,
      vehicleConditionDataClassification:
          EvidenceDataClassification.internalOperationalData,
      operatingPeriodDataClassification:
          EvidenceDataClassification.internalOperationalData,
      evaluatedAt: DateTime.utc(2026, 8, 28),
    );

    expect(() => build(incidentId: ' '), throwsArgumentError);
    expect(() => build(vehicleId: ''), throwsArgumentError);
    expect(() => build(routeId: '\t'), throwsArgumentError);
  });
}
