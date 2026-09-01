import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/data/sources/supabase_recommendation_remote_data_source.dart';
import 'package:prasa_assist/features/recommendations/repositories/recommendation_data_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseRecommendationRemoteDataSource', () {
    test('analysis request and refresh keep the exact remote ID', () async {
      final gateway = _Gateway()..row = _row(withAnalysis: true);
      final source = SupabaseRecommendationRemoteDataSource.withGateway(
        gateway,
      );

      final result = await source.generateAnalysis('  $_recommendationId  ');

      expect(gateway.analysisIds, [_recommendationId]);
      expect(gateway.fetchIds, [_recommendationId]);
      expect(result.recommendation.id, _recommendationId);
      expect(result.analysis?.summary, 'Inspect B1023.');
    });

    final functionFailures = <String, Matcher>{
      'NOT_FOUND': isA<RecommendationNotFoundException>(),
      'AUTH_REQUIRED': isA<RecommendationPermissionException>(),
      'PROVIDER_UNAVAILABLE': isA<RecommendationProviderException>(),
      'INVALID_MODEL_RESPONSE': isA<RecommendationProviderException>(),
      'INVALID_REQUEST': isA<RecommendationValidationException>(),
      'PERSISTENCE_ERROR': isA<RecommendationServerException>(),
    };
    for (final entry in functionFailures.entries) {
      test(
        'maps Edge Function ${entry.key} without connection wording',
        () async {
          final gateway = _Gateway()
            ..error = FunctionsHttpException(
              status: entry.key == 'NOT_FOUND' ? 404 : 500,
              details: {
                'error': {'code': entry.key, 'message': 'unsafe server detail'},
              },
            );
          final source = SupabaseRecommendationRemoteDataSource.withGateway(
            gateway,
          );

          await expectLater(
            source.generateAnalysis(_recommendationId),
            throwsA(entry.value),
          );
        },
      );
    }

    test('maps function transport failure to connectivity only', () async {
      final gateway = _Gateway()
        ..error = const FunctionsFetchException(details: 'unsafe transport');
      final source = SupabaseRecommendationRemoteDataSource.withGateway(
        gateway,
      );

      await expectLater(
        source.generateAnalysis(_recommendationId),
        throwsA(
          isA<RecommendationOfflineException>().having(
            (error) => error.safeMessage,
            'message',
            contains('connection'),
          ),
        ),
      );
    });

    test('maps recommendation query failures to server, not offline', () async {
      final gateway = _Gateway()
        ..error = const PostgrestException(message: 'unsafe', code: '42703');
      final source = SupabaseRecommendationRemoteDataSource.withGateway(
        gateway,
      );

      await expectLater(
        source.fetchById(_recommendationId),
        throwsA(
          isA<RecommendationServerException>().having(
            (error) => error.safeMessage,
            'message',
            isNot(contains('connection')),
          ),
        ),
      );
    });
  });
}

class _Gateway implements RecommendationSupabaseGateway {
  Object? row;
  Object? error;
  final analysisIds = <String>[];
  final fetchIds = <String>[];

  @override
  Future<Object?> fetchAllRecommendationRows() async => [row ?? _row()];

  @override
  Future<Object?> fetchRecommendationRow(String id) async {
    fetchIds.add(id);
    if (error case final value?) throw value;
    return row;
  }

  @override
  Future<Object?> insertRecommendationRow(Map<String, Object?> values) async =>
      row;

  @override
  Future<void> decideRecommendation(Map<String, Object?> params) async {}

  @override
  Future<void> invokeAnalysis(String recommendationId) async {
    analysisIds.add(recommendationId);
    if (error case final value?) throw value;
  }
}

Map<String, Object?> _row({bool withAnalysis = false}) => {
  'id': _recommendationId,
  'owner_user_id': 'e1a376c2-b7f7-4ad3-970c-8b10534a2d07',
  'incident_id': 'INC-1',
  'vehicle_id': 'B1023',
  'route_id': '300',
  'actions_snapshot': [
    {'type': 'inspect_or_repair_vehicle', 'vehicleId': 'B1023'},
  ],
  'evidence_snapshot': [
    {
      'ruleId': 'breakdown',
      'description': 'Confirmed.',
      'dataClassification': 'internalOperationalData',
      'contribution': 50,
    },
  ],
  'score': 50,
  'confidence_details': {
    'factors': [
      {
        'factorId': 'breakdown',
        'description': 'Confirmed.',
        'weight': 1.0,
        'isSupported': true,
      },
    ],
    'penalties': <Object?>[],
  },
  'status': 'accepted',
  'decision_user_id': 'e1a376c2-b7f7-4ad3-970c-8b10534a2d07',
  'decision_at': '2026-08-31T00:00:00Z',
  'decision_note': null,
  'version': 2,
  'created_at': '2026-08-30T00:00:00Z',
  'updated_at': '2026-08-31T00:00:00Z',
  'recommendation_analyses': withAnalysis
      ? [
          {
            'model_identifier': 'openai/gpt-oss-20b',
            'schema_version': 1,
            'summary': 'Inspect B1023.',
            'rationale': ['Confirmed breakdown.'],
            'limitations': ['Staff review required.'],
            'staff_review_checklist': ['Review evidence.'],
            'generated_at': '2026-08-31T00:01:00Z',
          },
        ]
      : <Object?>[],
};

const _recommendationId = '460d90f1-d4f1-451f-ac69-761dc972b652';
