import '../models/deployment_status.dart';
import '../models/service_deployment.dart';

abstract class DeploymentRepository {
  Future<List<ServiceDeployment>> getAll();

  Future<ServiceDeployment?> getById(String deploymentId);

  Future<ServiceDeployment> create(ServiceDeployment deployment);

  Future<ServiceDeployment> update(ServiceDeployment deployment);

  Future<void> delete(String deploymentId);

  Future<ServiceDeployment> transitionStatus(
    String deploymentCode,
    DeploymentStatus targetStatus, {
    required String changedByLabel,
    DateTime? changedAt,
  });
}
