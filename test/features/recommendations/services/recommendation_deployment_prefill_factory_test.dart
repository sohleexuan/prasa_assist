import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/data/dto/recommendation_record_dto.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_status.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation.dart';
import 'package:prasa_assist/features/recommendations/services/recommendation_deployment_prefill_factory.dart';

void main() {
  test(
    'creates an accepted replacement-bus deployment prefill with linkage',
    () {
      final prefill = const RecommendationDeploymentPrefillFactory().create(
        RecommendationRecordDto(recommendation: _accepted()),
      );

      expect(prefill.incidentId, 'INC-1');
      expect(prefill.recommendationId, 'REC-1');
      expect(prefill.routeId, '300');
      expect(prefill.suggestedVehicleCount, 2);
      expect(prefill.suggestedStartTime, isNull);
      expect(prefill.suggestedEndTime, isNull);
    },
  );

  test('rejects a pending replacement-bus recommendation', () {
    expect(
      () => const RecommendationDeploymentPrefillFactory().create(
        RecommendationRecordDto(recommendation: _pending()),
      ),
      throwsStateError,
    );
  });
}

OperationsRecommendation _accepted() {
  final pending = _pending();
  return pending.decide(
    status: RecommendationStatus.accepted,
    decisionUserId: '11111111-1111-4111-8111-111111111111',
    decidedAt: DateTime.utc(2026, 8, 30, 1),
    remoteVersion: 2,
  );
}

OperationsRecommendation _pending() => OperationsRecommendation(
  id: 'REC-1',
  incidentId: 'INC-1',
  vehicleId: 'B1023',
  routeId: '300',
  actions: [
    InspectOrRepairVehicleAction(vehicleId: 'B1023'),
    DeployReplacementBusesAction(routeId: '300', busCount: 2),
  ],
  evidence: [
    RecommendationEvidence(
      ruleId: 'breakdown',
      description: 'Confirmed.',
      dataClassification: EvidenceDataClassification.internalOperationalData,
      contribution: 50,
    ),
  ],
  status: RecommendationStatus.pendingReview,
  score: 85,
  confidenceDetails: RecommendationConfidence(
    factors: [
      RecommendationConfidenceFactor(
        factorId: 'breakdown',
        description: 'Confirmed.',
        weight: 1,
        isSupported: true,
      ),
    ],
    penalties: const [],
  ),
  createdAt: DateTime.utc(2026, 8, 30),
);
