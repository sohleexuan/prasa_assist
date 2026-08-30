import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/work_order.dart';
import '../../repositories/work_order_data_exception.dart';
import '../dto/local_work_order_draft.dart';
import '../dto/work_order_record_dto.dart';
import '../dto/work_order_update_input.dart';
import 'src/work_order_transport_classifier.dart';
import 'work_order_remote_data_source.dart';

abstract interface class WorkOrderSupabaseGateway {
  Future<Object?> fetchAllWorkOrderRows();
  Future<Object?> fetchWorkOrderRow(String workOrderId);
  Future<Object?> invokeRpc(String functionName, Map<String, dynamic> params);
}

class SupabaseWorkOrderGateway implements WorkOrderSupabaseGateway {
  SupabaseWorkOrderGateway(this._client);

  static const selection =
      'id,work_order_id,incident_id,recommendation_id,vehicle_id,task_type,'
      'description,priority,assigned_to,scheduled_start,scheduled_end,status,'
      'notes,created_by_user_id,created_by_label,created_at,updated_at,'
      'completed_at,cancelled_at,version';

  final SupabaseClient _client;

  @override
  Future<Object?> fetchAllWorkOrderRows() => _client
      .from('work_orders')
      .select(selection)
      .order('updated_at', ascending: false);

  @override
  Future<Object?> fetchWorkOrderRow(String workOrderId) => _client
      .from('work_orders')
      .select(selection)
      .eq('work_order_id', workOrderId)
      .maybeSingle();

  @override
  Future<Object?> invokeRpc(String functionName, Map<String, dynamic> params) =>
      _client.rpc<Object?>(functionName, params: params);
}

class SupabaseWorkOrderRemoteDataSource implements WorkOrderRemoteDataSource {
  SupabaseWorkOrderRemoteDataSource(SupabaseClient client)
    : this.withGateway(SupabaseWorkOrderGateway(client));

  SupabaseWorkOrderRemoteDataSource.withGateway(this._gateway);

  static const createRpc = 'create_work_order';
  static const updateRpc = 'update_work_order';
  static const assignRpc = 'assign_work_order';
  static const transitionRpc = 'transition_work_order';

  final WorkOrderSupabaseGateway _gateway;

  @override
  Future<List<WorkOrderRecordDto>> fetchAll() async {
    final response = await _request(_gateway.fetchAllWorkOrderRows);
    if (response is! List) {
      throw WorkOrderMappingException(
        'Work-order data returned an invalid list response.',
        cause: response,
      );
    }
    return List<WorkOrderRecordDto>.unmodifiable(
      response.map(_recordFromResponse),
    );
  }

  @override
  Future<WorkOrderRecordDto?> fetchById(String workOrderId) async {
    final response = await _request(
      () => _gateway.fetchWorkOrderRow(workOrderId.trim()),
    );
    return response == null ? null : _recordFromResponse(response);
  }

  @override
  Future<WorkOrderRecordDto> create(
    String publicationKey,
    LocalWorkOrderDraft draft,
  ) async {
    final response = await _request(
      () => _gateway.invokeRpc(createRpc, <String, dynamic>{
        'p_publication_key': publicationKey.trim(),
        'p_payload': <String, dynamic>{
          'incident_id': draft.incidentId,
          'recommendation_id': draft.recommendationId,
          'vehicle_id': draft.vehicleId,
          'task_type': draft.taskType,
          'description': draft.description,
          'priority': _priority(draft.priority),
          'scheduled_start': draft.scheduledStart?.toIso8601String(),
          'scheduled_end': draft.scheduledEnd?.toIso8601String(),
          'notes': draft.notes,
        },
      }),
    );
    return _recordFromResponse(response);
  }

