import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/controllers/deployment_controller.dart';
import 'package:prasa_assist/features/deployments/models/deployment_status.dart';
import 'package:prasa_assist/features/deployments/models/service_deployment.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_data_exception.dart';
import 'package:prasa_assist/features/deployments/repositories/in_memory_deployment_repository.dart';

void main() {
  group('DeploymentController', () {
    test('exposes repository capabilities without changing its contract', () {
      final controller = DeploymentController(
        repository: InMemoryDeploymentRepository(),
      );

      expect(controller.capabilities.isPersistent, isFalse);
      expect(controller.capabilities.supportsPhysicalDelete, isTrue);
      expect(controller.capabilities.supportsReset, isTrue);
    });

    test('exposes loading state and an immutable loaded list', () async {
      final repository = _DelayedRepository();
      final controller = DeploymentController(repository: repository);

      final loadFuture = controller.loadDeployments();
      expect(controller.isLoading, isTrue);
      expect(controller.errorMessage, isNull);

      repository.completeGetAll([_deployment()]);
      await loadFuture;

      expect(controller.isLoading, isFalse);
      expect(controller.deployments, [_deployment()]);
      expect(
        () => controller.deployments.add(_deployment(deploymentId: 'OTHER')),
        throwsUnsupportedError,
      );
    });

    test('loads a deployment by ID as the selected deployment', () async {
      final deployment = _deployment();
      final controller = DeploymentController(
        repository: InMemoryDeploymentRepository(seedData: [deployment]),
      );

      final result = await controller.getDeploymentById(
        deployment.deploymentId,
      );

      expect(result, deployment);
      expect(controller.selectedDeployment, deployment);
      expect(controller.errorMessage, isNull);
    });

    test(
      'exposes a useful error when a selected deployment is missing',
      () async {
        final controller = DeploymentController(
          repository: InMemoryDeploymentRepository(),
        );

        expect(await controller.getDeploymentById('MISSING'), isNull);
        expect(controller.errorMessage, contains('does not exist'));
        expect(controller.isLoading, isFalse);
      },
    );

    test('creates, updates, and deletes a Draft deployment', () async {
      final controller = DeploymentController(
        repository: InMemoryDeploymentRepository(),
      );
      final deployment = _deployment();

      expect(await controller.createDeployment(deployment), isTrue);
      expect(controller.deployments, [deployment]);
      expect(controller.selectedDeployment, deployment);

      final updated = deployment.copyWith(
        purpose: 'Updated purpose',
        updatedAt: deployment.updatedAt.add(const Duration(minutes: 1)),
      );
      expect(await controller.updateDeployment(updated), isTrue);
      expect(controller.deployments.single, updated.copyWith(version: 2));

      expect(
        await controller.deleteDeployment(deployment.deploymentId),
        isTrue,
      );
      expect(controller.deployments, isEmpty);
      expect(controller.selectedDeployment, isNull);
      expect(controller.errorMessage, isNull);
    });

    test('catches repository errors and exposes an error message', () async {
      final deployment = _deployment(status: DeploymentStatus.active);
      final controller = DeploymentController(
        repository: InMemoryDeploymentRepository(seedData: [deployment]),
      );

      expect(
        await controller.deleteDeployment(deployment.deploymentId),
        isFalse,
      );
      expect(controller.errorMessage, contains('Only Draft or Cancelled'));
      expect(controller.isLoading, isFalse);
    });

    test('performs each valid status change and updates updatedAt', () async {
      final deployment = _deployment();
      var currentTime = deployment.updatedAt;
      final repository = InMemoryDeploymentRepository(seedData: [deployment]);
      final controller = DeploymentController(
        repository: repository,
        clock: () {
          currentTime = currentTime.add(const Duration(minutes: 1));
          return currentTime;
        },
      );

      for (final nextStatus in const [
        DeploymentStatus.scheduled,
        DeploymentStatus.active,
        DeploymentStatus.completed,
      ]) {
        final previousUpdatedAt = (await repository.getById(
          deployment.deploymentId,
        ))!.updatedAt;

        expect(
          await controller.changeStatus(deployment.deploymentId, nextStatus),
          isTrue,
        );
        final stored = await repository.getById(deployment.deploymentId);
        expect(stored!.status, nextStatus);
        expect(stored.updatedAt.isAfter(previousUpdatedAt), isTrue);
        expect(controller.deployments.single.status, nextStatus);
      }
    });

    test(
      'delegates status changes to the repository atomic operation',
      () async {
        final deployment = _deployment();
        final repository = _TransitionRecordingRepository(
          seedData: [deployment],
        );
        final controller = DeploymentController(repository: repository);
        await controller.getDeploymentById(deployment.deploymentId);

        expect(
          await controller.changeStatus(
            deployment.deploymentId,
            DeploymentStatus.scheduled,
            changedByLabel: 'Control Centre Staff',
          ),
          isTrue,
        );

        expect(repository.transitionCallCount, 1);
        expect(repository.updateCallCount, 0);
        expect(repository.changedByLabel, 'Control Centre Staff');
        expect(controller.selectedDeployment!.version, 2);
      },
    );

    test('exposes offline and conflict failures using safe messages', () async {
      for (final exception in <DeploymentDataException>[
        const DeploymentOfflineException(
          'Deployment data is unavailable while offline.',
        ),
        const DeploymentConflictException(
          'Deployment changed elsewhere. Reload and try again.',
        ),
      ]) {
        final controller = DeploymentController(
          repository: _FailingTransitionRepository(exception),
        );

        expect(
          await controller.changeStatus(
            'DEP-001',
            DeploymentStatus.scheduled,
            changedByLabel: 'Operations Staff',
          ),
          isFalse,
        );
        expect(controller.errorMessage, exception.message);
        expect(controller.selectedDeployment, isNull);
      }
    });

    test('allows cancellation from Draft, Scheduled, and Active', () async {
      for (final status in const [
        DeploymentStatus.draft,
        DeploymentStatus.scheduled,
        DeploymentStatus.active,
      ]) {
        final deployment = _deployment(status: status);
        final repository = InMemoryDeploymentRepository(seedData: [deployment]);
        final controller = DeploymentController(
          repository: repository,
          clock: () => deployment.updatedAt.add(const Duration(minutes: 1)),
        );

        expect(
          await controller.changeStatus(
            deployment.deploymentId,
            DeploymentStatus.cancelled,
          ),
          isTrue,
          reason: '${status.displayLabel} should be cancellable',
        );
        expect(
          (await repository.getById(deployment.deploymentId))!.status,
          DeploymentStatus.cancelled,
        );
      }
    });

    test(
      'rejects an invalid status change without changing stored data',
      () async {
        final deployment = _deployment();
        final repository = InMemoryDeploymentRepository(seedData: [deployment]);
        final controller = DeploymentController(repository: repository);

        expect(
          await controller.changeStatus(
            deployment.deploymentId,
            DeploymentStatus.active,
          ),
          isFalse,
        );
        expect(controller.errorMessage, contains('Draft to Active'));
        expect(
          (await repository.getById(deployment.deploymentId))!.status,
          DeploymentStatus.draft,
        );
      },
    );

    test('completed and cancelled deployments remain terminal', () async {
      for (final status in const [
        DeploymentStatus.completed,
        DeploymentStatus.cancelled,
      ]) {
        final deployment = _deployment(status: status);
        final repository = InMemoryDeploymentRepository(seedData: [deployment]);
        final controller = DeploymentController(repository: repository);

        expect(
          await controller.changeStatus(
            deployment.deploymentId,
            DeploymentStatus.draft,
          ),
          isFalse,
          reason: '${status.displayLabel} must remain terminal',
        );
        expect(controller.errorMessage, isNotNull);
        expect(
          (await repository.getById(deployment.deploymentId))!.status,
          status,
        );
      }
    });
  });
}

