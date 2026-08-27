import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/models/deployment_status.dart';
import 'package:prasa_assist/features/deployments/models/service_deployment.dart';

void main() {
  group('DeploymentStatus', () {
    test('provides user-facing labels', () {
      expect(DeploymentStatus.draft.displayLabel, 'Draft');
      expect(DeploymentStatus.scheduled.displayLabel, 'Scheduled');
      expect(DeploymentStatus.active.displayLabel, 'Active');
      expect(DeploymentStatus.completed.displayLabel, 'Completed');
      expect(DeploymentStatus.cancelled.displayLabel, 'Cancelled');
    });

    test('allows every specified transition', () {
      const validTransitions = <(DeploymentStatus, DeploymentStatus)>[
        (DeploymentStatus.draft, DeploymentStatus.scheduled),
        (DeploymentStatus.draft, DeploymentStatus.cancelled),
        (DeploymentStatus.scheduled, DeploymentStatus.active),
        (DeploymentStatus.scheduled, DeploymentStatus.cancelled),
        (DeploymentStatus.active, DeploymentStatus.completed),
        (DeploymentStatus.active, DeploymentStatus.cancelled),
      ];

      for (final transition in validTransitions) {
        expect(
          transition.$1.canTransitionTo(transition.$2),
          isTrue,
          reason:
              '${transition.$1.displayLabel} should transition to '
              '${transition.$2.displayLabel}',
        );
      }
    });

    test('rejects every unspecified transition', () {
      const validTransitions = <(DeploymentStatus, DeploymentStatus)>{
        (DeploymentStatus.draft, DeploymentStatus.scheduled),
        (DeploymentStatus.draft, DeploymentStatus.cancelled),
        (DeploymentStatus.scheduled, DeploymentStatus.active),
        (DeploymentStatus.scheduled, DeploymentStatus.cancelled),
        (DeploymentStatus.active, DeploymentStatus.completed),
        (DeploymentStatus.active, DeploymentStatus.cancelled),
      };

      for (final currentStatus in DeploymentStatus.values) {
        for (final nextStatus in DeploymentStatus.values) {
          if (!validTransitions.contains((currentStatus, nextStatus))) {
            expect(
              currentStatus.canTransitionTo(nextStatus),
              isFalse,
              reason:
                  '${currentStatus.displayLabel} must not transition to '
                  '${nextStatus.displayLabel}',
            );
          }
        }
      }
    });

    test('identifies only completed and cancelled as terminal', () {
      expect(DeploymentStatus.draft.isTerminal, isFalse);
      expect(DeploymentStatus.scheduled.isTerminal, isFalse);
      expect(DeploymentStatus.active.isTerminal, isFalse);
      expect(DeploymentStatus.completed.isTerminal, isTrue);
      expect(DeploymentStatus.cancelled.isTerminal, isTrue);
    });
  });

  group('ServiceDeployment', () {
    test('derives vehicle count from immutable vehicle IDs', () {
      final originalVehicleIds = ['ABC 1230', 'DEF 4567'];
      final deployment = _deployment(vehicleIds: originalVehicleIds);

      originalVehicleIds.add('GHI 8901');

      expect(deployment.vehicleCount, 2);
      expect(deployment.vehicleIds, ['ABC 1230', 'DEF 4567']);
      expect(
        () => deployment.vehicleIds.add('GHI 8901'),
        throwsUnsupportedError,
      );
    });

    test('valid deployment returns no validation messages', () {
      expect(_deployment().validate(), isEmpty);
    });

    test('validates all required text fields', () {
      expect(
        _deployment(deploymentId: ' ').validate(),
        contains('Deployment ID is required.'),
      );
      expect(
        _deployment(routeId: '').validate(),
        contains('Route ID is required.'),
      );
      expect(
        _deployment(routeName: '  ').validate(),
        contains('Route name is required.'),
      );
      expect(
        _deployment(purpose: '').validate(),
        contains('Purpose is required.'),
      );
      expect(
        _deployment(createdBy: ' ').validate(),
        contains('Created by is required.'),
      );
    });

    test('requires at least one vehicle', () {
      expect(
        _deployment(vehicleIds: const []).validate(),
        contains('At least one vehicle must be selected.'),
      );
    });

    test('rejects blank vehicle IDs', () {
      expect(
        _deployment(vehicleIds: const ['ABC 1230', ' ']).validate(),
        contains('Vehicle IDs cannot be empty.'),
      );
    });

    test('rejects duplicate normalized vehicle IDs', () {
      expect(
        _deployment(vehicleIds: const ['ABC 1230', ' ABC 1230 ']).validate(),
        contains('Vehicle IDs cannot contain duplicates.'),
      );
    });

    test('requires end time to be after start time', () {
      final startTime = DateTime(2026, 8, 27, 8);

      expect(
        _deployment(startTime: startTime, endTime: startTime).validate(),
        contains('End time must be after start time.'),
      );
      expect(
        _deployment(
          startTime: startTime,
          endTime: startTime.subtract(const Duration(minutes: 1)),
        ).validate(),
        contains('End time must be after start time.'),
      );
    });

    test('requires updated time not to precede created time', () {
      final createdAt = DateTime(2026, 8, 27, 7, 30);

      expect(
        _deployment(
          createdAt: createdAt,
          updatedAt: createdAt.subtract(const Duration(seconds: 1)),
        ).validate(),
        contains('Updated time cannot be earlier than created time.'),
      );
    });

    test('rejects blank optional integration IDs', () {
      expect(
        _deployment(incidentId: ' ').validate(),
        contains('Incident ID cannot be blank when provided.'),
      );
      expect(
        _deployment(sourceRecommendationId: '').validate(),
        contains('Source recommendation ID cannot be blank when provided.'),
      );
    });

    test('defaults version to 1 and rejects versions below 1', () {
      expect(_deployment().version, 1);
      expect(
        _deployment(version: 0).validate(),
        contains('Version must be at least 1.'),
      );
    });

    test('copyWith changes requested values and preserves the rest', () {
      final original = _deployment();
      final newUpdatedAt = original.updatedAt.add(const Duration(minutes: 5));
      final copy = original.copyWith(
        routeId: '301',
        routeName: 'Route 301',
        vehicleIds: const ['GHI 8901'],
        status: DeploymentStatus.scheduled,
        updatedAt: newUpdatedAt,
        version: 4,
      );

      expect(copy.deploymentId, original.deploymentId);
      expect(copy.routeId, '301');
      expect(copy.routeName, 'Route 301');
      expect(copy.vehicleIds, ['GHI 8901']);
      expect(copy.status, DeploymentStatus.scheduled);
      expect(copy.updatedAt, newUpdatedAt);
      expect(copy.version, 4);
      expect(copy.incidentId, original.incidentId);
      expect(copy.sourceRecommendationId, original.sourceRecommendationId);
      expect(original.routeId, '300');
    });

    test('copyWith can explicitly clear nullable integration IDs', () {
      final copy = _deployment().copyWith(
        incidentId: null,
        sourceRecommendationId: null,
      );

      expect(copy.incidentId, isNull);
      expect(copy.sourceRecommendationId, isNull);
    });

    test('implements value equality and matching hash codes', () {
      final first = _deployment();
      final equalCopy = first.copyWith();

      expect(equalCopy, first);
      expect(equalCopy.hashCode, first.hashCode);
      expect(first.copyWith(purpose: 'Different purpose'), isNot(first));
      expect(first.copyWith(version: 2), isNot(first));
    });
  });
}

ServiceDeployment _deployment({
  String deploymentId = 'DEP-001',
  String routeId = '300',
  String routeName = 'Route 300',
  List<String> vehicleIds = const ['ABC 1230', 'DEF 4567'],
  DateTime? startTime,
  DateTime? endTime,
  DeploymentStatus status = DeploymentStatus.draft,
  String purpose = 'Provide replacement service',
  String createdBy = 'Operations Staff',
  DateTime? createdAt,
  DateTime? updatedAt,
  int version = 1,
  String? incidentId = 'INC-001',
  String? sourceRecommendationId = 'REC-001',
}) {
  return ServiceDeployment(
    deploymentId: deploymentId,
    routeId: routeId,
    routeName: routeName,
    vehicleIds: vehicleIds,
    startTime: startTime ?? DateTime(2026, 8, 27, 8),
    endTime: endTime ?? DateTime(2026, 8, 27, 10),
    status: status,
    purpose: purpose,
    createdBy: createdBy,
    createdAt: createdAt ?? DateTime(2026, 8, 27, 7, 30),
    updatedAt: updatedAt ?? DateTime(2026, 8, 27, 7, 45),
    version: version,
    incidentId: incidentId,
    sourceRecommendationId: sourceRecommendationId,
  );
}
