import '../../models/delay_estimate.dart';
import '../../models/incident.dart';
import '../../models/incident_enums.dart';
import '../../models/incident_status_change.dart';
import '../../repositories/incident_data_exception.dart';
import '../../services/incident_validator.dart';
import '../dto/incident_record_dto.dart';

class IncidentMapper {
  const IncidentMapper();

  Incident toDomain(IncidentRecordDto record) {
    if (record.estimationModelVersion != 1) {
      throw IncidentMappingException(
        'Incident ${record.incidentCode} uses an unsupported estimation model.',
      );
    }
    return Incident(
      incidentId: record.incidentCode,
      incidentType: _incidentTypeFromStorage(record.incidentType),
      title: record.title,
      description: record.description,
      routeId: record.routeId,
      routeName: record.routeName,
      vehicleId: record.vehicleId,
      location: record.location,
      reportedAt: record.reportedAt,
      severity: _severityFromStorage(record.severity),
      status: _statusFromStorage(record.status),
      vehicleCondition: _vehicleConditionFromStorage(record.vehicleCondition),
      disruptionScope: _disruptionScopeFromStorage(record.disruptionScope),
      delayEstimate: DelayEstimate(
        estimatedDelayMinutes: record.estimatedDelayMinutes,
        impactLevel: _impactFromStorage(record.impactLevel),
        reasons: record.estimationReasons,
      ),
      reportedBy: record.reportedByLabel,
      dataSource: _dataSourceFromStorage(record.dataSource),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      statusHistory: record.statusHistory
          .map(
            (change) => IncidentStatusChange(
              fromStatus: change.fromStatus == null
                  ? null
                  : _statusFromStorage(change.fromStatus!),
              toStatus: _statusFromStorage(change.toStatus),
              changedAt: change.changedAt,
              changedBy: change.changedByLabel,
              note: change.note,
            ),
          )
          .toList(growable: false),
      version: record.version,
    );
  }

  IncidentRecordDto toDto(Incident incident) {
    final issues = IncidentValidator.validate(incident);
    if (issues.isNotEmpty) {
      throw IncidentValidationException(
        issues.map((issue) => issue.message).join(' '),
        issues: issues,
      );
    }
    return IncidentRecordDto(
      incidentCode: incident.incidentId,
      incidentType: _incidentTypeToStorage(incident.incidentType),
      title: incident.title,
      description: incident.description,
      routeId: incident.routeId,
      routeName: incident.routeName,
      vehicleId: incident.vehicleId,
      location: incident.location,
      reportedAt: incident.reportedAt,
      severity: _severityToStorage(incident.severity),
      status: _statusToStorage(incident.status),
      vehicleCondition: _vehicleConditionToStorage(incident.vehicleCondition),
      disruptionScope: _disruptionScopeToStorage(incident.disruptionScope),
      estimatedDelayMinutes: incident.estimatedDelayMinutes,
      impactLevel: _impactToStorage(incident.impactLevel),
      estimationReasons: incident.estimationReasons,
      estimationModelVersion: 1,
      dataSource: _dataSourceToStorage(incident.dataSource),
      reportedByLabel: incident.reportedBy,
      createdAt: incident.createdAt,
      updatedAt: incident.updatedAt,
      version: incident.version,
      statusHistory: [
        for (var index = 0; index < incident.statusHistory.length; index++)
          IncidentStatusRecordDto(
            sequenceNumber: index + 1,
            fromStatus: incident.statusHistory[index].fromStatus == null
                ? null
                : _statusToStorage(incident.statusHistory[index].fromStatus!),
            toStatus: _statusToStorage(incident.statusHistory[index].toStatus),
            changedAt: incident.statusHistory[index].changedAt,
            changedByLabel: incident.statusHistory[index].changedBy,
            note: incident.statusHistory[index].note,
          ),
      ],
    );
  }

  IncidentType _incidentTypeFromStorage(String value) => switch (value) {
    'vehicle_breakdown' => IncidentType.vehicleBreakdown,
    'accident' => IncidentType.accident,
    'service_disruption' => IncidentType.serviceDisruption,
    'infrastructure_issue' => IncidentType.infrastructureIssue,
    'safety_incident' => IncidentType.safetyIncident,
    'other' => IncidentType.other,
    _ => throw IncidentMappingException('Unknown incident type "$value".'),
  };

