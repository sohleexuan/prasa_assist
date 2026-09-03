class DeploymentPrefill {
  const DeploymentPrefill({
    this.incidentId,
    this.recommendationId,
    this.routeId,
    this.routeName,
    this.suggestedVehicleCount,
    this.suggestedStartTime,
    this.suggestedEndTime,
    this.suggestedPurpose,
  });

  final String? incidentId;
  final String? recommendationId;
  final String? routeId;
  final String? routeName;
  final int? suggestedVehicleCount;
  final DateTime? suggestedStartTime;
  final DateTime? suggestedEndTime;
  final String? suggestedPurpose;
}
