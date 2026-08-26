enum DeploymentStatus { draft, scheduled, active, completed, cancelled }

extension DeploymentStatusRules on DeploymentStatus {
  String get displayLabel => switch (this) {
    DeploymentStatus.draft => 'Draft',
    DeploymentStatus.scheduled => 'Scheduled',
    DeploymentStatus.active => 'Active',
    DeploymentStatus.completed => 'Completed',
    DeploymentStatus.cancelled => 'Cancelled',
  };

  bool canTransitionTo(DeploymentStatus nextStatus) => switch (this) {
    DeploymentStatus.draft =>
      nextStatus == DeploymentStatus.scheduled ||
          nextStatus == DeploymentStatus.cancelled,
    DeploymentStatus.scheduled =>
      nextStatus == DeploymentStatus.active ||
          nextStatus == DeploymentStatus.cancelled,
    DeploymentStatus.active =>
      nextStatus == DeploymentStatus.completed ||
          nextStatus == DeploymentStatus.cancelled,
    DeploymentStatus.completed || DeploymentStatus.cancelled => false,
  };

  bool get isTerminal =>
      this == DeploymentStatus.completed || this == DeploymentStatus.cancelled;
}
