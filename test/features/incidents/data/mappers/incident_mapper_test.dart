import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/data/dto/incident_record_dto.dart';
import 'package:prasa_assist/features/incidents/data/mappers/incident_mapper.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';
import 'package:prasa_assist/features/incidents/repositories/incident_data_exception.dart';

void main() {
  const mapper = IncidentMapper();

  test('maps every approved storage enum value to the domain', () {
    const incidentTypes = <String, IncidentType>{
      'vehicle_breakdown': IncidentType.vehicleBreakdown,
      'accident': IncidentType.accident,
      'service_disruption': IncidentType.serviceDisruption,
      'infrastructure_issue': IncidentType.infrastructureIssue,
      'safety_incident': IncidentType.safetyIncident,
      'other': IncidentType.other,
    };
    const severities = <String, IncidentSeverity>{
      'low': IncidentSeverity.low,
      'medium': IncidentSeverity.medium,
      'high': IncidentSeverity.high,
      'critical': IncidentSeverity.critical,
    };
    const vehicleConditions = <String, VehicleCondition>{
      'operational': VehicleCondition.operational,
      'limited_operation': VehicleCondition.limitedOperation,
      'immobilised': VehicleCondition.immobilised,
      'unknown': VehicleCondition.unknown,
    };
    const disruptionScopes = <String, DisruptionScope>{
      'no_obstruction': DisruptionScope.noObstruction,
      'partial_obstruction': DisruptionScope.partialObstruction,
      'full_obstruction': DisruptionScope.fullObstruction,
      'unknown': DisruptionScope.unknown,
    };
    const impactLevels = <String, OperationalImpactLevel>{
      'minor': OperationalImpactLevel.minor,
      'moderate': OperationalImpactLevel.moderate,
      'major': OperationalImpactLevel.major,
      'severe': OperationalImpactLevel.severe,
    };
    const dataSources = <String, IncidentDataSource>{
      'staff_entered': IncidentDataSource.staffEntered,
      'mock_demonstration': IncidentDataSource.mockDemonstration,
      'live_government': IncidentDataSource.liveGovernment,
      'cached_government': IncidentDataSource.cachedGovernment,
      'static_government': IncidentDataSource.staticGovernment,
    };

    for (final entry in incidentTypes.entries) {
      expect(
        mapper.toDomain(_record(incidentType: entry.key)).incidentType,
        entry.value,
      );
    }
    for (final entry in severities.entries) {
      expect(
        mapper.toDomain(_record(severity: entry.key)).severity,
        entry.value,
      );
    }
    for (final entry in vehicleConditions.entries) {
      expect(
        mapper.toDomain(_record(vehicleCondition: entry.key)).vehicleCondition,
        entry.value,
      );
    }
    for (final entry in disruptionScopes.entries) {
      expect(
        mapper.toDomain(_record(disruptionScope: entry.key)).disruptionScope,
        entry.value,
      );
    }
    for (final entry in impactLevels.entries) {
      expect(
        mapper.toDomain(_record(impactLevel: entry.key)).impactLevel,
        entry.value,
      );
    }
    for (final entry in dataSources.entries) {
      expect(
        mapper.toDomain(_record(dataSource: entry.key)).dataSource,
        entry.value,
      );
    }
  });

  test('maps a complete record to the domain and back to storage values', () {
    final domain = mapper.toDomain(
      _record(
        incidentType: 'infrastructure_issue',
        severity: 'critical',
        vehicleCondition: 'limited_operation',
        disruptionScope: 'full_obstruction',
        impactLevel: 'major',
        dataSource: 'static_government',
      ),
    );

    final roundTrip = mapper.toDto(domain);

    expect(roundTrip.incidentType, 'infrastructure_issue');
    expect(roundTrip.severity, 'critical');
    expect(roundTrip.vehicleCondition, 'limited_operation');
    expect(roundTrip.disruptionScope, 'full_obstruction');
    expect(roundTrip.impactLevel, 'major');
    expect(roundTrip.dataSource, 'static_government');
    expect(roundTrip.version, 1);
  });

  test('rejects an unknown database enum value', () {
    expect(
      () => mapper.toDomain(_record(severity: 'catastrophic')),
      throwsA(isA<IncidentMappingException>()),
    );
  });

  test('rejects an unsupported estimator model version', () {
    expect(
      () => mapper.toDomain(_record(estimationModelVersion: 2)),
      throwsA(isA<IncidentMappingException>()),
    );
  });
}

IncidentRecordDto _record({
  String incidentType = 'vehicle_breakdown',
  String severity = 'high',
  String vehicleCondition = 'immobilised',
  String disruptionScope = 'partial_obstruction',
  String impactLevel = 'severe',
  String dataSource = 'staff_entered',
  int estimationModelVersion = 1,
}) => IncidentRecordDto.fromMap(<String, dynamic>{
  'incident_code': 'INC-20260828-002',
  'incident_type': incidentType,
  'title': 'Database mapping test',
  'description': 'A complete Incident record used for database mapping tests.',
  'route_id': '300',
  'route_name': 'Route 300',
  'vehicle_id': 'B1023',
  'location': 'Test location',
  'reported_at': '2026-08-28T00:00:00Z',
  'severity': severity,
  'status': 'reported',
  'vehicle_condition': vehicleCondition,
  'disruption_scope': disruptionScope,
  'estimated_delay_minutes': 75,
  'impact_level': impactLevel,
  'estimation_reasons': ['Mapping test reason.'],
  'estimation_model_version': estimationModelVersion,
  'data_source': dataSource,
  'reported_by_label': 'staff@example.com',
  'created_at': '2026-08-28T00:05:00Z',
  'updated_at': '2026-08-28T00:05:00Z',
  'version': 1,
  'incident_status_history': [
    {
      'sequence_no': 1,
      'from_status': null,
      'to_status': 'reported',
      'changed_at': '2026-08-28T00:05:00Z',
      'changed_by_label': 'staff@example.com',
      'note': null,
    },
  ],
});
