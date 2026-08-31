import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/recommendation_data_exception.dart';
import '../dto/recommendation_record_dto.dart';
import '../recommendation_serialization.dart';
import 'recommendation_remote_data_source.dart';

abstract interface class RecommendationSupabaseGateway {
  Future<Object?> fetchAllRecommendationRows();
  Future<Object?> fetchRecommendationRow(String id);
  Future<Object?> insertRecommendationRow(Map<String, Object?> values);
  Future<void> decideRecommendation(Map<String, Object?> params);
  Future<void> invokeAnalysis(String recommendationId);
}

class SupabaseRecommendationGateway implements RecommendationSupabaseGateway {
  SupabaseRecommendationGateway(this._client);

  static const selection = '*, recommendation_analyses(*)';
  final SupabaseClient _client;

  @override
  Future<Object?> fetchAllRecommendationRows() => _client
      .from('recommendations')
      .select(selection)
      .order('updated_at', ascending: false);

  @override
  Future<Object?> fetchRecommendationRow(String id) => _client
      .from('recommendations')
      .select(selection)
      .eq('id', id)
      .maybeSingle();

  @override
  Future<Object?> insertRecommendationRow(Map<String, Object?> values) =>
      _client.from('recommendations').insert(values).select(selection).single();

  @override
  Future<void> decideRecommendation(Map<String, Object?> params) async {
    await _client.rpc('decide_recommendation', params: params);
  }

  @override
  Future<void> invokeAnalysis(String recommendationId) async {
    await _client.functions.invoke(
      'generate-recommendation-analysis',
      body: {'recommendationId': recommendationId},
    );
  }
}

