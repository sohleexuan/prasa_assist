import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';

void main() {
  final vehicle = RecommendationConfidenceFactor(
    factorId: 'vehicle-condition',
    description: 'Vehicle condition known.',
    weight: 0.60,
    isSupported: true,
  );
  final period = RecommendationConfidenceFactor(
    factorId: 'operating-period',
    description: 'Operating period known.',
    weight: 0.40,
    isSupported: true,
  );
  final demo = RecommendationConfidencePenalty(
    penaltyId: 'demonstration-evidence',
    description: 'Demonstration evidence limits confidence.',
    amount: 0.15,
  );

  test('calculates and preserves the complete confidence explanation', () {
    final factors = [vehicle, period];
    final penalties = [demo];
    final result = RecommendationConfidence(
      factors: factors,
      penalties: penalties,
    );
    expect(result.baseConfidence, 1.0);
    expect(result.finalConfidence, 0.85);
    expect(() => result.factors.clear(), throwsUnsupportedError);
    expect(() => result.penalties.clear(), throwsUnsupportedError);
    factors.clear();
    penalties.clear();
    expect(result.factors, hasLength(2));
    expect(result.penalties, hasLength(1));
  });

  test('requires unique factor and penalty IDs', () {
    expect(
      () => RecommendationConfidence(
        factors: [vehicle, vehicle],
        penalties: const [],
      ),
      throwsArgumentError,
    );
    expect(
      () =>
          RecommendationConfidence(factors: [vehicle], penalties: [demo, demo]),
      throwsArgumentError,
    );
  });

  test('validates labels, weights, amounts, and total weight', () {
    expect(
      () => RecommendationConfidenceFactor(
        factorId: ' ',
        description: 'Known.',
        weight: .5,
        isSupported: true,
      ),
      throwsArgumentError,
    );
    expect(
      () => RecommendationConfidenceFactor(
        factorId: 'x',
        description: 'Known.',
        weight: double.nan,
        isSupported: true,
      ),
      throwsArgumentError,
    );
    expect(
      () => RecommendationConfidencePenalty(
        penaltyId: 'x',
        description: ' ',
        amount: .1,
      ),
      throwsArgumentError,
    );
    expect(
      () => RecommendationConfidencePenalty(
        penaltyId: 'x',
        description: 'Penalty.',
        amount: 1.1,
      ),
      throwsArgumentError,
    );
    expect(
      () => RecommendationConfidence(
        factors: [
          RecommendationConfidenceFactor(
            factorId: 'x',
            description: 'Known.',
            weight: 0,
            isSupported: false,
          ),
        ],
        penalties: const [],
      ),
      throwsArgumentError,
    );
  });
}
