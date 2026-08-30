import '../domain/recommendation_confidence.dart';
import '../domain/recommendation_evidence.dart';
import '../domain/recommendation_rule_input.dart';
import '../domain/recommendation_rule_policy.dart';

class ExplainableConfidenceScorer {
  const ExplainableConfidenceScorer();

  RecommendationConfidence score({
    required RecommendationRuleInput input,
    required RecommendationRulePolicy policy,
  }) {
    final hasDemonstrationEvidence =
        input.vehicleConditionDataClassification ==
            EvidenceDataClassification.demonstrationData ||
        input.operatingPeriodDataClassification ==
            EvidenceDataClassification.demonstrationData;
    return RecommendationConfidence(
      factors: [
        RecommendationConfidenceFactor(
          factorId: 'vehicle-condition',
          description: 'Vehicle condition is supplied as a normalized fact.',
          weight: policy.breakdownConfidenceWeight,
          isSupported: input.vehicleCondition != VehicleCondition.unknown,
        ),
        RecommendationConfidenceFactor(
          factorId: 'operating-period',
          description: 'Operating period is supplied as a normalized fact.',
          weight: policy.operatingPeriodConfidenceWeight,
          isSupported: input.operatingPeriod != OperatingPeriod.unknown,
        ),
      ],
      penalties: hasDemonstrationEvidence
          ? [
              RecommendationConfidencePenalty(
                penaltyId: 'demonstration-evidence',
                description: 'Demonstration evidence limits confidence.',
                amount: policy.demonstrationEvidencePenalty,
              ),
            ]
          : const [],
    );
  }
}
