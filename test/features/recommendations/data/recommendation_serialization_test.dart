import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/data/recommendation_serialization.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';

void main() {
  test(
    'round trips deterministic snapshots without allowing analysis changes',
    () {
      final actions = <RecommendationAction>[
        InspectOrRepairVehicleAction(vehicleId: 'B1023'),
        DeployReplacementBusesAction(routeId: '300', busCount: 2),
      ];
      final evidence = <RecommendationEvidence>[
        RecommendationEvidence(
          ruleId: 'confirmed-breakdown',
          description: 'Confirmed breakdown contributes 50.',
          dataClassification: EvidenceDataClassification.demonstrationData,
          contribution: 50,
        ),
      ];
      final confidence = RecommendationConfidence(
        factors: [
          RecommendationConfidenceFactor(
            factorId: 'breakdown',
            description: 'Confirmed.',
            weight: .6,
            isSupported: true,
          ),
          RecommendationConfidenceFactor(
            factorId: 'period',
            description: 'Peak.',
            weight: .4,
            isSupported: true,
          ),
        ],
        penalties: [
          RecommendationConfidencePenalty(
            penaltyId: 'demo',
            description: 'Demonstration evidence.',
            amount: .15,
          ),
        ],
      );

      final decodedActions = RecommendationSerialization.decodeActions(
        jsonEncode(RecommendationSerialization.encodeActions(actions)),
      );
      final decodedEvidence = RecommendationSerialization.decodeEvidence(
        jsonEncode(RecommendationSerialization.encodeEvidence(evidence)),
      );
      final decodedConfidence = RecommendationSerialization.decodeConfidence(
        jsonEncode(RecommendationSerialization.encodeConfidence(confidence)),
      );

      expect(
        decodedActions
            .whereType<DeployReplacementBusesAction>()
            .single
            .busCount,
        2,
      );
      expect(decodedEvidence.single.contribution, 50);
      expect(decodedConfidence.finalConfidence, closeTo(.85, .0001));
    },
  );

  test('rejects unknown deterministic action shapes', () {
    expect(
      () => RecommendationSerialization.decodeActions(
        '[{"type":"change_score","score":100}]',
      ),
      throwsFormatException,
    );
  });
}
