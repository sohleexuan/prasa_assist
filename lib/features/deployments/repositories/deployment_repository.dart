import '../models/service_deployment.dart';

abstract class DeploymentRepository {
  Future<List<ServiceDeployment>> getAll();

  Future<ServiceDeployment?> getById(String deploymentId);

  Future<void> create(ServiceDeployment deployment);

  Future<void> update(ServiceDeployment deployment);

  Future<void> delete(String deploymentId);
}