class _DelayedRepository extends InMemoryDeploymentRepository {
  final Completer<List<ServiceDeployment>> _getAllCompleter =
      Completer<List<ServiceDeployment>>();

  @override
  Future<List<ServiceDeployment>> getAll() => _getAllCompleter.future;

  void completeGetAll(List<ServiceDeployment> deployments) {
    _getAllCompleter.complete(deployments);
  }
}

class _TransitionRecordingRepository extends InMemoryDeploymentRepository {
  _TransitionRecordingRepository({required super.seedData});

  int transitionCallCount = 0;
  int updateCallCount = 0;
  String? changedByLabel;

  @override
  Future<ServiceDeployment> update(ServiceDeployment deployment) {
    updateCallCount++;
    return super.update(deployment);
  }

  @override
  Future<ServiceDeployment> transitionStatus(
    String deploymentCode,
    DeploymentStatus targetStatus, {
    required String changedByLabel,
    DateTime? changedAt,
  }) {
    transitionCallCount++;
    this.changedByLabel = changedByLabel;
    return super.transitionStatus(
      deploymentCode,
      targetStatus,
      changedByLabel: changedByLabel,
      changedAt: changedAt,
    );
  }
}

class _FailingTransitionRepository extends InMemoryDeploymentRepository {
  _FailingTransitionRepository(this.exception);

  final DeploymentDataException exception;

  @override
  Future<ServiceDeployment> transitionStatus(
    String deploymentCode,
    DeploymentStatus targetStatus, {
    required String changedByLabel,
    DateTime? changedAt,
  }) {
    throw exception;
  }
}

ServiceDeployment _deployment({
  String deploymentId = 'DEP-001',
  DeploymentStatus status = DeploymentStatus.draft,
}) {
  return ServiceDeployment(
    deploymentId: deploymentId,
    routeId: '300',
    routeName: 'Route 300',
    vehicleIds: const ['ABC 1230'],
    startTime: DateTime(2026, 8, 27, 8),
    endTime: DateTime(2026, 8, 27, 10),
    status: status,
    purpose: 'Provide replacement service',
    createdBy: 'Operations Staff',
    createdAt: DateTime(2026, 8, 27, 7, 30),
    updatedAt: DateTime(2026, 8, 27, 7, 45),
  );
}
