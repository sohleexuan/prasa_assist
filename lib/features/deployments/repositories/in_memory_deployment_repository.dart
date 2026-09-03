import '../models/deployment_status.dart';
import '../models/service_deployment.dart';
import 'deployment_data_exception.dart';
import 'deployment_repository.dart';
import 'deployment_repository_capabilities.dart';

class InMemoryDeploymentRepository
    implements DeploymentRepository, DeploymentRepositoryCapabilitiesProvider {
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

  factory InMemoryDeploymentRepository.withDemonstrationData() {
    return InMemoryDeploymentRepository(seedData: [demonstrationDeployment]);
  }

  final Map<String, ServiceDeployment> _deployments = {};

  @override
  DeploymentRepositoryCapabilities get capabilities =>
      const DeploymentRepositoryCapabilities.prototype();

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
  Future<ServiceDeployment> create(ServiceDeployment deployment) async {
    _validate(deployment);
    if (_deployments.containsKey(deployment.deploymentId)) {
      throw DeploymentDuplicateException(
        'A deployment with ID ${deployment.deploymentId} already exists.',
      );
    }
    final created = deployment.copyWith();
    _deployments[deployment.deploymentId] = created;
    return created.copyWith();
  }

  @override
  Future<ServiceDeployment> update(ServiceDeployment deployment) async {
    _validate(deployment);
    final current = _deployments[deployment.deploymentId];
    if (current == null) {
      throw DeploymentNotFoundException(
        'Deployment ${deployment.deploymentId} does not exist.',
      );
    }
    if (deployment.version != current.version) {
      throw DeploymentConflictException(
        'Deployment ${deployment.deploymentId} was changed by another operation. '
        'Reload it and try again.',
      );
    }
    final updated = deployment.copyWith(version: current.version + 1);
    _deployments[deployment.deploymentId] = updated;
    return updated.copyWith();
  }

  @override
  Future<void> delete(String deploymentId) async {
    final deployment = _deployments[deploymentId];
    if (deployment == null) {
      throw DeploymentNotFoundException(
        'Deployment $deploymentId does not exist.',
      );
    }
    if (deployment.status != DeploymentStatus.draft &&
        deployment.status != DeploymentStatus.cancelled) {
      throw StateError('Only Draft or Cancelled deployments may be deleted.');
    }
    _deployments.remove(deploymentId);
  }

  @override
  Future<ServiceDeployment> transitionStatus(
    String deploymentCode,
    DeploymentStatus targetStatus, {
    required String changedByLabel,
    DateTime? changedAt,
  }) async {
    if (changedByLabel.trim().isEmpty) {
      throw const DeploymentValidationException(
        'A staff label is required to change deployment status.',
      );
    }
    final current = _deployments[deploymentCode];
    if (current == null) {
      throw DeploymentNotFoundException(
        'Deployment $deploymentCode does not exist.',
      );
    }
    if (!current.status.canTransitionTo(targetStatus)) {
      throw DeploymentValidationException(
        'Cannot change deployment status from '
        '${current.status.displayLabel} to ${targetStatus.displayLabel}.',
      );
    }
    final updated = current.copyWith(
      status: targetStatus,
      updatedAt: changedAt ?? DateTime.now(),
      version: current.version + 1,
    );
    _validate(updated);
    _deployments[deploymentCode] = updated;
    return updated.copyWith();
  }

  void _validate(ServiceDeployment deployment) {
    final errors = deployment.validate();
    if (errors.isNotEmpty) {
      throw DeploymentValidationException(errors.join(' '));
    }
  }
}
