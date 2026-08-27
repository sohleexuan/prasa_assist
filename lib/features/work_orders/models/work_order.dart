enum WorkOrderPriority { low, medium, high, urgent }

enum WorkOrderStatus { draft, open, assigned, inProgress, completed, cancelled }

class WorkOrder {
  const WorkOrder({
    required this.workOrderId,
    required this.vehicleId,
    required this.taskType,
    required this.description,
    required this.priority,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.incidentId,
    this.recommendationId,
    this.assignedTo,
    this.scheduledStart,
    this.scheduledEnd,
    this.notes,
    this.completedAt,
    this.cancelledAt,
  });

  final String workOrderId;
  final String? incidentId;
  final String? recommendationId;
  final String vehicleId;
  final String taskType;
  final String description;
  final WorkOrderPriority priority;
  final String? assignedTo;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final WorkOrderStatus status;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  bool get isTerminal =>
      status == WorkOrderStatus.completed ||
      status == WorkOrderStatus.cancelled;

  WorkOrder copyWith({
    String? workOrderId,
    String? incidentId,
    String? recommendationId,
    String? vehicleId,
    String? taskType,
    String? description,
    WorkOrderPriority? priority,
    String? assignedTo,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    WorkOrderStatus? status,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
  }) {
    return WorkOrder(
      workOrderId: workOrderId ?? this.workOrderId,
      incidentId: incidentId ?? this.incidentId,
      recommendationId: recommendationId ?? this.recommendationId,
      vehicleId: vehicleId ?? this.vehicleId,
      taskType: taskType ?? this.taskType,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      assignedTo: assignedTo ?? this.assignedTo,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }
}

extension WorkOrderPriorityLabel on WorkOrderPriority {
  String get label => switch (this) {
    WorkOrderPriority.low => 'Low',
    WorkOrderPriority.medium => 'Medium',
    WorkOrderPriority.high => 'High',
    WorkOrderPriority.urgent => 'Urgent',
  };
}

extension WorkOrderStatusLabel on WorkOrderStatus {
  String get label => switch (this) {
    WorkOrderStatus.draft => 'Draft',
    WorkOrderStatus.open => 'Open',
    WorkOrderStatus.assigned => 'Assigned',
    WorkOrderStatus.inProgress => 'In Progress',
    WorkOrderStatus.completed => 'Completed',
    WorkOrderStatus.cancelled => 'Cancelled',
  };

  bool get isTerminal =>
      this == WorkOrderStatus.completed || this == WorkOrderStatus.cancelled;

  bool canTransitionTo(WorkOrderStatus next) {
    if (isTerminal || next == this) return false;
    if (next == WorkOrderStatus.cancelled) return true;
    return switch (this) {
      WorkOrderStatus.draft => next == WorkOrderStatus.open,
      WorkOrderStatus.open => next == WorkOrderStatus.assigned,
      WorkOrderStatus.assigned => next == WorkOrderStatus.inProgress,
      WorkOrderStatus.inProgress => next == WorkOrderStatus.completed,
      WorkOrderStatus.completed || WorkOrderStatus.cancelled => false,
    };
  }
}
