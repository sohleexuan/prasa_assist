import '../models/incident.dart';
import '../models/incident_enums.dart';

/// Versioned, immutable Module 1 facts prepared for a future recommendation
/// hand-off.
///
/// This DTO contains only approved Incident facts. It does not create a
/// recommendation, authorise an operational action, or depend on Module 4.
class M1IncidentRecommendationFacts {
  M1IncidentRecommendationFacts._({
    required this.incidentId,
    required this.vehicleId,
    required this.routeId,
    required this.incidentType,
    required this.severity,
    required this.status,
    required this.incidentTimeUtc,
    required this.vehicleCondition,
    required this.disruptionScope,
    required this.estimatedDelayMinutes,
    required this.impactLevel,
    required this.incidentDataClassification,
    required this.delayEstimateClassification,
    required this.generatedAtUtc,
  });

  static const int schemaVersion = 1;
  static const String demonstrationRule = 'demonstration_rule';

  factory M1IncidentRecommendationFacts.fromIncident(
    Incident incident, {
    required DateTime generatedAt,
  }) {
    return M1IncidentRecommendationFacts._(
      incidentId: incident.incidentId,
      vehicleId: incident.vehicleId,
      routeId: incident.routeId,
      incidentType: _incidentType(incident.incidentType),
      severity: incident.severity.name,
      status: _status(incident.status),
      incidentTimeUtc: incident.reportedAt.toUtc(),
      vehicleCondition: _vehicleCondition(incident.vehicleCondition),
      disruptionScope: _disruptionScope(incident.disruptionScope),
      estimatedDelayMinutes: incident.estimatedDelayMinutes,
      impactLevel: incident.impactLevel.name,
      incidentDataClassification: _dataClassification(incident.dataSource),
      delayEstimateClassification: demonstrationRule,
      generatedAtUtc: generatedAt.toUtc(),
    );
  }

  final String incidentId;
  final String? vehicleId;
  final String routeId;
  final String incidentType;
  final String severity;
  final String status;
  final DateTime incidentTimeUtc;
  final String vehicleCondition;
  final String disruptionScope;
  final int estimatedDelayMinutes;
  final String impactLevel;
  final String incidentDataClassification;
  final String delayEstimateClassification;
  final DateTime generatedAtUtc;

  Map<String, Object?> toJson() {
    return Map<String, Object?>.unmodifiable({
      'schema_version': schemaVersion,
      'incident_id': incidentId,
      'vehicle_id': vehicleId,
      'route_id': routeId,
      'incident_type': incidentType,
      'severity': severity,
      'status': status,
      'incident_time_utc': incidentTimeUtc.toIso8601String(),
      'vehicle_condition': vehicleCondition,
      'disruption_scope': disruptionScope,
      'estimated_delay_minutes': estimatedDelayMinutes,
      'impact_level': impactLevel,
      'incident_data_classification': incidentDataClassification,
      'delay_estimate_classification': delayEstimateClassification,
      'generated_at_utc': generatedAtUtc.toIso8601String(),
    });
  }

  static String _incidentType(IncidentType value) => switch (value) {
    IncidentType.vehicleBreakdown => 'vehicle_breakdown',
    IncidentType.accident => 'accident',
    IncidentType.serviceDisruption => 'service_disruption',
    IncidentType.infrastructureIssue => 'infrastructure_issue',
    IncidentType.safetyIncident => 'safety_incident',
    IncidentType.other => 'other',
  };

  static String _status(IncidentStatus value) => switch (value) {
    IncidentStatus.reported => 'reported',
    IncidentStatus.underReview => 'under_review',
    IncidentStatus.active => 'active',
    IncidentStatus.resolved => 'resolved',
    IncidentStatus.cancelled => 'cancelled',
  };

  static String _vehicleCondition(VehicleCondition value) => switch (value) {
    VehicleCondition.operational => 'operational',
    VehicleCondition.limitedOperation => 'limited_operation',
    VehicleCondition.immobilised => 'immobilised',
    VehicleCondition.unknown => 'unknown',
  };

  static String _disruptionScope(DisruptionScope value) => switch (value) {
    DisruptionScope.noObstruction => 'no_obstruction',
    DisruptionScope.partialObstruction => 'partial_obstruction',
    DisruptionScope.fullObstruction => 'full_obstruction',
    DisruptionScope.unknown => 'unknown',
  };

  static String _dataClassification(IncidentDataSource value) =>
      switch (value) {
        IncidentDataSource.staffEntered => 'staff_entered',
        IncidentDataSource.mockDemonstration => 'mock_demonstration',
        IncidentDataSource.liveGovernment => 'live_government',
        IncidentDataSource.cachedGovernment => 'cached_government',
        IncidentDataSource.staticGovernment => 'static_government',
      };
}
