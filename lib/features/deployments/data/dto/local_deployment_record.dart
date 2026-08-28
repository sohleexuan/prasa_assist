import '../../../../core/database/local_sync_state.dart';
import '../../../../core/database/local_user_scope.dart';
import '../../repositories/deployment_data_exception.dart';
import 'deployment_record_dto.dart';
import 'local_deployment_draft.dart';

/// Owner-scoped local cache or unpublished work record.
class LocalDeploymentRecord {
  LocalDeploymentRecord({
    required String localId,
    required String ownerUserId,
    required this.draft,
    required String status,
    required this.syncState,
    required DateTime localCreatedAt,
    required DateTime localModifiedAt,
    String? remoteStorageId,
    String? deploymentCode,
    String? createdByLabel,
    DateTime? remoteCreatedAt,
    DateTime? remoteUpdatedAt,
    this.remoteVersion,
    DateTime? retrievedAt,
    String? safeErrorMessage,
  }) : localId = localId.trim(),
       ownerUserId = ownerUserId.trim(),
       status = status.trim(),
       remoteStorageId = remoteStorageId?.trim(),
       deploymentCode = deploymentCode?.trim(),
       createdByLabel = createdByLabel?.trim(),
       remoteCreatedAt = remoteCreatedAt?.toUtc(),
       remoteUpdatedAt = remoteUpdatedAt?.toUtc(),
       retrievedAt = retrievedAt?.toUtc(),
       localCreatedAt = localCreatedAt.toUtc(),
       localModifiedAt = localModifiedAt.toUtc(),
       safeErrorMessage = safeErrorMessage?.trim() {
    _validate();
  }

  final String localId;
  final String ownerUserId;
  final LocalDeploymentDraft draft;
  final String status;
  final LocalSyncState syncState;
  final String? remoteStorageId;
  final String? deploymentCode;
  final String? createdByLabel;
  final DateTime? remoteCreatedAt;
  final DateTime? remoteUpdatedAt;
  final int? remoteVersion;
  final DateTime? retrievedAt;
  final DateTime localCreatedAt;
  final DateTime localModifiedAt;
  final String? safeErrorMessage;

  bool get isConfirmedRemote => syncState == LocalSyncState.cachedRemote;

  DeploymentRecordDto toConfirmedDto() {
    if (!isConfirmedRemote) {
      throw const DeploymentValidationException(
        'Only confirmed cached deployments can become remote records.',
      );
    }
    return DeploymentRecordDto(
      storageId: remoteStorageId,
      deploymentCode: deploymentCode!,
      routeId: draft.routeId,
      routeName: draft.routeName,
      vehicleIds: draft.vehicleIds,
      startTime: draft.startTime,
      endTime: draft.endTime,
      status: status,
      purpose: draft.purpose,
      createdByLabel: createdByLabel!,
      createdAt: remoteCreatedAt!,
      updatedAt: remoteUpdatedAt!,
      version: remoteVersion!,
      incidentId: draft.incidentId,
      recommendationId: draft.recommendationId,
    );
  }

  void _validate() {
    if (localId.isEmpty) {
      throw const DeploymentValidationException(
        'Local deployment ID is required.',
      );
    }
    LocalUserScope(ownerUserId);
    if (localModifiedAt.isBefore(localCreatedAt)) {
      throw const DeploymentValidationException(
        'Local modified time cannot be earlier than local creation time.',
      );
    }
    _validateStatus();
    for (final entry in <String, String?>{
      'remote storage ID': remoteStorageId,
      'deployment code': deploymentCode,
      'created-by label': createdByLabel,
      'safe error message': safeErrorMessage,
    }.entries) {
      if (entry.value != null && entry.value!.isEmpty) {
        throw DeploymentValidationException(
          'Local deployment ${entry.key} cannot be blank.',
        );
      }
    }

    final serverFieldsAreAbsent =
        remoteStorageId == null &&
        deploymentCode == null &&
        createdByLabel == null &&
        remoteCreatedAt == null &&
        remoteUpdatedAt == null &&
        remoteVersion == null &&
        retrievedAt == null;
    switch (syncState) {
      case LocalSyncState.cachedRemote:
        if (deploymentCode == null ||
            createdByLabel == null ||
            remoteCreatedAt == null ||
            remoteUpdatedAt == null ||
            remoteVersion == null ||
            remoteVersion! < 1 ||
            retrievedAt == null ||
            safeErrorMessage != null) {
          throw const DeploymentValidationException(
            'Confirmed cache metadata is incomplete.',
          );
        }
      case LocalSyncState.localDraft || LocalSyncState.pendingPublication:
        if (!serverFieldsAreAbsent || safeErrorMessage != null) {
          throw const DeploymentValidationException(
            'Unpublished deployment state contains server-owned data.',
          );
        }
      case LocalSyncState.publicationFailed || LocalSyncState.conflict:
        if (!serverFieldsAreAbsent || safeErrorMessage?.isNotEmpty != true) {
          throw const DeploymentValidationException(
            'Failed local deployment state requires a safe message only.',
          );
        }
    }
  }

  void _validateStatus() {
    if (!DeploymentRecordDto.validStatuses.contains(status)) {
      throw DeploymentValidationException(
        'Local deployment has unknown status "$status".',
      );
    }
    if (!isConfirmedRemote && status != 'draft') {
      throw const DeploymentValidationException(
        'Unpublished local deployment work must remain Draft.',
      );
    }
  }
}
