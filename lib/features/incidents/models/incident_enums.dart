enum IncidentType {
  vehicleBreakdown,
  accident,
  serviceDisruption,
  infrastructureIssue,
  safetyIncident,
  other,
}

extension IncidentTypeDetails on IncidentType {
  String get displayLabel => switch (this) {
    IncidentType.vehicleBreakdown => 'Vehicle Breakdown',
    IncidentType.accident => 'Accident',
    IncidentType.serviceDisruption => 'Service Disruption',
    IncidentType.infrastructureIssue => 'Infrastructure Issue',
    IncidentType.safetyIncident => 'Safety Incident',
    IncidentType.other => 'Other',
  };

  bool get requiresVehicleId =>
      this == IncidentType.vehicleBreakdown || this == IncidentType.accident;
}

enum IncidentSeverity { low, medium, high, critical }

extension IncidentSeverityDetails on IncidentSeverity {
  String get displayLabel => switch (this) {
    IncidentSeverity.low => 'Low',
    IncidentSeverity.medium => 'Medium',
    IncidentSeverity.high => 'High',
    IncidentSeverity.critical => 'Critical',
  };

  int get priority => switch (this) {
    IncidentSeverity.low => 0,
    IncidentSeverity.medium => 1,
    IncidentSeverity.high => 2,
    IncidentSeverity.critical => 3,
  };
}

enum IncidentStatus { reported, underReview, active, resolved, cancelled }

extension IncidentStatusRules on IncidentStatus {
  String get displayLabel => switch (this) {
    IncidentStatus.reported => 'Reported',
    IncidentStatus.underReview => 'Under Review',
    IncidentStatus.active => 'Active',
    IncidentStatus.resolved => 'Resolved',
    IncidentStatus.cancelled => 'Cancelled',
  };

  bool canTransitionTo(IncidentStatus nextStatus) => switch (this) {
    IncidentStatus.reported =>
      nextStatus == IncidentStatus.underReview ||
          nextStatus == IncidentStatus.cancelled,
    IncidentStatus.underReview =>
      nextStatus == IncidentStatus.active ||
          nextStatus == IncidentStatus.cancelled,
    IncidentStatus.active =>
      nextStatus == IncidentStatus.resolved ||
          nextStatus == IncidentStatus.cancelled,
    IncidentStatus.resolved || IncidentStatus.cancelled => false,
  };

  bool get isTerminal =>
      this == IncidentStatus.resolved || this == IncidentStatus.cancelled;

  bool get canBeDeleted =>
      this == IncidentStatus.reported || this == IncidentStatus.cancelled;
}

enum VehicleCondition { operational, limitedOperation, immobilised, unknown }

extension VehicleConditionDetails on VehicleCondition {
  String get displayLabel => switch (this) {
    VehicleCondition.operational => 'Operational',
    VehicleCondition.limitedOperation => 'Limited Operation',
    VehicleCondition.immobilised => 'Immobilised',
    VehicleCondition.unknown => 'Unknown',
  };
}

enum DisruptionScope {
  noObstruction,
  partialObstruction,
  fullObstruction,
  unknown,
}

extension DisruptionScopeDetails on DisruptionScope {
  String get displayLabel => switch (this) {
    DisruptionScope.noObstruction => 'No Obstruction',
    DisruptionScope.partialObstruction => 'Partial Obstruction',
    DisruptionScope.fullObstruction => 'Full Obstruction',
    DisruptionScope.unknown => 'Unknown',
  };
}

enum OperationalImpactLevel { minor, moderate, major, severe }

extension OperationalImpactLevelDetails on OperationalImpactLevel {
  String get displayLabel => switch (this) {
    OperationalImpactLevel.minor => 'Minor',
    OperationalImpactLevel.moderate => 'Moderate',
    OperationalImpactLevel.major => 'Major',
    OperationalImpactLevel.severe => 'Severe',
  };
}

enum IncidentDataSource {
  staffEntered,
  mockDemonstration,
  liveGovernment,
  cachedGovernment,
  staticGovernment,
}

extension IncidentDataSourceDetails on IncidentDataSource {
  String get displayLabel => switch (this) {
    IncidentDataSource.staffEntered => 'Staff-entered Data',
    IncidentDataSource.mockDemonstration => 'Mock / Demonstration Data',
    IncidentDataSource.liveGovernment => 'Live Government Data',
    IncidentDataSource.cachedGovernment => 'Cached Government Data',
    IncidentDataSource.staticGovernment => 'Static Government Data',
  };
}
