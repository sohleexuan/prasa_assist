import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/deployment_data_exception.dart';
import '../dto/deployment_record_dto.dart';
import '../dto/local_deployment_draft.dart';
import 'deployment_remote_data_source.dart';
import 'src/deployment_transport_classifier.dart';

abstract interface class DeploymentSupabaseGateway {
  Future<Object?> fetchAllDeploymentRows();

  Future<Object?> fetchDeploymentRow(String deploymentCode);

  Future<Object?> invokeRpc(String functionName, Map<String, dynamic> params);
}

class SupabaseDeploymentGateway implements DeploymentSupabaseGateway {
  SupabaseDeploymentGateway(this._client);

  static const _selection =
      'id,deployment_code,'
      'incident_id:linked_incident_ref,'
      'recommendation_id:linked_recommendation_ref,'
      'route_id,route_name,start_time,end_time,status,purpose,'
      'created_by_label:created_by,created_at,updated_at,version,'
      'deployment_vehicles(vehicle_id,display_order:sequence_no)';

  final SupabaseClient _client;

  @override
  Future<Object?> fetchAllDeploymentRows() {
    return _client.from('deployments').select(_selection).order('start_time');
  }

  @override
  Future<Object?> fetchDeploymentRow(String deploymentCode) {
    return _client
        .from('deployments')
        .select(_selection)
        .eq('deployment_code', deploymentCode)
        .maybeSingle();
  }

  @override
  Future<Object?> invokeRpc(String functionName, Map<String, dynamic> params) {
    return _client.rpc<Object?>(functionName, params: params);
  }
}

