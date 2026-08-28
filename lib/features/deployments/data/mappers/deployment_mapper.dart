import '../../models/deployment_status.dart';
import '../../models/service_deployment.dart';
import '../../repositories/deployment_data_exception.dart';
import '../dto/deployment_record_dto.dart';

class DeploymentMapper {
  const DeploymentMapper();

  ServiceDeployment toDomain(DeploymentRecordDto record) {
    final deployment = ServiceDeployment(
      deploymentId: record.deploymentCode,
      routeId: record.routeId,
      routeName: record.routeName,
      vehicleIds: record.vehicleIds,
      startTime: record.startTime,
      endTime: record.endTime,
      status: _statusFromStorage(record.status),
      purpose: record.purpose,
      createdBy: record.createdByLabel,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      version: record.version,
      incidentId: record.incidentId,
      sourceRecommendationId: record.recommendationId,
    );
    final validationErrors = deployment.validate();
    if (validationErrors.isNotEmpty) {
      throw DeploymentMappingException(
        'Deployment record is invalid: ${validationErrors.join(' ')}',
      );
    }
    return deployment;
  }

  DeploymentRecordDto toDto(ServiceDeployment deployment, {String? storageId}) {
    final validationErrors = deployment.validate();
    if (validationErrors.isNotEmpty) {
      throw DeploymentValidationException(validationErrors.join(' '));
    }
    return DeploymentRecordDto(
      storageId: storageId,
      deploymentCode: deployment.deploymentId,
      routeId: deployment.routeId,
      routeName: deployment.routeName,
      vehicleIds: deployment.vehicleIds,
      startTime: deployment.startTime,
      endTime: deployment.endTime,
      status: _statusToStorage(deployment.status),
      purpose: deployment.purpose,
      createdByLabel: deployment.createdBy,
      createdAt: deployment.createdAt,
      updatedAt: deployment.updatedAt,
      version: deployment.version,
      incidentId: deployment.incidentId,
      recommendationId: deployment.sourceRecommendationId,
    );
  }

  DeploymentStatus _statusFromStorage(String status) => switch (status) {
    'draft' => DeploymentStatus.draft,
    'scheduled' => DeploymentStatus.scheduled,
    'active' => DeploymentStatus.active,
    'completed' => DeploymentStatus.completed,
    'cancelled' => DeploymentStatus.cancelled,
    _ => throw DeploymentMappingException(
      'Deployment record has unknown status "$status".',
    ),
  };

  String _statusToStorage(DeploymentStatus status) => switch (status) {
    DeploymentStatus.draft => 'draft',
    DeploymentStatus.scheduled => 'scheduled',
    DeploymentStatus.active => 'active',
    DeploymentStatus.completed => 'completed',
    DeploymentStatus.cancelled => 'cancelled',
  };
}
