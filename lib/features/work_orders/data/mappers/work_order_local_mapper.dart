import '../../../../core/database/local_sync_state.dart';
import '../../models/work_order.dart';
import '../../repositories/work_order_data_exception.dart';
import '../dto/local_work_order_draft.dart';
import '../dto/local_work_order_record.dart';
import '../dto/work_order_record_dto.dart';

class WorkOrderLocalMapper {
  const WorkOrderLocalMapper();

  LocalWorkOrderRecord confirmedFromDto({
    required String localId,
    required String ownerUserId,
    required WorkOrderRecordDto record,
    required DateTime retrievedAtUtc,
    required DateTime localCreatedAtUtc,
    required DateTime localModifiedAtUtc,
  }) => LocalWorkOrderRecord(
    localId: localId,
    ownerUserId: ownerUserId,
    createdByUserId: record.createdByUserId,
    draft: LocalWorkOrderDraft(
      incidentId: record.incidentId,
      recommendationId: record.recommendationId,
      routeId: record.routeId,
      vehicleId: record.vehicleId,
      taskType: record.taskType,
      description: record.description,
      priority: record.priority,
      scheduledStart: record.scheduledStart,
      scheduledEnd: record.scheduledEnd,
      notes: record.notes,
      createdByLabel: record.createdByLabel,
      allowLegacyScheduleEquality: record.hasLegacyScheduleEquality,
    ),
    status: record.status,
    syncState: LocalSyncState.cachedRemote,
    remoteStorageId: record.storageId,
    workOrderId: record.workOrderId,
    assignedTo: record.assignedTo,
    remoteCreatedAt: record.createdAt,
    remoteUpdatedAt: record.updatedAt,
    completedAt: record.completedAt,
    cancelledAt: record.cancelledAt,
    remoteVersion: record.remoteVersion,
    retrievedAt: retrievedAtUtc,
    localCreatedAt: localCreatedAtUtc,
    localModifiedAt: localModifiedAtUtc,
  );

  Map<String, Object?> toRow(LocalWorkOrderRecord record) => {
    'local_id': record.localId,
    'owner_user_id': record.ownerUserId,
    'remote_storage_id': record.remoteStorageId,
    'work_order_id': record.workOrderId,
    'incident_id': record.draft.incidentId,
    'recommendation_id': record.draft.recommendationId,
    'route_id': record.draft.routeId,
    'vehicle_id': record.draft.vehicleId,
    'task_type': record.draft.taskType,
    'description': record.draft.description,
    'priority': record.draft.priority.name,
    'assigned_to': record.assignedTo,
    'scheduled_start_utc': record.draft.scheduledStart?.toIso8601String(),
    'scheduled_end_utc': record.draft.scheduledEnd?.toIso8601String(),
    'status': _statusToStorage(record.status),
    'notes': record.draft.notes,
    'created_by_user_id': record.createdByUserId,
    'created_by_label': record.draft.createdByLabel,
    'remote_created_at_utc': record.remoteCreatedAt?.toIso8601String(),
    'remote_updated_at_utc': record.remoteUpdatedAt?.toIso8601String(),
    'completed_at_utc': record.completedAt?.toIso8601String(),
    'cancelled_at_utc': record.cancelledAt?.toIso8601String(),
    'remote_version': record.remoteVersion,
    'sync_state': record.syncState.storageValue,
    'retrieved_at_utc': record.retrievedAt?.toIso8601String(),
    'local_created_at_utc': record.localCreatedAt.toIso8601String(),
    'local_modified_at_utc': record.localModifiedAt.toIso8601String(),
    'safe_error_message': record.safeErrorMessage,
  };

  LocalWorkOrderRecord fromRow(Map<String, Object?> row) {
    try {
      return LocalWorkOrderRecord(
        localId: row['local_id']! as String,
        ownerUserId: row['owner_user_id']! as String,
        createdByUserId: row['created_by_user_id']! as String,
        draft: LocalWorkOrderDraft(
          incidentId: row['incident_id'] as String?,
          recommendationId: row['recommendation_id'] as String?,
          routeId: row['route_id'] as String?,
          vehicleId: row['vehicle_id']! as String,
          taskType: row['task_type']! as String,
          description: row['description']! as String,
          priority: _priority(row['priority']),
          scheduledStart: _date(row['scheduled_start_utc']),
          scheduledEnd: _date(row['scheduled_end_utc']),
          notes: row['notes'] as String?,
          createdByLabel: row['created_by_label']! as String,
          allowLegacyScheduleEquality: true,
        ),
        status: _status(row['status']),
        syncState: LocalSyncState.fromStorage(row['sync_state']! as String),
        remoteStorageId: row['remote_storage_id'] as String?,
        workOrderId: row['work_order_id'] as String?,
        assignedTo: row['assigned_to'] as String?,
        remoteCreatedAt: _date(row['remote_created_at_utc']),
        remoteUpdatedAt: _date(row['remote_updated_at_utc']),
        completedAt: _date(row['completed_at_utc']),
        cancelledAt: _date(row['cancelled_at_utc']),
        remoteVersion: row['remote_version'] as int?,
        retrievedAt: _date(row['retrieved_at_utc']),
        localCreatedAt: _date(row['local_created_at_utc'])!,
        localModifiedAt: _date(row['local_modified_at_utc'])!,
        safeErrorMessage: row['safe_error_message'] as String?,
      );
    } on WorkOrderDataException {
      rethrow;
    } catch (error) {
      throw WorkOrderCorruptionException(
        'Local work-order data is malformed.',
        cause: error,
      );
    }
  }

  DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();
  WorkOrderPriority _priority(Object? value) => switch (value) {
    'low' => WorkOrderPriority.low,
    'medium' => WorkOrderPriority.medium,
    'high' => WorkOrderPriority.high,
    'urgent' => WorkOrderPriority.urgent,
    _ => throw WorkOrderCorruptionException('Unknown local priority "$value".'),
  };
  WorkOrderStatus _status(Object? value) => switch (value) {
    'draft' => WorkOrderStatus.draft,
    'open' => WorkOrderStatus.open,
    'assigned' => WorkOrderStatus.assigned,
    'in_progress' => WorkOrderStatus.inProgress,
    'completed' => WorkOrderStatus.completed,
    'cancelled' => WorkOrderStatus.cancelled,
    _ => throw WorkOrderCorruptionException('Unknown local status "$value".'),
  };
  String _statusToStorage(WorkOrderStatus value) =>
      value == WorkOrderStatus.inProgress ? 'in_progress' : value.name;
}