class SupabaseDeploymentRemoteDataSource
    implements DeploymentRemoteDataSource, DeploymentDraftRemotePublisher {
  SupabaseDeploymentRemoteDataSource(SupabaseClient client)
    : this.withGateway(SupabaseDeploymentGateway(client));

  SupabaseDeploymentRemoteDataSource.withGateway(this._gateway);

  static const saveRpc = 'save_deployment';
  static const transitionRpc = 'transition_deployment';

  final DeploymentSupabaseGateway _gateway;

  @override
  Future<List<DeploymentRecordDto>> fetchAll() async {
    final response = await _request(_gateway.fetchAllDeploymentRows);
    if (response is! List) {
      throw DeploymentMappingException(
        'Deployment data returned an invalid list response.',
        cause: response,
      );
    }
    return List<DeploymentRecordDto>.unmodifiable(
      response.map((row) => _recordFromResponse(row)),
    );
  }

  @override
  Future<DeploymentRecordDto?> fetchByCode(String deploymentCode) async {
    final response = await _request(
      () => _gateway.fetchDeploymentRow(deploymentCode),
    );
    return response == null ? null : _recordFromResponse(response);
  }

  @override
  Future<DeploymentRecordDto> insert(DeploymentRecordDto record) async {
    if (record.status != 'draft') {
      throw const DeploymentValidationException(
        'A persisted deployment must be created as Draft before scheduling.',
      );
    }
    final response = await _request(
      () => _gateway.invokeRpc(saveRpc, <String, dynamic>{
        'p_payload': _savePayload(record, includeDeploymentCode: false),
        'p_expected_version': null,
      }),
    );
    return _recordFromResponse(response);
  }

  @override
  Future<DeploymentRecordDto> publishDraft(LocalDeploymentDraft draft) async {
    final response = await _request(
      () => _gateway.invokeRpc(saveRpc, <String, dynamic>{
        'p_payload': <String, dynamic>{
          'linked_incident_ref': draft.incidentId,
          'linked_recommendation_ref': draft.recommendationId,
          'route_id': draft.routeId,
          'route_name': draft.routeName,
          'start_time': draft.startTime.toUtc().toIso8601String(),
          'end_time': draft.endTime.toUtc().toIso8601String(),
          'purpose': draft.purpose,
          'vehicle_ids': List<String>.from(draft.vehicleIds),
        },
        'p_expected_version': null,
      }),
    );
    return _recordFromResponse(response);
  }

  @override
  Future<DeploymentRecordDto> update(
    DeploymentRecordDto record, {
    required int expectedVersion,
  }) async {
    final response = await _request(
      () => _gateway.invokeRpc(saveRpc, <String, dynamic>{
        'p_payload': _savePayload(record, includeDeploymentCode: true),
        'p_expected_version': expectedVersion,
      }),
    );
    return _recordFromResponse(response);
  }

  @override
  Future<DeploymentRecordDto> transitionStatus(
    String deploymentCode, {
    required String fromStatus,
    required String toStatus,
    required String changedByLabel,
    required DateTime changedAt,
    required int expectedVersion,
  }) async {
    final response = await _request(
      () => _gateway.invokeRpc(transitionRpc, <String, dynamic>{
        'p_deployment_code': deploymentCode,
        'p_to_status': toStatus,
        'p_expected_version': expectedVersion,
      }),
    );
    return _recordFromResponse(response);
  }

  @override
  Future<void> delete(
    String deploymentCode, {
    required int expectedVersion,
  }) async {
    throw const DeploymentPermissionException(
      'Persistent deployment records cannot be physically deleted.',
    );
  }

  Map<String, dynamic> _savePayload(
    DeploymentRecordDto record, {
    required bool includeDeploymentCode,
  }) {
    return <String, dynamic>{
      if (includeDeploymentCode) 'deployment_code': record.deploymentCode,
      'linked_incident_ref': record.incidentId,
      'linked_recommendation_ref': record.recommendationId,
      'route_id': record.routeId,
      'route_name': record.routeName,
      'start_time': record.startTime.toUtc().toIso8601String(),
      'end_time': record.endTime.toUtc().toIso8601String(),
      'purpose': record.purpose,
      'vehicle_ids': List<String>.from(record.vehicleIds),
    };
  }

  DeploymentRecordDto _recordFromResponse(Object? response) {
    final row = _mapFromResponse(response);
    final normalized = <String, dynamic>{
      if (row.containsKey('id')) 'id': row['id'],
      'deployment_code': row['deployment_code'],
      'incident_id': row.containsKey('incident_id')
          ? row['incident_id']
          : row['linked_incident_ref'],
      'recommendation_id': row.containsKey('recommendation_id')
          ? row['recommendation_id']
          : row['linked_recommendation_ref'],
      'route_id': row['route_id'],
      'route_name': row['route_name'],
      if (row.containsKey('vehicle_ids')) 'vehicle_ids': row['vehicle_ids'],
      if (row.containsKey('deployment_vehicles'))
        'deployment_vehicles': row['deployment_vehicles'],
      'start_time': row['start_time'],
      'end_time': row['end_time'],
      'status': row['status'],
      'purpose': row['purpose'],
      'created_by_label': row.containsKey('created_by_label')
          ? row['created_by_label']
          : row['created_by'],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
      'version': row['version'],
    };
    return DeploymentRecordDto.fromMap(normalized);
  }

  Map<String, dynamic> _mapFromResponse(Object? response) {
    if (response is! Map) {
      throw DeploymentMappingException(
        'Deployment data returned an invalid record response.',
        cause: response,
      );
    }
    return response.map(
      (key, value) => MapEntry<String, dynamic>(key.toString(), value),
    );
  }

  Future<T> _request<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DeploymentDataException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _postgrestFailure(error);
    } on AuthException catch (error) {
      throw DeploymentPermissionException(
        'An authenticated staff session is required for deployment data.',
        cause: error,
      );
    } on TimeoutException catch (error) {
      throw DeploymentOfflineException(
        'Deployment data is unavailable. Check the connection and try again.',
        cause: error,
      );
    } catch (error) {
      if (isDeploymentTransportFailure(error)) {
        throw DeploymentOfflineException(
          'Deployment data is unavailable. Check the connection and try again.',
          cause: error,
        );
      }
      throw DeploymentUnknownDataException(
        'Unable to complete the deployment data operation.',
        cause: error,
      );
    }
  }

  DeploymentDataException _postgrestFailure(PostgrestException error) {
    return switch (error.code) {
      'P0002' || 'PGRST116' => DeploymentNotFoundException(
        'The requested deployment was not found.',
        cause: error,
      ),
      '23505' => DeploymentDuplicateException(
        'A deployment with the same identifier already exists.',
        cause: error,
      ),
      '40001' => DeploymentConflictException(
        'This deployment changed elsewhere. Reload it and try again.',
        cause: error,
      ),
      '42501' => DeploymentPermissionException(
        'You do not have permission to access deployment data.',
        cause: error,
      ),
      '22007' ||
      '22023' ||
      '22P02' ||
      '23502' ||
      '23514' => DeploymentValidationException(
        'The deployment data was rejected by persistence validation.',
        cause: error,
      ),
      _ => DeploymentUnknownDataException(
        'Unable to complete the deployment data operation.',
        cause: error,
      ),
    };
  }
}
