import '../../../../core/database/local_sync_state.dart';
import '../../../../core/database/local_user_scope.dart';
import '../../models/work_order.dart';
import '../../repositories/work_order_data_exception.dart';
import 'local_work_order_draft.dart';
import 'work_order_record_dto.dart';

class LocalWorkOrderRecord {
  LocalWorkOrderRecord({
    required String localId,
    required String ownerUserId,
    required String createdByUserId,
    required this.draft,
    required this.status,
    required this.syncState,
    required DateTime localCreatedAt,
    required DateTime localModifiedAt,
    String? remoteStorageId,
    String? workOrderId,
    String? assignedTo,
    DateTime? remoteCreatedAt,
    DateTime? remoteUpdatedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    this.remoteVersion,
    DateTime? retrievedAt,
    String? safeErrorMessage,
  }) : localId = localId.trim(),
       ownerUserId = ownerUserId.trim(),
       createdByUserId = createdByUserId.trim(),
       remoteStorageId = _optional(remoteStorageId),
       workOrderId = _optional(workOrderId),
       assignedTo = _optional(assignedTo),
       remoteCreatedAt = remoteCreatedAt?.toUtc(),
       remoteUpdatedAt = remoteUpdatedAt?.toUtc(),
       completedAt = completedAt?.toUtc(),
       cancelledAt = cancelledAt?.toUtc(),
       retrievedAt = retrievedAt?.toUtc(),
       localCreatedAt = localCreatedAt.toUtc(),
       localModifiedAt = localModifiedAt.toUtc(),
       safeErrorMessage = _optional(safeErrorMessage) {
    _validate();
  }

  final String localId;
  final String ownerUserId;
  final String createdByUserId;
  final LocalWorkOrderDraft draft;
  final WorkOrderStatus status;
  final LocalSyncState syncState;
  final String? remoteStorageId;
  final String? workOrderId;
  final String? assignedTo;
  final DateTime? remoteCreatedAt;
  final DateTime? remoteUpdatedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final int? remoteVersion;
  final DateTime? retrievedAt;
  final DateTime localCreatedAt;
  final DateTime localModifiedAt;
  final String? safeErrorMessage;

  bool get isConfirmedRemote => syncState == LocalSyncState.cachedRemote;

  WorkOrderRecordDto toConfirmedDto() {
    if (!isConfirmedRemote) {
      throw const WorkOrderValidationException(
        'Only confirmed cached work orders can become remote records.',
      );
    }
    return WorkOrderRecordDto(
      storageId: remoteStorageId!,
      workOrderId: workOrderId!,
      incidentId: draft.incidentId,
      recommendationId: draft.recommendationId,
      vehicleId: draft.vehicleId,
      taskType: draft.taskType,
      description: draft.description,
      priority: draft.priority,
      assignedTo: assignedTo,
      scheduledStart: draft.scheduledStart,
      scheduledEnd: draft.scheduledEnd,
      status: status,
      notes: draft.notes,
      createdByUserId: createdByUserId,
      createdByLabel: draft.createdByLabel,
      createdAt: remoteCreatedAt!,
      updatedAt: remoteUpdatedAt!,
      completedAt: completedAt,
      cancelledAt: cancelledAt,
      remoteVersion: remoteVersion!,
    );
  }

  void _validate() {
    if (localId.isEmpty) {
      throw const WorkOrderValidationException(
        'Local work-order ID is required.',
      );
    }
    LocalUserScope(ownerUserId);
    LocalUserScope(createdByUserId);
    if (localModifiedAt.isBefore(localCreatedAt)) {
      throw const WorkOrderValidationException(
        'Local modified time cannot be earlier than local creation time.',
      );
    }
    final serverFieldsAbsent =
        remoteStorageId == null &&
        workOrderId == null &&
        assignedTo == null &&
        remoteCreatedAt == null &&
        remoteUpdatedAt == null &&
        completedAt == null &&
        cancelledAt == null &&
        remoteVersion == null &&
        retrievedAt == null;
    switch (syncState) {
      case LocalSyncState.cachedRemote:
        if (remoteStorageId == null ||
            workOrderId == null ||
            remoteCreatedAt == null ||
            remoteUpdatedAt == null ||
            remoteVersion == null ||
            remoteVersion! < 1 ||
            retrievedAt == null ||
            safeErrorMessage != null) {
          throw const WorkOrderValidationException(
            'Confirmed work-order cache metadata is incomplete.',
          );
        }
        toConfirmedDto();
      case LocalSyncState.localDraft || LocalSyncState.pendingPublication:
        if (status != WorkOrderStatus.draft ||
            !serverFieldsAbsent ||
            safeErrorMessage != null) {
          throw const WorkOrderValidationException(
            'Unpublished work order contains server-owned data.',
          );
        }
      case LocalSyncState.publicationFailed || LocalSyncState.conflict:
        if (status != WorkOrderStatus.draft ||
            !serverFieldsAbsent ||
            safeErrorMessage == null) {
          throw const WorkOrderValidationException(
            'Failed local work order requires only a safe error message.',
          );
        }
    }
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