class SupabaseRecommendationRemoteDataSource
    implements RecommendationRemoteDataSource {
  SupabaseRecommendationRemoteDataSource(SupabaseClient client)
    : this.withGateway(SupabaseRecommendationGateway(client));

  SupabaseRecommendationRemoteDataSource.withGateway(this._gateway);

  final RecommendationSupabaseGateway _gateway;

  @override
  Future<List<RecommendationRecordDto>> fetchAll() async {
    final response = await _request(_gateway.fetchAllRecommendationRows);
    if (response is! List) {
      throw RecommendationMappingException(
        'Recommendation data returned an invalid list response.',
        cause: response,
      );
    }
    return List<RecommendationRecordDto>.unmodifiable(
      response.map(_recordFromResponse),
    );
  }

  @override
  Future<RecommendationRecordDto?> fetchById(String id) async {
    final response = await _request(
      () => _gateway.fetchRecommendationRow(id.trim()),
    );
    return response == null ? null : _recordFromResponse(response);
  }

  @override
  Future<RecommendationRecordDto> createPending(
    RecommendationRecordDto record,
  ) async {
    final recommendation = record.recommendation;
    final existing = await fetchById(recommendation.id);
    if (existing != null) return existing;
    try {
      final response = await _request(
        () => _gateway.insertRecommendationRow({
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
        }),
      );
      return _recordFromResponse(response);
    } on RecommendationConflictException {
      final reused = await fetchById(recommendation.id);
      if (reused != null) return reused;
      rethrow;
    }
  }

  @override
  Future<RecommendationRecordDto> decide(
    String id, {
    required String decision,
    String? note,
    required int expectedVersion,
  }) async {
    await _request(
      () => _gateway.decideRecommendation({
        'p_recommendation_id': id.trim(),
        'p_decision': decision,
        'p_note': note?.trim(),
        'p_expected_version': expectedVersion,
      }),
    );
    final updated = await fetchById(id);
    if (updated == null) {
      throw const RecommendationNotFoundException(
        'The recommendation was not found after the decision.',
      );
    }
    return updated;
  }

  @override
  Future<RecommendationRecordDto> generateAnalysis(String id) async {
    final normalizedId = id.trim();
    await _request(() => _gateway.invokeAnalysis(normalizedId));
    final updated = await fetchById(normalizedId);
    if (updated == null) {
      throw const RecommendationNotFoundException(
        'The recommendation was not found after analysis.',
      );
    }
    if (updated.analysis == null) {
      throw const RecommendationServerException(
        'AI analysis was saved but could not be loaded.',
      );
    }
    return updated;
  }

  RecommendationRecordDto _recordFromResponse(Object? response) {
    if (response is! Map) {
      throw RecommendationMappingException(
        'Recommendation data returned an invalid record response.',
        cause: response,
      );
    }
    try {
      return RecommendationRecordDto.fromMap(
        response.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on RecommendationDataException {
      rethrow;
    } catch (error) {
      throw RecommendationMappingException(
        'Recommendation data could not be mapped safely.',
        cause: error,
      );
    }
  }

  Future<T> _request<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on RecommendationDataException {
      rethrow;
    } on FunctionsHttpException catch (error) {
      throw _functionFailure(error);
    } on FunctionsFetchException catch (error) {
      throw RecommendationOfflineException(
        'Recommendation service is unreachable. Check the connection.',
        cause: error,
      );
    } on FunctionsRelayException catch (error) {
      throw RecommendationServerException(
        'Recommendation analysis could not reach the server function.',
        cause: error,
      );
    } on AuthException catch (error) {
      throw RecommendationPermissionException(
        'An authenticated staff session is required for recommendations.',
        cause: error,
      );
    } on PostgrestException catch (error) {
      throw _postgrestFailure(error);
    } on TimeoutException catch (error) {
      throw RecommendationOfflineException(
        'Recommendation service is unreachable. Check the connection.',
        cause: error,
      );
    } on SocketException catch (error) {
      throw RecommendationOfflineException(
        'Recommendation service is unreachable. Check the connection.',
        cause: error,
      );
    } catch (error) {
      throw RecommendationServerException(
        'Unable to complete the recommendation operation safely.',
        cause: error,
      );
    }
  }

  RecommendationDataException _functionFailure(FunctionsHttpException error) {
    final code = _functionCode(error.details);
    return switch (code) {
      'NOT_FOUND' => RecommendationNotFoundException(
        'The requested recommendation was not found or is not available to this staff account.',
        cause: error,
      ),
      'AUTH_REQUIRED' => RecommendationPermissionException(
        'Your staff session is no longer authorized. Sign in and try again.',
        cause: error,
      ),
      'PROVIDER_UNAVAILABLE' => RecommendationProviderException(
        'AI analysis is temporarily unavailable from the provider.',
        cause: error,
      ),
      'INVALID_MODEL_RESPONSE' => RecommendationProviderException(
        'AI analysis was rejected because the provider response was invalid.',
        cause: error,
      ),
      'INVALID_REQUEST' => RecommendationValidationException(
        'The analysis request failed server validation.',
        cause: error,
      ),
      'PERSISTENCE_ERROR' => RecommendationServerException(
        'The analysis service could not read or save recommendation data.',
        cause: error,
      ),
      _ when error.status == 401 || error.status == 403 =>
        RecommendationPermissionException(
          'Your staff session is not authorized for this analysis.',
          cause: error,
        ),
      _ when error.status == 404 => RecommendationNotFoundException(
        'The requested recommendation analysis was not found.',
        cause: error,
      ),
      _ when error.status == 400 || error.status == 422 =>
        RecommendationValidationException(
          'The analysis request failed server validation.',
          cause: error,
        ),
      _ => RecommendationServerException(
        'The recommendation analysis service failed safely.',
        cause: error,
      ),
    };
  }

  RecommendationDataException _postgrestFailure(PostgrestException error) =>
      switch (error.code) {
        'P0002' || 'PGRST116' => RecommendationNotFoundException(
          'The requested recommendation was not found.',
          cause: error,
        ),
        '40001' => RecommendationConflictException(
          'This recommendation changed elsewhere. Refresh and try again.',
          cause: error,
        ),
        '23505' => RecommendationConflictException(
          'A matching recommendation already exists.',
          cause: error,
        ),
        '42501' => RecommendationPermissionException(
          'You do not have permission to access this recommendation.',
          cause: error,
        ),
        '22007' ||
        '22023' ||
        '22P02' ||
        '23502' ||
        '23503' ||
        '23514' => RecommendationValidationException(
          'The recommendation request failed server validation.',
          cause: error,
        ),
        _ => RecommendationServerException(
          'The recommendation data service failed safely.',
          cause: error,
        ),
      };
}

String? _functionCode(Object? details) {
  if (details is! Map) return null;
  final error = details['error'];
  if (error is! Map) return null;
  final code = error['code'];
  return code is String ? code : null;
}
