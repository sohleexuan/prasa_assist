import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../models/incident_status_change.dart';

class IncidentOperationalSnapshot {
  IncidentOperationalSnapshot._({
    required this.incidentId,
    required this.incidentType,
    required this.incidentTypeLabel,
    required this.title,
    required this.description,
    required this.routeId,
    required this.routeName,
    required this.vehicleId,
    required this.location,
    required this.reportedAt,
    required this.severity,
    required this.severityLabel,
    required this.status,
    required this.statusLabel,
    required this.vehicleCondition,
    required this.vehicleConditionLabel,
    required this.disruptionScope,
    required this.disruptionScopeLabel,
    required this.estimatedDelayMinutes,
    required this.impactLevel,
    required this.impactLevelLabel,
    required List<String> estimationReasons,
    required this.reportedBy,
    required this.dataSource,
    required this.dataSourceLabel,
    required this.createdAt,
    required this.updatedAt,
    required List<IncidentStatusSnapshot> statusHistory,
  }) : estimationReasons = List<String>.unmodifiable(estimationReasons),
       statusHistory = List<IncidentStatusSnapshot>.unmodifiable(statusHistory);

  static const int schemaVersion = 1;
  static const bool decisionSupportOnly = true;
  static const bool automaticActionAllowed = false;

  factory IncidentOperationalSnapshot.fromIncident(Incident incident) {
    return IncidentOperationalSnapshot._(
      incidentId: incident.incidentId,
      incidentType: incident.incidentType.name,
      incidentTypeLabel: incident.incidentType.displayLabel,
      title: incident.title,
      description: incident.description,
      routeId: incident.routeId,
      routeName: incident.routeName,
      vehicleId: incident.vehicleId,
      location: incident.location,
      reportedAt: incident.reportedAt,
      severity: incident.severity.name,
      severityLabel: incident.severity.displayLabel,
      status: incident.status.name,
      statusLabel: incident.status.displayLabel,
      vehicleCondition: incident.vehicleCondition.name,
      vehicleConditionLabel: incident.vehicleCondition.displayLabel,
      disruptionScope: incident.disruptionScope.name,
      disruptionScopeLabel: incident.disruptionScope.displayLabel,
      estimatedDelayMinutes: incident.estimatedDelayMinutes,
      impactLevel: incident.impactLevel.name,
      impactLevelLabel: incident.impactLevel.displayLabel,
      estimationReasons: incident.estimationReasons,
      reportedBy: incident.reportedBy,
      dataSource: incident.dataSource.name,
      dataSourceLabel: incident.dataSource.displayLabel,
      createdAt: incident.createdAt,
      updatedAt: incident.updatedAt,
      statusHistory: incident.statusHistory
          .map(IncidentStatusSnapshot.fromStatusChange)
          .toList(growable: false),
    );
  }

  final String incidentId;
  final String incidentType;
  final String incidentTypeLabel;
  final String title;
  final String description;
  final String routeId;
  final String? routeName;
  final String? vehicleId;
  final String location;
  final DateTime reportedAt;
  final String severity;
  final String severityLabel;
  final String status;
  final String statusLabel;
  final String vehicleCondition;
  final String vehicleConditionLabel;
  final String disruptionScope;
  final String disruptionScopeLabel;
  final int estimatedDelayMinutes;
  final String impactLevel;
  final String impactLevelLabel;
  final List<String> estimationReasons;
  final String reportedBy;
  final String dataSource;
  final String dataSourceLabel;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<IncidentStatusSnapshot> statusHistory;

  Map<String, Object?> toJson() {
    return Map<String, Object?>.unmodifiable({
      'schema_version': schemaVersion,
      'decision_support_only': decisionSupportOnly,
      'automatic_action_allowed': automaticActionAllowed,
      'incident_id': incidentId,
      'incident_type': incidentType,
      'incident_type_label': incidentTypeLabel,
      'title': title,
      'description': description,
      'route_id': routeId,
      'route_name': routeName,
      'vehicle_id': vehicleId,
      'location': location,
      'reported_at': reportedAt.toUtc().toIso8601String(),
      'severity': severity,
      'severity_label': severityLabel,
      'status': status,
      'status_label': statusLabel,
      'vehicle_condition': vehicleCondition,
      'vehicle_condition_label': vehicleConditionLabel,
      'disruption_scope': disruptionScope,
      'disruption_scope_label': disruptionScopeLabel,
      'estimated_delay_minutes': estimatedDelayMinutes,
      'impact_level': impactLevel,
      'impact_level_label': impactLevelLabel,
      'estimation_reasons': List<String>.unmodifiable(estimationReasons),
      'reported_by': reportedBy,
      'data_source': dataSource,
      'data_source_label': dataSourceLabel,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'status_history': List<Map<String, Object?>>.unmodifiable(
        statusHistory.map((entry) => entry.toJson()),
      ),
    });
  }
}

class IncidentStatusSnapshot {
  const IncidentStatusSnapshot({
    required this.fromStatus,
    required this.toStatus,
    required this.changedAt,
    required this.changedBy,
    required this.note,
  });

  factory IncidentStatusSnapshot.fromStatusChange(IncidentStatusChange change) {
    return IncidentStatusSnapshot(
      fromStatus: change.fromStatus?.name,
      toStatus: change.toStatus.name,
      changedAt: change.changedAt,
      changedBy: change.changedBy,
      note: change.note,
    );
  }

  final String? fromStatus;
  final String toStatus;
  final DateTime changedAt;
  final String changedBy;
  final String? note;

  Map<String, Object?> toJson() {
    return Map<String, Object?>.unmodifiable({
      'from_status': fromStatus,
      'to_status': toStatus,
      'changed_at': changedAt.toUtc().toIso8601String(),
      'changed_by': changedBy,
      'note': note,
    });
  }
}
