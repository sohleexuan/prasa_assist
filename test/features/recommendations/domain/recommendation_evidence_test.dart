import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';

void main() {
  test('labels evidence with its approved data classification', () {
    final evidence = RecommendationEvidence(
      ruleId: 'vehicle-breakdown-peak-hour',
      description: 'Bus B1023 broke down on Route 300 during peak hour.',
      dataClassification: EvidenceDataClassification.demonstrationData,
      contribution: 40,
    );

    expect(evidence.ruleId, 'vehicle-breakdown-peak-hour');
    expect(
      evidence.dataClassification,
      EvidenceDataClassification.demonstrationData,
    );
    expect(evidence.contribution, 40);
  });
  test('supports all approved evidence data classifications', () {
    expect(EvidenceDataClassification.values, [
      EvidenceDataClassification.liveGovernmentData,
      EvidenceDataClassification.staticGovernmentData,
      EvidenceDataClassification.cachedData,
      EvidenceDataClassification.internalOperationalData,
      EvidenceDataClassification.demonstrationData,
    ]);
  });
}
