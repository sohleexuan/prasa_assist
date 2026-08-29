import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';
import 'package:prasa_assist/features/incidents/services/incident_report_factory.dart';

void main() {
  const factory = IncidentReportFactory();
  final now = DateTime(2026, 8, 28, 8);

  test('builds a normalized staff-entered Reported incident', () {
    final incident = factory.create(
      incidentId: ' INC-001 ',
      incidentType: IncidentType.vehicleBreakdown,
      title: ' Bus B1023 breakdown ',
      description: ' Bus cannot continue operating. ',
      routeId: ' 300 ',
      routeName: ' Route 300 ',
      vehicleId: ' B1023 ',
      location: ' Jalan Ampang ',
      reportedAt: now,
      severity: IncidentSeverity.high,
      vehicleCondition: VehicleCondition.immobilised,
      disruptionScope: DisruptionScope.partialObstruction,
      reportedBy: ' staff-001 ',
      createdAt: now,
    );

    expect(incident.incidentId, 'INC-001');
    expect(incident.title, 'Bus B1023 breakdown');
    expect(incident.routeId, '300');
    expect(incident.routeName, 'Route 300');
    expect(incident.vehicleId, 'B1023');
    expect(incident.reportedBy, 'staff-001');
    expect(incident.dataSource, IncidentDataSource.staffEntered);
    expect(incident.status, IncidentStatus.reported);
    expect(incident.statusHistory, hasLength(1));
    expect(incident.statusHistory.single.fromStatus, isNull);
    expect(incident.statusHistory.single.toStatus, IncidentStatus.reported);
    expect(incident.statusHistory.single.changedBy, 'staff-001');
  });

  test('uses the explainable estimator for the shared demonstration case', () {
    final incident = factory.create(
      incidentId: 'INC-002',
      incidentType: IncidentType.vehicleBreakdown,
      title: 'Bus B1023 breakdown',
      description: 'Bus cannot continue operating.',
      routeId: '300',
      routeName: 'Route 300',
      vehicleId: 'B1023',
      location: 'Jalan Ampang',
      reportedAt: now,
      severity: IncidentSeverity.high,
      vehicleCondition: VehicleCondition.immobilised,
      disruptionScope: DisruptionScope.partialObstruction,
      reportedBy: 'staff-001',
      createdAt: now,
    );

    expect(incident.estimatedDelayMinutes, 75);
    expect(incident.impactLevel, OperationalImpactLevel.severe);
    expect(incident.estimationReasons, isNotEmpty);
  });

  test('converts blank optional route and vehicle values to null', () {
    final incident = factory.create(
      incidentId: 'INC-003',
      incidentType: IncidentType.serviceDisruption,
      title: 'Service disruption',
      description: 'Service is operating with delays.',
      routeId: '300',
      routeName: '   ',
      vehicleId: '',
      location: 'Jalan Ampang',
      reportedAt: now,
      severity: IncidentSeverity.medium,
      vehicleCondition: VehicleCondition.unknown,
      disruptionScope: DisruptionScope.unknown,
      reportedBy: 'staff-001',
      createdAt: now,
    );

    expect(incident.routeName, isNull);
    expect(incident.vehicleId, isNull);
  });

  test('default ID contains a sortable local timestamp and milliseconds', () {
    expect(
      IncidentReportFactory.defaultId(DateTime(2026, 8, 28, 9, 7, 6, 5)),
      'INC-20260828-090706005',
    );
  });
}
