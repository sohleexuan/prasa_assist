import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/models/delay_estimate.dart';
import 'package:prasa_assist/features/incidents/models/incident.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';
import 'package:prasa_assist/features/incidents/models/incident_status_change.dart';

void main() {
  group('Incident', () {
    test('exposes delay estimate values directly', () {
      final incident = _incident();

      expect(incident.estimatedDelayMinutes, 75);
      expect(incident.impactLevel, OperationalImpactLevel.severe);
      expect(incident.estimationReasons, hasLength(2));
    });

    test('keeps status history immutable', () {
      final createdAt = DateTime(2026, 8, 28, 8);
      final originalHistory = [_initialStatus(createdAt)];
      final incident = _incident(
        createdAt: createdAt,
        updatedAt: createdAt,
        statusHistory: originalHistory,
      );

      originalHistory.add(
        IncidentStatusChange(
          fromStatus: IncidentStatus.reported,
          toStatus: IncidentStatus.cancelled,
          changedAt: createdAt.add(const Duration(minutes: 1)),
          changedBy: 'Operations Staff',
        ),
      );

      expect(incident.statusHistory, hasLength(1));
      expect(
        () => incident.statusHistory.add(_initialStatus(createdAt)),
        throwsUnsupportedError,
      );
    });

    test('copyWith changes requested values and preserves the rest', () {
      final original = _incident();
      final updatedAt = original.updatedAt.add(const Duration(minutes: 5));
      final copy = original.copyWith(
        title: 'Updated breakdown report',
        severity: IncidentSeverity.critical,
        updatedAt: updatedAt,
      );

      expect(copy.incidentId, original.incidentId);
      expect(copy.title, 'Updated breakdown report');
      expect(copy.severity, IncidentSeverity.critical);
      expect(copy.updatedAt, updatedAt);
      expect(copy.routeName, original.routeName);
      expect(copy.vehicleId, original.vehicleId);
      expect(original.title, 'Bus B1023 breakdown');
    });

    test('copyWith can explicitly clear nullable values', () {
      final copy = _incident().copyWith(routeName: null, vehicleId: null);

      expect(copy.routeName, isNull);
      expect(copy.vehicleId, isNull);
    });

    test('implements value equality and matching hash codes', () {
      final first = _incident();
      final equalCopy = first.copyWith();

      expect(equalCopy, first);
      expect(equalCopy.hashCode, first.hashCode);
      expect(first.copyWith(routeId: '301'), isNot(first));
    });
  });
}

Incident _incident({
  DateTime? createdAt,
  DateTime? updatedAt,
  List<IncidentStatusChange>? statusHistory,
}) {
  final creationTime = createdAt ?? DateTime(2026, 8, 28, 8);
  return Incident(
    incidentId: 'INC-20260828-001',
    incidentType: IncidentType.vehicleBreakdown,
    title: 'Bus B1023 breakdown',
    description: 'Bus B1023 became immobilised while operating Route 300.',
    routeId: '300',
    routeName: 'Route 300',
    vehicleId: 'B1023',
    location: 'Route 300 demonstration location',
    reportedAt: DateTime(2026, 8, 28, 7, 55),
    severity: IncidentSeverity.high,
    status: IncidentStatus.reported,
    vehicleCondition: VehicleCondition.immobilised,
    disruptionScope: DisruptionScope.partialObstruction,
    delayEstimate: DelayEstimate(
      estimatedDelayMinutes: 75,
      impactLevel: OperationalImpactLevel.severe,
      reasons: const [
        'Vehicle breakdown and impact inputs contributed 60 minutes.',
        'The demonstration peak-hour factor increased the estimate by 25%.',
      ],
    ),
    reportedBy: 'Leong Yong Quan',
    dataSource: IncidentDataSource.mockDemonstration,
    createdAt: creationTime,
    updatedAt: updatedAt ?? creationTime,
    statusHistory: statusHistory ?? [_initialStatus(creationTime)],
  );
}

IncidentStatusChange _initialStatus(DateTime changedAt) {
  return IncidentStatusChange(
    fromStatus: null,
    toStatus: IncidentStatus.reported,
    changedAt: changedAt,
    changedBy: 'Leong Yong Quan',
    note: 'Demonstration incident created.',
  );
}
