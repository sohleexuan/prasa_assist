import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/incident_data_exception.dart';
import '../dto/incident_record_dto.dart';
import 'incident_remote_data_source.dart';

abstract interface class IncidentSupabaseGateway {
  Future<Object?> fetchAllIncidentRows();

  Future<Object?> fetchIncidentRow(String incidentCode);

  Future<Object?> invokeRpc(String functionName, Map<String, dynamic> params);
}

class SupabaseIncidentGateway implements IncidentSupabaseGateway {
  SupabaseIncidentGateway(this._client);

  static const _selection =
      'id,incident_code,incident_type,title,description,route_id,route_name,'
      'vehicle_id,location,reported_at,severity,status,vehicle_condition,'
      'disruption_scope,estimated_delay_minutes,impact_level,'
      'estimation_reasons,estimation_model_version,data_source,'
      'reported_by_label,created_at,updated_at,version,'
      'incident_status_history(sequence_no,from_status,to_status,changed_at,'
      'changed_by_label,note)';

  final SupabaseClient _client;

  @override
  Future<Object?> fetchAllIncidentRows() {
    return _client
        .from('incidents')
        .select(_selection)
        .order('reported_at', ascending: false);
  }

  @override
  Future<Object?> fetchIncidentRow(String incidentCode) {
    return _client
        .from('incidents')
        .select(_selection)
        .eq('incident_code', incidentCode)
        .maybeSingle();
  }

  @override
  Future<Object?> invokeRpc(String functionName, Map<String, dynamic> params) {
    return _client.rpc<Object?>(functionName, params: params);
  }
}

class SupabaseIncidentRemoteDataSource implements IncidentRemoteDataSource {
  SupabaseIncidentRemoteDataSource(SupabaseClient client)
    : this.withGateway(SupabaseIncidentGateway(client));

  SupabaseIncidentRemoteDataSource.withGateway(this._gateway);

  static const saveRpc = 'save_incident';
  static const transitionRpc = 'transition_incident';

  final IncidentSupabaseGateway _gateway;

  @override
  Future<List<IncidentRecordDto>> fetchAll() async {
    final response = await _request(_gateway.fetchAllIncidentRows);
    if (response is! List) {
      throw IncidentMappingException(
        'Incident data returned an invalid list response.',
        cause: response,
      );
    }
    return List<IncidentRecordDto>.unmodifiable(
      response.map(_recordFromResponse),
    );
  }

  @override
  Future<IncidentRecordDto?> fetchByCode(String incidentCode) async {
    final response = await _request(
      () => _gateway.fetchIncidentRow(incidentCode),
    );
    return response == null ? null : _recordFromResponse(response);
  }

  @override
  Future<IncidentRecordDto> insert(IncidentRecordDto record) async {
    if (record.status != 'reported') {
      throw const IncidentValidationException(
        'A persisted incident must be created as Reported.',
      );
    }
    final response = await _request(
      () => _gateway.invokeRpc(saveRpc, <String, dynamic>{
        'p_payload': _savePayload(record, includeIncidentCode: false),
        'p_expected_version': null,
      }),
    );
    return _recordFromResponse(response);
  }

  @override
  Future<IncidentRecordDto> update(
    IncidentRecordDto record, {
    required int expectedVersion,
  }) async {
    final response = await _request(
      () => _gateway.invokeRpc(saveRpc, <String, dynamic>{
        'p_payload': _savePayload(record, includeIncidentCode: true),
        'p_expected_version': expectedVersion,
      }),
    );
    return _recordFromResponse(response);
  }

  @override
  Future<IncidentRecordDto> transitionStatus(
    String incidentCode, {
    required String toStatus,
    String? note,
    required int expectedVersion,
  }) async {
    final response = await _request(
      () => _gateway.invokeRpc(transitionRpc, <String, dynamic>{
        'p_incident_code': incidentCode,
        'p_to_status': toStatus,
        'p_note': note?.trim(),
        'p_expected_version': expectedVersion,
      }),
    );
    return _recordFromResponse(response);
  }

  Map<String, dynamic> _savePayload(
    IncidentRecordDto record, {
    required bool includeIncidentCode,
  }) {
    return <String, dynamic>{
      if (includeIncidentCode) 'incident_code': record.incidentCode,
      'incident_type': record.incidentType,
      'title': record.title,
      'description': record.description,
      'route_id': record.routeId,
      'route_name': record.routeName,
      'vehicle_id': record.vehicleId,
      'location': record.location,
      'reported_at': record.reportedAt.toIso8601String(),
      'severity': record.severity,
      'vehicle_condition': record.vehicleCondition,
      'disruption_scope': record.disruptionScope,
      'estimated_delay_minutes': record.estimatedDelayMinutes,
      'impact_level': record.impactLevel,
      'estimation_reasons': List<String>.from(record.estimationReasons),
    };
  }

  IncidentRecordDto _recordFromResponse(Object? response) {
    if (response is! Map) {
      throw IncidentMappingException(
        'Incident data returned an invalid record response.',
        cause: response,
      );
    }
    final row = response.map(
      (key, value) => MapEntry<String, dynamic>(key.toString(), value),
    );
    if (!row.containsKey('incident_status_history') &&
        row.containsKey('status_history')) {
      row['incident_status_history'] = row['status_history'];
    }
    return IncidentRecordDto.fromMap(row);
  }

  Future<T> _request<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on IncidentDataException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _postgrestFailure(error);
    } on AuthException catch (error) {
      throw IncidentPermissionException(
        'An authenticated staff session is required for incident data.',
        cause: error,
      );
    } on TimeoutException catch (error) {
      throw IncidentOfflineException(
        'Incident data is unavailable. Check the connection and try again.',
        cause: error,
      );
    } catch (error) {
      throw IncidentOfflineException(
        'Incident data is unavailable. Check the connection and try again.',
        cause: error,
      );
    }
  }

  IncidentDataException _postgrestFailure(PostgrestException error) {
    return switch (error.code) {
      'P0002' || 'PGRST116' => IncidentNotFoundException(
        'The requested incident was not found.',
        cause: error,
      ),
      '23505' => IncidentDuplicateException(
        'An incident with the same identifier already exists.',
        cause: error,
      ),
      '40001' => IncidentConflictException(
        'This incident changed elsewhere. Reload it and try again.',
        cause: error,
      ),
      '42501' => IncidentPermissionException(
        'You do not have permission to access incident data.',
        cause: error,
      ),
      'PGRST202' || 'PGRST205' => IncidentPersistenceSetupException(
        'Incident persistence is not available yet. Ask the coordinator to '
        'apply the approved database migration.',
        cause: error,
      ),
      '22007' ||
      '22023' ||
      '22P02' ||
      '23502' ||
      '23503' ||
      '23514' => IncidentValidationException(
        'The incident data was rejected by persistence validation.',
        cause: error,
      ),
      _ => IncidentUnknownDataException(
        'Unable to complete the incident data operation.',
        cause: error,
      ),
    };
  }
}
