import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/recommendation_data_exception.dart';
import '../recommendation_serialization.dart';
import '../dto/recommendation_record_dto.dart';
import 'recommendation_remote_data_source.dart';

class SupabaseRecommendationRemoteDataSource
    implements RecommendationRemoteDataSource {
  const SupabaseRecommendationRemoteDataSource(this._client);
  final SupabaseClient _client;
  static const _selection = '*, recommendation_analyses(*)';

  @override
  Future<List<RecommendationRecordDto>> fetchAll() => _guard(() async {
    final rows = await _client
        .from('recommendations')
        .select(_selection)
        .order('updated_at', ascending: false);
    return List.unmodifiable(rows.map(RecommendationRecordDto.fromMap));
  });

  @override
  Future<RecommendationRecordDto?> fetchById(String id) => _guard(() async {
    final row = await _client
        .from('recommendations')
        .select(_selection)
        .eq('id', id.trim())
        .maybeSingle();
    return row == null ? null : RecommendationRecordDto.fromMap(row);
  });

  @override
  Future<RecommendationRecordDto> createPending(
    RecommendationRecordDto record,
  ) => _guard(() async {
    final existing = await fetchById(record.recommendation.id);
    if (existing != null) return existing;
    final recommendation = record.recommendation;
    try {
      final row = await _client
          .from('recommendations')
          .insert({
            'id': recommendation.id,
            'owner_user_id': recommendation.ownerUserId,
            'incident_id': recommendation.incidentId,
            'vehicle_id': recommendation.vehicleId,
            'route_id': recommendation.routeId,
            'actions_snapshot': RecommendationSerialization.encodeActions(
              recommendation.actions,
            ),
            'evidence_snapshot': RecommendationSerialization.encodeEvidence(
              recommendation.evidence,
            ),
            'score': recommendation.score,
            'confidence_details': RecommendationSerialization.encodeConfidence(
              recommendation.confidenceDetails,
            ),
            'status': 'pending_review',
            'created_at': recommendation.createdAt.toIso8601String(),
            'updated_at': recommendation.updatedAt.toIso8601String(),
          })
          .select(_selection)
          .single();
      return RecommendationRecordDto.fromMap(row);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final reused = await fetchById(recommendation.id);
      if (reused != null) return reused;
      rethrow;
    }
  });

  @override
  Future<RecommendationRecordDto> decide(
    String id, {
    required String decision,
    String? note,
    required int expectedVersion,
  }) => _guard(() async {
    await _client.rpc(
      'decide_recommendation',
      params: {
        'p_recommendation_id': id.trim(),
        'p_decision': decision,
        'p_note': note?.trim(),
        'p_expected_version': expectedVersion,
      },
    );
    final updated = await fetchById(id);
    if (updated == null) {
      throw const RecommendationValidationException(
        'The recommendation was not found after the decision.',
      );
    }
    return updated;
  });

  @override
  Future<RecommendationRecordDto> generateAnalysis(
    String id,
  ) => _guard(() async {
    final response = await _client.functions.invoke(
      'generate-recommendation-analysis',
      body: {'recommendationId': id.trim()},
    );
    if (response.status < 200 || response.status >= 300) {
      throw const RecommendationValidationException(
        'AI analysis is unavailable. Try again when connectivity is restored.',
      );
    }
    final updated = await fetchById(id);
    if (updated?.analysis == null) {
      throw const RecommendationValidationException(
        'AI analysis could not be loaded after saving.',
      );
    }
    return updated!;
  });

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on RecommendationDataException {
      rethrow;
    } on PostgrestException catch (error) {
      if (error.code == '40001') {
        throw RecommendationConflictException(
          'This recommendation changed elsewhere. Refresh and try again.',
          cause: error,
        );
      }
      throw RecommendationValidationException(
        'Unable to complete the recommendation operation.',
        cause: error,
      );
    } on TimeoutException catch (error) {
      throw RecommendationOfflineException(
        'Recommendation data is unavailable. Check the connection.',
        cause: error,
      );
    } catch (error) {
      throw RecommendationOfflineException(
        'Recommendation data is unavailable. Check the connection.',
        cause: error,
      );
    }
  }
}
