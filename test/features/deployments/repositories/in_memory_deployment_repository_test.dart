import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/models/deployment_status.dart';
import 'package:prasa_assist/features/deployments/models/service_deployment.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_data_exception.dart';
import 'package:prasa_assist/features/deployments/repositories/in_memory_deployment_repository.dart';

void main() {
  group('InMemoryDeploymentRepository', () {
    test(
      'provides clearly identified shared-scenario demonstration data',
      () async {
        final repository = InMemoryDeploymentRepository.withDemonstrationData();

        final deployments = await repository.getAll();

        expect(deployments, hasLength(1));
        expect(deployments.single.deploymentId, 'DEP-120');
        expect(deployments.single.routeId, '300');
        expect(deployments.single.routeName, 'Route 300');
        expect(deployments.single.vehicleIds, ['ABC 1230', 'DEF 4567']);
        expect(deployments.single.incidentId, 'INC-2026-0142');
        expect(deployments.single.sourceRecommendationId, 'REC-0088');
        expect(deployments.single.status, DeploymentStatus.scheduled);
        expect(deployments.single.validate(), isEmpty);
      },
    );

    test('creates and retrieves a deployment by ID', () async {
      final repository = InMemoryDeploymentRepository();
      final deployment = _deployment();

      await repository.create(deployment);

      expect(await repository.getById(deployment.deploymentId), deployment);
      expect(await repository.getById('MISSING'), isNull);
    });

    test('rejects duplicate deployment IDs', () async {
      final repository = InMemoryDeploymentRepository();
      await repository.create(_deployment());

      await expectLater(
        repository.create(_deployment(purpose: 'Duplicate deployment')),
        throwsA(
          isA<DeploymentDuplicateException>().having(
            (error) => error.message,
            'message',
            contains('already exists'),
          ),
        ),
      );
    });

    test('updates an existing deployment', () async {
      final repository = InMemoryDeploymentRepository();
      final deployment = _deployment();
      await repository.create(deployment);

      final updated = deployment.copyWith(
        purpose: 'Updated operational purpose',
        updatedAt: deployment.updatedAt.add(const Duration(minutes: 5)),
      );
      final result = await repository.update(updated);

      expect(result, updated.copyWith(version: 2));
      expect(await repository.getById(deployment.deploymentId), result);
    });

    test(
      'rejects a stale update version without changing stored data',
      () async {
        final repository = InMemoryDeploymentRepository(
          seedData: [_deployment().copyWith(version: 2)],
        );

        await expectLater(
          repository.update(_deployment(version: 1)),
          throwsA(isA<DeploymentConflictException>()),
        );

        expect((await repository.getById('DEP-001'))!.version, 2);
      },
    );

    test('atomically transitions status and increments version', () async {
      final repository = InMemoryDeploymentRepository(
        seedData: [_deployment()],
      );
      final changedAt = DateTime(2026, 8, 27, 8);

      final transitioned = await repository.transitionStatus(
        'DEP-001',
        DeploymentStatus.scheduled,
        changedByLabel: 'Operations Staff',
        changedAt: changedAt,
      );

      expect(transitioned.status, DeploymentStatus.scheduled);
      expect(transitioned.updatedAt, changedAt);
      expect(transitioned.version, 2);
      expect((await repository.getById('DEP-001'))!.version, 2);
    });

    test('rejects update for a missing deployment', () async {
      final repository = InMemoryDeploymentRepository();

      await expectLater(
        repository.update(_deployment()),
        throwsA(
          isA<DeploymentNotFoundException>().having(
            (error) => error.message,
            'message',
            contains('does not exist'),
          ),
        ),
      );
    });

    test('rejects delete for a missing deployment', () async {
      final repository = InMemoryDeploymentRepository();

      await expectLater(
        repository.delete('MISSING'),
        throwsA(
          isA<DeploymentNotFoundException>().having(
            (error) => error.message,
            'message',
            contains('does not exist'),
          ),
        ),
      );
    });

    test('allows Draft and Cancelled deployments to be deleted', () async {
      final repository = InMemoryDeploymentRepository(
        seedData: [
          _deployment(deploymentId: 'DRAFT'),
          _deployment(
            deploymentId: 'CANCELLED',
            status: DeploymentStatus.cancelled,
          ),
        ],
      );

      await repository.delete('DRAFT');
      await repository.delete('CANCELLED');

      expect(await repository.getAll(), isEmpty);
    });

    test(
      'rejects deletion of Scheduled, Active, and Completed deployments',
      () async {
        for (final status in const [
          DeploymentStatus.scheduled,
          DeploymentStatus.active,
          DeploymentStatus.completed,
        ]) {
          final repository = InMemoryDeploymentRepository(
            seedData: [_deployment(status: status)],
          );

          await expectLater(
            repository.delete('DEP-001'),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                contains('Only Draft or Cancelled'),
              ),
            ),
            reason: '${status.displayLabel} must not be deleted',
          );
        }
      },
    );

    test('validates deployments before create and update', () async {
      final repository = InMemoryDeploymentRepository();

      await expectLater(
        repository.create(_deployment(routeId: '')),
        throwsA(
          isA<DeploymentValidationException>().having(
            (error) => error.message,
            'message',
            contains('Route ID is required.'),
          ),
        ),
      );

      final validDeployment = _deployment();
      await repository.create(validDeployment);
      await expectLater(
        repository.update(validDeployment.copyWith(vehicleIds: const [])),
        throwsA(
          isA<DeploymentValidationException>().having(
            (error) => error.message,
            'message',
            contains('At least one vehicle must be selected.'),
          ),
        ),
      );
    });

    test('returns copies in an unmodifiable collection', () async {
      final seed = _deployment();
      final repository = InMemoryDeploymentRepository(seedData: [seed]);

      final firstResult = await repository.getAll();
      final secondResult = await repository.getAll();

      expect(() => firstResult.add(_deployment()), throwsUnsupportedError);
      expect(
        () => firstResult.single.vehicleIds.add('NEW'),
        throwsUnsupportedError,
      );
      expect(identical(firstResult.single, seed), isFalse);
      expect(identical(firstResult.single, secondResult.single), isFalse);
      expect(firstResult.single, secondResult.single);
    });

    test('rejects duplicate IDs in seed data', () {
      expect(
        () => InMemoryDeploymentRepository(
          seedData: [_deployment(), _deployment()],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

ServiceDeployment _deployment({
  String deploymentId = 'DEP-001',
  String routeId = '300',
  DeploymentStatus status = DeploymentStatus.draft,
  String purpose = 'Provide replacement service',
  int version = 1,
}) {
  return ServiceDeployment(
    deploymentId: deploymentId,
    routeId: routeId,
    routeName: 'Route 300',
    vehicleIds: const ['ABC 1230'],
    startTime: DateTime(2026, 8, 27, 8),
    endTime: DateTime(2026, 8, 27, 10),
    status: status,
    purpose: purpose,
    createdBy: 'Operations Staff',
    createdAt: DateTime(2026, 8, 27, 7, 30),
    updatedAt: DateTime(2026, 8, 27, 7, 45),
    version: version,
  );
}
