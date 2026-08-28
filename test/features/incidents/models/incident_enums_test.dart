import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';

void main() {
  group('Incident enums', () {
    test('provide user-facing labels', () {
      expect(IncidentType.vehicleBreakdown.displayLabel, 'Vehicle Breakdown');
      expect(IncidentSeverity.critical.displayLabel, 'Critical');
      expect(IncidentStatus.underReview.displayLabel, 'Under Review');
      expect(
        VehicleCondition.limitedOperation.displayLabel,
        'Limited Operation',
      );
      expect(
        DisruptionScope.partialObstruction.displayLabel,
        'Partial Obstruction',
      );
      expect(OperationalImpactLevel.severe.displayLabel, 'Severe');
      expect(
        IncidentDataSource.mockDemonstration.displayLabel,
        'Mock / Demonstration Data',
      );
    });

    test('requires vehicle IDs only for vehicle-related incident types', () {
      expect(IncidentType.vehicleBreakdown.requiresVehicleId, isTrue);
      expect(IncidentType.accident.requiresVehicleId, isTrue);
      expect(IncidentType.serviceDisruption.requiresVehicleId, isFalse);
      expect(IncidentType.infrastructureIssue.requiresVehicleId, isFalse);
      expect(IncidentType.safetyIncident.requiresVehicleId, isFalse);
      expect(IncidentType.other.requiresVehicleId, isFalse);
    });

    test('orders severity from low to critical', () {
      expect(IncidentSeverity.values.map((severity) => severity.priority), [
        0,
        1,
        2,
        3,
      ]);
    });
  });

  group('IncidentStatus', () {
    test('allows every agreed transition', () {
      const validTransitions = <(IncidentStatus, IncidentStatus)>[
        (IncidentStatus.reported, IncidentStatus.underReview),
        (IncidentStatus.reported, IncidentStatus.cancelled),
        (IncidentStatus.underReview, IncidentStatus.active),
        (IncidentStatus.underReview, IncidentStatus.cancelled),
        (IncidentStatus.active, IncidentStatus.resolved),
        (IncidentStatus.active, IncidentStatus.cancelled),
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
      const validTransitions = <(IncidentStatus, IncidentStatus)>{
        (IncidentStatus.reported, IncidentStatus.underReview),
        (IncidentStatus.reported, IncidentStatus.cancelled),
        (IncidentStatus.underReview, IncidentStatus.active),
        (IncidentStatus.underReview, IncidentStatus.cancelled),
        (IncidentStatus.active, IncidentStatus.resolved),
        (IncidentStatus.active, IncidentStatus.cancelled),
      };

      for (final currentStatus in IncidentStatus.values) {
        for (final nextStatus in IncidentStatus.values) {
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

    test('identifies terminal and deletable statuses', () {
      expect(IncidentStatus.reported.isTerminal, isFalse);
      expect(IncidentStatus.active.isTerminal, isFalse);
      expect(IncidentStatus.resolved.isTerminal, isTrue);
      expect(IncidentStatus.cancelled.isTerminal, isTrue);

      expect(IncidentStatus.reported.canBeDeleted, isTrue);
      expect(IncidentStatus.cancelled.canBeDeleted, isTrue);
      expect(IncidentStatus.underReview.canBeDeleted, isFalse);
      expect(IncidentStatus.active.canBeDeleted, isFalse);
      expect(IncidentStatus.resolved.canBeDeleted, isFalse);
    });
  });
}