  String _incidentTypeToStorage(IncidentType value) => switch (value) {
    IncidentType.vehicleBreakdown => 'vehicle_breakdown',
    IncidentType.accident => 'accident',
    IncidentType.serviceDisruption => 'service_disruption',
    IncidentType.infrastructureIssue => 'infrastructure_issue',
    IncidentType.safetyIncident => 'safety_incident',
    IncidentType.other => 'other',
  };

  IncidentSeverity _severityFromStorage(String value) => switch (value) {
    'low' => IncidentSeverity.low,
    'medium' => IncidentSeverity.medium,
    'high' => IncidentSeverity.high,
    'critical' => IncidentSeverity.critical,
    _ => throw IncidentMappingException('Unknown incident severity "$value".'),
  };

  String _severityToStorage(IncidentSeverity value) => value.name;

  IncidentStatus _statusFromStorage(String value) => switch (value) {
    'reported' => IncidentStatus.reported,
    'under_review' => IncidentStatus.underReview,
    'active' => IncidentStatus.active,
    'resolved' => IncidentStatus.resolved,
    'cancelled' => IncidentStatus.cancelled,
    _ => throw IncidentMappingException('Unknown incident status "$value".'),
  };

  String _statusToStorage(IncidentStatus value) => switch (value) {
    IncidentStatus.reported => 'reported',
    IncidentStatus.underReview => 'under_review',
    IncidentStatus.active => 'active',
    IncidentStatus.resolved => 'resolved',
    IncidentStatus.cancelled => 'cancelled',
  };

  VehicleCondition _vehicleConditionFromStorage(String value) =>
      switch (value) {
        'operational' => VehicleCondition.operational,
        'limited_operation' => VehicleCondition.limitedOperation,
        'immobilised' => VehicleCondition.immobilised,
        'unknown' => VehicleCondition.unknown,
        _ => throw IncidentMappingException(
          'Unknown vehicle condition "$value".',
        ),
      };

  String _vehicleConditionToStorage(VehicleCondition value) => switch (value) {
    VehicleCondition.operational => 'operational',
    VehicleCondition.limitedOperation => 'limited_operation',
    VehicleCondition.immobilised => 'immobilised',
    VehicleCondition.unknown => 'unknown',
  };

  DisruptionScope _disruptionScopeFromStorage(String value) => switch (value) {
    'no_obstruction' => DisruptionScope.noObstruction,
    'partial_obstruction' => DisruptionScope.partialObstruction,
    'full_obstruction' => DisruptionScope.fullObstruction,
    'unknown' => DisruptionScope.unknown,
    _ => throw IncidentMappingException('Unknown disruption scope "$value".'),
  };

  String _disruptionScopeToStorage(DisruptionScope value) => switch (value) {
    DisruptionScope.noObstruction => 'no_obstruction',
    DisruptionScope.partialObstruction => 'partial_obstruction',
    DisruptionScope.fullObstruction => 'full_obstruction',
    DisruptionScope.unknown => 'unknown',
  };

  OperationalImpactLevel _impactFromStorage(String value) => switch (value) {
    'minor' => OperationalImpactLevel.minor,
    'moderate' => OperationalImpactLevel.moderate,
    'major' => OperationalImpactLevel.major,
    'severe' => OperationalImpactLevel.severe,
    _ => throw IncidentMappingException('Unknown impact level "$value".'),
  };

  String _impactToStorage(OperationalImpactLevel value) => value.name;

  IncidentDataSource _dataSourceFromStorage(String value) => switch (value) {
    'staff_entered' => IncidentDataSource.staffEntered,
    'mock_demonstration' => IncidentDataSource.mockDemonstration,
    'live_government' => IncidentDataSource.liveGovernment,
    'cached_government' => IncidentDataSource.cachedGovernment,
    'static_government' => IncidentDataSource.staticGovernment,
    _ => throw IncidentMappingException(
      'Unknown incident data source "$value".',
    ),
  };

  String _dataSourceToStorage(IncidentDataSource value) => switch (value) {
    IncidentDataSource.staffEntered => 'staff_entered',
    IncidentDataSource.mockDemonstration => 'mock_demonstration',
    IncidentDataSource.liveGovernment => 'live_government',
    IncidentDataSource.cachedGovernment => 'cached_government',
    IncidentDataSource.staticGovernment => 'static_government',
  };
}
