import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_status.dart';

void main() {
  RecommendationConfidence buildConfidence({double penalty = 0.15}) =>
      RecommendationConfidence(
        factors: [
          RecommendationConfidenceFactor(
            factorId: 'vehicle-condition',
            description: 'Known.',
            weight: 1,
            isSupported: true,
          ),
        ],
        penalties: penalty == 0
            ? const []
            : [
                RecommendationConfidencePenalty(
                  penaltyId: 'demonstration-evidence',
                  description: 'Demonstration evidence.',
                  amount: penalty,
                ),
              ],
      );

  OperationsRecommendation buildRecommendation({
    List<RecommendationAction>? actions,
    List<RecommendationEvidence>? evidence,
    int score = 85,
    RecommendationConfidence? confidenceDetails,
  }) {
    return OperationsRecommendation(
      id: 'recommendation-b1023-route-300',
      incidentId: 'incident-b1023-breakdown',
      vehicleId: 'B1023',
      routeId: '300',
      actions:
          actions ??
          [
            InspectOrRepairVehicleAction(vehicleId: 'B1023'),
            DeployReplacementBusesAction(routeId: '300', busCount: 2),
          ],
      evidence:
          evidence ??
          [
            RecommendationEvidence(
              ruleId: 'vehicle-breakdown-peak-hour',
              description:
                  'Bus B1023 broke down on Route 300 during peak hour.',
              dataClassification: EvidenceDataClassification.demonstrationData,
              contribution: 40,
            ),
          ],
      status: RecommendationStatus.pendingReview,
      score: score,
      confidenceDetails: confidenceDetails ?? buildConfidence(),
      createdAt: DateTime.utc(2026, 8, 27, 10),
    );
  }

  test('represents the complete B1023 Route 300 recommendation', () {
    final createdAt = DateTime.utc(2026, 8, 27, 10);
    final actions = <RecommendationAction>[
      InspectOrRepairVehicleAction(vehicleId: 'B1023'),
      DeployReplacementBusesAction(routeId: '300', busCount: 2),
    ];

    final recommendation = OperationsRecommendation(
      id: 'recommendation-b1023-route-300',
      incidentId: 'incident-b1023-breakdown',
      vehicleId: 'B1023',
      routeId: '300',
      actions: actions,
      evidence: [
        RecommendationEvidence(
          ruleId: 'vehicle-breakdown-peak-hour',
          description: 'Bus B1023 broke down on Route 300 during peak hour.',
          dataClassification: EvidenceDataClassification.demonstrationData,
          contribution: 40,
        ),
      ],
      status: RecommendationStatus.pendingReview,
      score: 85,
      confidenceDetails: buildConfidence(),
      createdAt: createdAt,
    );

    expect(recommendation.vehicleId, 'B1023');
    expect(recommendation.routeId, '300');
    expect(recommendation.actions, hasLength(2));
    final inspectAction = recommendation.actions
        .whereType<InspectOrRepairVehicleAction>()
        .single;
    final deployAction = recommendation.actions
        .whereType<DeployReplacementBusesAction>()
        .single;
    expect(inspectAction.vehicleId, 'B1023');
    expect(deployAction.routeId, '300');
    expect(deployAction.busCount, 2);
    expect(recommendation.evidence, hasLength(1));
    expect(recommendation.status, RecommendationStatus.pendingReview);
    expect(recommendation.score, 85);
    expect(recommendation.confidence, 0.85);
    expect(recommendation.createdAt, createdAt);
  });
  test('requires at least one proposed action', () {
    expect(() => buildRecommendation(actions: []), throwsArgumentError);
  });
  test('score must be from 0 through 100 inclusive', () {
    expect(() => buildRecommendation(score: -1), throwsArgumentError);
    expect(() => buildRecommendation(score: 101), throwsArgumentError);
    expect(() => buildRecommendation(score: 0), returnsNormally);
    expect(() => buildRecommendation(score: 100), returnsNormally);
  });
  test('confidence getter has confidenceDetails as its only stored source', () {
    final details = buildConfidence();
    final recommendation = buildRecommendation(confidenceDetails: details);

    expect(identical(recommendation.confidenceDetails, details), isTrue);
    expect(
      recommendation.confidence,
      recommendation.confidenceDetails.finalConfidence,
    );
    expect(recommendation.confidence, 0.85);
  });
  test('normalizes createdAt to UTC', () {
    final recommendation = OperationsRecommendation(
      id: 'recommendation-1',
      incidentId: 'incident-1',
      vehicleId: 'B1023',
      routeId: '300',
      actions: [InspectOrRepairVehicleAction(vehicleId: 'B1023')],
      evidence: [
        RecommendationEvidence(
          ruleId: 'breakdown',
          description: 'Confirmed breakdown.',
          dataClassification: EvidenceDataClassification.demonstrationData,
          contribution: 50,
        ),
      ],
      status: RecommendationStatus.pendingReview,
      score: 50,
      confidenceDetails: buildConfidence(),
      createdAt: DateTime(2026, 8, 28, 10),
    );

    expect(recommendation.createdAt.isUtc, isTrue);
  });
  test('requires at least one evidence item', () {
    expect(() => buildRecommendation(evidence: []), throwsArgumentError);
  });
  test('exposes actions as an unmodifiable defensive copy', () {
    final actions = <RecommendationAction>[
      InspectOrRepairVehicleAction(vehicleId: 'B1023'),
      DeployReplacementBusesAction(routeId: '300', busCount: 2),
    ];
    final recommendation = buildRecommendation(actions: actions);

    expect(
      () => recommendation.actions.add(
        InspectOrRepairVehicleAction(vehicleId: 'B1023'),
      ),
      throwsUnsupportedError,
    );

    actions.clear();
    expect(recommendation.actions, hasLength(2));
  });
  test('exposes evidence as an unmodifiable defensive copy', () {
    final evidence = <RecommendationEvidence>[
      RecommendationEvidence(
        ruleId: 'vehicle-breakdown-peak-hour',
        description: 'Bus B1023 broke down on Route 300 during peak hour.',
        dataClassification: EvidenceDataClassification.demonstrationData,
        contribution: 40,
      ),
    ];
    final recommendation = buildRecommendation(evidence: evidence);

    expect(
      () => recommendation.evidence.add(
        RecommendationEvidence(
          ruleId: 'route-300-service-impact',
          description: 'Route 300 requires operational staff review.',
          dataClassification: EvidenceDataClassification.demonstrationData,
          contribution: 20,
        ),
      ),
      throwsUnsupportedError,
    );

    evidence.clear();
    expect(recommendation.evidence, hasLength(1));
  });

  test('records a UTC staff decision without changing deterministic facts', () {
    final pending = buildRecommendation();
    final decided = pending.decide(
      status: RecommendationStatus.accepted,
      decisionUserId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      decidedAt: DateTime(2026, 8, 29, 11),
      remoteVersion: 2,
    );

    expect(decided.status, RecommendationStatus.accepted);
    expect(decided.decisionAt!.isUtc, isTrue);
    expect(decided.remoteVersion, 2);
    expect(identical(decided.actions, pending.actions), isTrue);
    expect(identical(decided.evidence, pending.evidence), isTrue);
    expect(
      identical(decided.confidenceDetails, pending.confidenceDetails),
      isTrue,
    );
    expect(
      () => decided.decide(
        status: RecommendationStatus.rejected,
        decisionUserId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        decidedAt: DateTime.utc(2026, 8, 29),
        remoteVersion: 3,
      ),
      throwsStateError,
    );
  });
}
