import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_analysis.dart';

void main() {
  test('parses the exact explanation contract and normalizes UTC', () {
    final analysis = RecommendationAnalysis.fromJson(
      {
        'summary': 'Inspect B1023 before it returns to service.',
        'rationale': ['A confirmed breakdown triggered inspection.'],
        'limitations': ['Demonstration evidence reduces confidence.'],
        'staffReviewChecklist': ['Confirm B1023 remains unavailable.'],
      },
      recommendationId: 'rec-1',
      generatedAt: DateTime(2026, 8, 29, 10),
      modelIdentifier: 'openai/gpt-oss-20b',
    );

    expect(analysis.modelIdentifier, 'openai/gpt-oss-20b');
    expect(analysis.schemaVersion, 1);
    expect(analysis.generatedAt.isUtc, isTrue);
    expect(() => analysis.rationale.add('Changed'), throwsUnsupportedError);
  });

  test('rejects extra keys, wrong shapes, blanks, and excessive lists', () {
    final valid = <String, Object?>{
      'summary': 'Review the deterministic recommendation.',
      'rationale': ['Confirmed breakdown.'],
      'limitations': ['Staff confirmation is required.'],
      'staffReviewChecklist': ['Review evidence.'],
    };
    for (final invalid in <Map<String, Object?>>[
      {...valid, 'score': 100},
      {...valid, 'rationale': 'not-a-list'},
      {...valid, 'summary': '   '},
      {...valid, 'limitations': List.filled(9, 'item')},
      {
        ...valid,
        'staffReviewChecklist': [''],
      },
    ]) {
      expect(
        () => RecommendationAnalysis.fromJson(
          invalid,
          recommendationId: 'rec-1',
          generatedAt: DateTime.utc(2026, 8, 29),
          modelIdentifier: 'openai/gpt-oss-20b',
        ),
        throwsFormatException,
      );
    }
  });

  test('rejects an unknown persisted analysis model identifier', () {
    expect(
      () => RecommendationAnalysis.fromJson(
        {
          'summary': 'Review the deterministic recommendation.',
          'rationale': ['Confirmed breakdown.'],
          'limitations': ['Staff confirmation is required.'],
          'staffReviewChecklist': ['Review evidence.'],
        },
        recommendationId: 'rec-1',
        generatedAt: DateTime.utc(2026, 8, 29),
        modelIdentifier: 'unknown/model',
      ),
      throwsFormatException,
    );
  });
}