  @override
  Future<WorkOrderRecordDto> update(
    String workOrderId,
    WorkOrderUpdateInput input, {
    required int expectedVersion,
  }) async {
    final response = await _request(
      () => _gateway.invokeRpc(updateRpc, <String, dynamic>{
        'p_work_order_id': workOrderId.trim(),
        'p_payload': <String, dynamic>{
          'vehicle_id': input.vehicleId,
          'task_type': input.taskType,
          'description': input.description,
          'priority': _priority(input.priority),
          'scheduled_start': input.scheduledStart?.toIso8601String(),
          'scheduled_end': input.scheduledEnd?.toIso8601String(),
          'notes': input.notes,
        },
        'p_expected_version': expectedVersion,
      }),
    );
    return _recordFromResponse(response);
  }

  @override
  Future<WorkOrderRecordDto> assign(
    String workOrderId, {
    required String assignedTo,
    required int expectedVersion,
  }) async {
    final response = await _request(
      () => _gateway.invokeRpc(assignRpc, <String, dynamic>{
        'p_work_order_id': workOrderId.trim(),
        'p_assigned_to': assignedTo.trim(),
        'p_expected_version': expectedVersion,
      }),
    );
    return _recordFromResponse(response);
  }

  @override
  Future<WorkOrderRecordDto> transitionStatus(
    String workOrderId, {
    required WorkOrderStatus toStatus,
    required int expectedVersion,
  }) async {
    final response = await _request(
      () => _gateway.invokeRpc(transitionRpc, <String, dynamic>{
        'p_work_order_id': workOrderId.trim(),
        'p_to_status': _status(toStatus),
        'p_expected_version': expectedVersion,
      }),
    );
    return _recordFromResponse(response);
  }

  Future<T> _request<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on WorkOrderDataException {
      rethrow;
    } on AuthException catch (error) {
      throw WorkOrderPermissionException(
        'Authentication is required to access confirmed work orders.',
        cause: error,
      );
    } on PostgrestException catch (error) {
      throw _postgrest(error);
    } on TimeoutException catch (error) {
      throw WorkOrderOfflineException(
        'The confirmed work-order service is unreachable.',
        cause: error,
      );
    } catch (error) {
      if (isVerifiedWorkOrderReadTransportFailure(error)) {
        throw WorkOrderOfflineException(
          'The confirmed work-order service is unreachable.',
          cause: error,
        );
      }
      throw WorkOrderUnknownDataException(
        'The work-order request could not be completed safely.',
        cause: error,
      );
    }
  }

  WorkOrderDataException _postgrest(PostgrestException error) =>
      switch (error.code) {
        'P0002' || 'PGRST116' => WorkOrderNotFoundException(
          'The confirmed work order was not found.',
          cause: error,
        ),
        '40001' => WorkOrderConflictException(
          'The work order changed remotely. Refresh before continuing.',
          cause: error,
        ),
        '42501' => WorkOrderPermissionException(
          'You are not authorized to perform this work-order action.',
          cause: error,
        ),
        '23505' => WorkOrderDuplicateException(
          'A matching confirmed work order already exists.',
          cause: error,
        ),
        '22007' ||
        '22023' ||
        '22P02' ||
        '23502' ||
        '23514' => WorkOrderValidationException(
          'The work-order request failed server validation.',
          cause: error,
        ),
        _ => WorkOrderUnknownDataException(
          'The work-order request could not be completed safely.',
          cause: error,
        ),
      };

  WorkOrderRecordDto _recordFromResponse(Object? response) {
    if (response is! Map) {
      throw WorkOrderMappingException(
        'Work-order data returned an invalid record response.',
        cause: response,
      );
    }
    try {
      return WorkOrderRecordDto.fromMap(Map<String, dynamic>.from(response));
    } on WorkOrderDataException {
      rethrow;
    } catch (error) {
      throw WorkOrderMappingException(
        'Work-order data could not be mapped safely.',
        cause: error,
      );
    }
  }

  String _priority(WorkOrderPriority value) => value.name;
  String _status(WorkOrderStatus value) =>
      value == WorkOrderStatus.inProgress ? 'in_progress' : value.name;
}
