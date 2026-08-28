import '../../../../core/database/local_sync_state.dart';
import '../../repositories/deployment_data_exception.dart';
import '../dto/deployment_record_dto.dart';
import '../dto/local_deployment_draft.dart';
import '../dto/local_deployment_record.dart';

class DeploymentLocalMapper {
  const DeploymentLocalMapper();

  LocalDeploymentRecord fromRows(
    Map<String, Object?> row,
    List<Map<String, Object?>> vehicleRows,
  ) {
    try {
      final orderedVehicles = List<Map<String, Object?>>.from(vehicleRows)
        ..sort(
          (first, second) => _requiredInt(
            first,
            'display_order',
          ).compareTo(_requiredInt(second, 'display_order')),
        );
      return LocalDeploymentRecord(
        localId: _requiredString(row, 'local_id'),
        ownerUserId: _requiredString(row, 'owner_user_id'),
        draft: LocalDeploymentDraft(
          routeId: _requiredString(row, 'route_id'),
          routeName: _requiredString(row, 'route_name'),
          vehicleIds: orderedVehicles
              .map((vehicle) => _requiredString(vehicle, 'vehicle_id'))
              .toList(growable: false),
          startTime: _requiredDateTime(row, 'start_time_utc'),
          endTime: _requiredDateTime(row, 'end_time_utc'),
          purpose: _requiredString(row, 'purpose'),
          incidentId: _optionalString(row, 'incident_id'),
          recommendationId: _optionalString(row, 'recommendation_id'),
        ),
        status: _requiredString(row, 'status'),
        syncState: LocalSyncState.fromStorage(
          _requiredString(row, 'sync_state'),
        ),
        localCreatedAt: _requiredDateTime(row, 'local_created_at_utc'),
        localModifiedAt: _requiredDateTime(row, 'local_modified_at_utc'),
        remoteStorageId: _optionalString(row, 'remote_storage_id'),
        deploymentCode: _optionalString(row, 'deployment_code'),
        createdByLabel: _optionalString(row, 'created_by_label'),
        remoteCreatedAt: _optionalDateTime(row, 'remote_created_at_utc'),
        remoteUpdatedAt: _optionalDateTime(row, 'remote_updated_at_utc'),
        remoteVersion: _optionalInt(row, 'remote_version'),
        retrievedAt: _optionalDateTime(row, 'retrieved_at_utc'),
        safeErrorMessage: _optionalString(row, 'safe_error_message'),
      );
    } on DeploymentMappingException {
      rethrow;
    } on DeploymentDataException catch (error) {
      throw DeploymentMappingException(
        'Local deployment data is malformed.',
        cause: error,
      );
    } catch (error) {
      throw DeploymentMappingException(
        'Local deployment data is malformed.',
        cause: error,
      );
    }
  }

  LocalDeploymentRecord confirmedFromDto({
    required String localId,
    required String ownerUserId,
    required DeploymentRecordDto record,
    required DateTime retrievedAtUtc,
    required DateTime localCreatedAtUtc,
    required DateTime localModifiedAtUtc,
  }) {
    return LocalDeploymentRecord(
      localId: localId,
      ownerUserId: ownerUserId,
      draft: LocalDeploymentDraft(
        routeId: record.routeId,
        routeName: record.routeName,
        vehicleIds: record.vehicleIds,
        startTime: record.startTime,
        endTime: record.endTime,
        purpose: record.purpose,
        incidentId: record.incidentId,
        recommendationId: record.recommendationId,
      ),
      status: record.status,
      syncState: LocalSyncState.cachedRemote,
      localCreatedAt: localCreatedAtUtc,
      localModifiedAt: localModifiedAtUtc,
      remoteStorageId: record.storageId,
      deploymentCode: record.deploymentCode,
      createdByLabel: record.createdByLabel,
      remoteCreatedAt: record.createdAt,
      remoteUpdatedAt: record.updatedAt,
      remoteVersion: record.version,
      retrievedAt: retrievedAtUtc,
    );
  }

  Map<String, Object?> toParentRow(LocalDeploymentRecord record) {
    return <String, Object?>{
      'local_id': record.localId,
      'owner_user_id': record.ownerUserId,
      'remote_storage_id': record.remoteStorageId,
      'deployment_code': record.deploymentCode,
      'incident_id': record.draft.incidentId,
      'recommendation_id': record.draft.recommendationId,
      'route_id': record.draft.routeId,
      'route_name': record.draft.routeName,
      'start_time_utc': record.draft.startTime.toIso8601String(),
      'end_time_utc': record.draft.endTime.toIso8601String(),
      'status': record.status,
      'purpose': record.draft.purpose,
      'created_by_label': record.createdByLabel,
      'remote_created_at_utc': record.remoteCreatedAt?.toIso8601String(),
      'remote_updated_at_utc': record.remoteUpdatedAt?.toIso8601String(),
      'remote_version': record.remoteVersion,
      'sync_state': record.syncState.storageValue,
      'retrieved_at_utc': record.retrievedAt?.toIso8601String(),
      'local_created_at_utc': record.localCreatedAt.toIso8601String(),
      'local_modified_at_utc': record.localModifiedAt.toIso8601String(),
      'safe_error_message': record.safeErrorMessage,
    };
  }

  List<Map<String, Object?>> toVehicleRows(LocalDeploymentRecord record) {
    return List<Map<String, Object?>>.generate(
      record.draft.vehicleIds.length,
      (index) => <String, Object?>{
        'owner_user_id': record.ownerUserId,
        'local_deployment_id': record.localId,
        'display_order': index,
        'vehicle_id': record.draft.vehicleIds[index],
      },
      growable: false,
    );
  }

  String _requiredString(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw DeploymentMappingException(
        'Local deployment field $key is missing or malformed.',
      );
    }
    return value.trim();
  }

  String? _optionalString(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value == null) {
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      throw DeploymentMappingException(
        'Local deployment field $key is malformed.',
      );
    }
    return value.trim();
  }

  int _requiredInt(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is! int) {
      throw DeploymentMappingException(
        'Local deployment field $key is missing or malformed.',
      );
    }
    return value;
  }

  int? _optionalInt(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value == null) {
      return null;
    }
    if (value is! int) {
      throw DeploymentMappingException(
        'Local deployment field $key is malformed.',
      );
    }
    return value;
  }

  DateTime _requiredDateTime(Map<String, Object?> row, String key) {
    final value = _requiredString(row, key);
    try {
      return DateTime.parse(value).toUtc();
    } on FormatException catch (error) {
      throw DeploymentMappingException(
        'Local deployment field $key is not a valid timestamp.',
        cause: error,
      );
    }
  }

  DateTime? _optionalDateTime(Map<String, Object?> row, String key) {
    final value = _optionalString(row, key);
    if (value == null) {
      return null;
    }
    try {
      return DateTime.parse(value).toUtc();
    } on FormatException catch (error) {
      throw DeploymentMappingException(
        'Local deployment field $key is not a valid timestamp.',
        cause: error,
      );
    }
  }
}
