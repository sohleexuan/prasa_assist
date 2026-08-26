import '../models/deployment_status.dart';
import '../models/service_deployment.dart';
import 'deployment_repository.dart';

/// In-memory storage for development and demonstration only.
///
/// This repository is not a live data source and does not connect to Supabase.
class InMemoryDeploymentRepository implements DeploymentRepository {
  InMemoryDeploymentRepository({
    Iterable<ServiceDeployment> seedData = const [],
  }) {
    for (final deployment in seedData) {
      _validate(deployment);
      if (_deployments.containsKey(deployment.deploymentId)) {
        throw StateError(
          'A deployment with ID ${deployment.deploymentId} already exists.',
        );
      }
      _deployments[deployment.deploymentId] = deployment.copyWith();
    }
  }

  /// Creates a repository containing mock data for the shared Bus B1023 demo.
  factory InMemoryDeploymentRepository.withDemonstrationData() {
    return InMemoryDeploymentRepository(seedData: [demonstrationDeployment]);
  }

  final Map<String, ServiceDeployment> _deployments = {};

  /// Mock data only; the identifiers and operational details are demonstrative.
  static ServiceDeployment get demonstrationDeployment => ServiceDeployment(
    deploymentId: 'DEP-120',
    routeId: '300',
    routeName: 'Route 300',
    vehicleIds: const ['ABC 1230', 'DEF 4567'],
    startTime: DateTime(2026, 8, 27, 8),
    endTime: DateTime(2026, 8, 27, 10),
    status: DeploymentStatus.scheduled,
    purpose: 'Replace unavailable Bus B1023 during peak hour',
    createdBy: 'Demo Operations Staff',
    createdAt: DateTime(2026, 8, 27, 7, 30),
    updatedAt: DateTime(2026, 8, 27, 7, 45),
    incidentId: 'INC-2026-0142',
    sourceRecommendationId: 'REC-0088',
  );

  @override
  Future<List<ServiceDeployment>> getAll() async {
    return List<ServiceDeployment>.unmodifiable(
      _deployments.values.map((deployment) => deployment.copyWith()),
    );
  }

  @override
  Future<ServiceDeployment?> getById(String deploymentId) async {
    return _deployments[deploymentId]?.copyWith();
  }

  @override
  Future<void> create(ServiceDeployment deployment) async {
    _validate(deployment);
    if (_deployments.containsKey(deployment.deploymentId)) {
      throw StateError(
        'A deployment with ID ${deployment.deploymentId} already exists.',
      );
    }
    _deployments[deployment.deploymentId] = deployment.copyWith();
  }

  @override
  Future<void> update(ServiceDeployment deployment) async {
    _validate(deployment);
    if (!_deployments.containsKey(deployment.deploymentId)) {
      throw StateError('Deployment ${deployment.deploymentId} does not exist.');
    }
    _deployments[deployment.deploymentId] = deployment.copyWith();
  }

  @override
  Future<void> delete(String deploymentId) async {
    final deployment = _deployments[deploymentId];
    if (deployment == null) {
      throw StateError('Deployment $deploymentId does not exist.');
    }
    if (deployment.status != DeploymentStatus.draft &&
        deployment.status != DeploymentStatus.cancelled) {
      throw StateError('Only Draft or Cancelled deployments may be deleted.');
    }
    _deployments.remove(deploymentId);
  }

  void _validate(ServiceDeployment deployment) {
    final errors = deployment.validate();
    if (errors.isNotEmpty) {
      throw ArgumentError(errors.join(' '), 'deployment');
    }
  }
}
