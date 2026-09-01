import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/data/dto/recommendation_record_dto.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_analysis.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_status.dart';
import 'package:prasa_assist/features/recommendations/services/recommendation_work_order_prefill_factory.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';

void main() {
  test('accepted breakdown creates high-priority create-mode prefill only', () {
    final pending = OperationsRecommendation(
      id: 'REC-1',
      incidentId: 'INC-1',
      vehicleId: 'B1023',
      routeId: '300',
      actions: [InspectOrRepairVehicleAction(vehicleId: 'B1023')],
      evidence: [
        RecommendationEvidence(
          ruleId: 'breakdown',
          description: 'Confirmed.',
          dataClassification:
              EvidenceDataClassification.internalOperationalData,
          contribution: 50,
        ),
      ],
      status: RecommendationStatus.pendingReview,
      score: 50,
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
      createdAt: DateTime.utc(2026, 8, 29),
    );
    expect(
      () => const RecommendationWorkOrderPrefillFactory().create(
        RecommendationRecordDto(recommendation: pending),
      ),
      throwsStateError,
    );
    final accepted = pending.decide(
      status: RecommendationStatus.accepted,
      decisionUserId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      decidedAt: DateTime.utc(2026, 8, 29, 1),
      remoteVersion: 2,
    );
    final prefill = const RecommendationWorkOrderPrefillFactory().create(
      RecommendationRecordDto(
        recommendation: accepted,
        analysis: RecommendationAnalysis(
          recommendationId: 'REC-1',
          modelIdentifier: 'gemini-2.5-flash',
          schemaVersion: 1,
          summary: 'Inspect B1023 before returning it to service.',
          rationale: ['The stored breakdown evidence supports inspection.'],
          limitations: ['Staff must verify the current vehicle condition.'],
          staffReviewChecklist: ['Review the stored evidence.'],
          generatedAt: DateTime.utc(2026, 8, 29, 1, 5),
        ),
      ),
    );
    expect(prefill.vehicleId, 'B1023');
    expect(prefill.incidentId, 'INC-1');
    expect(prefill.recommendationId, 'REC-1');
    expect(prefill.taskType, 'Vehicle inspection');
    expect(
      prefill.description,
      'Inspect B1023 following the confirmed breakdown recommendation.',
    );
    expect(prefill.priority, WorkOrderPriority.high);
    expect(
      prefill.notes,
      'AI-generated summary (review before saving): '
      'Inspect B1023 before returning it to service.',
    );
  });
}
