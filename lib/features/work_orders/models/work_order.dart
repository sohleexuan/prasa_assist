import '../repositories/work_order_data_exception.dart';

enum WorkOrderPriority { low, medium, high, urgent }

enum WorkOrderStatus { draft, open, assigned, inProgress, completed, cancelled }

class WorkOrder {
  WorkOrder({
    required String workOrderId,
    required String vehicleId,
    required String taskType,
    required String description,
    required this.priority,
    required this.status,
    String? createdByUserId,
    required String createdBy,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? incidentId,
    String? recommendationId,
    String? routeId,
    String? assignedTo,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? notes,
    DateTime? completedAt,
    DateTime? cancelledAt,
    this.remoteVersion,
    bool allowLegacyScheduleEquality = false,
  }) : workOrderId = _required(workOrderId, 'Work order ID'),
       incidentId = _optional(incidentId),
       recommendationId = _optional(recommendationId),
       routeId = _optional(routeId),
       vehicleId = _required(vehicleId, 'Vehicle ID'),
       taskType = _required(taskType, 'Task type'),
       description = _required(description, 'Description'),
       assignedTo = _optional(assignedTo),
       scheduledStart = scheduledStart?.toUtc(),
       scheduledEnd = scheduledEnd?.toUtc(),
       notes = _optional(notes),
       createdByUserId = _optionalUuid(createdByUserId, 'Creator user ID'),
       createdBy = _required(createdBy, 'Created-by label'),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc(),
       completedAt = completedAt?.toUtc(),
       cancelledAt = cancelledAt?.toUtc() {
    _validate(allowLegacyScheduleEquality: allowLegacyScheduleEquality);
  }

  static const Object _unset = Object();

  final String workOrderId;
  final String? incidentId;
  final String? recommendationId;
  final String? routeId;
  final String vehicleId;
  final String taskType;
  final String description;
  final WorkOrderPriority priority;
  final String? assignedTo;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final WorkOrderStatus status;
  final String? notes;
  final String? createdByUserId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final int? remoteVersion;

  bool get isTerminal => status.isTerminal;
  bool get hasLegacyScheduleEquality =>
      scheduledStart != null && scheduledEnd!.isAtSameMomentAs(scheduledStart!);

  WorkOrder copyWith({
    String? workOrderId,
    Object? incidentId = _unset,
    Object? recommendationId = _unset,
    String? vehicleId,
    String? taskType,
    String? description,
    WorkOrderPriority? priority,
    Object? assignedTo = _unset,
    Object? scheduledStart = _unset,
    Object? scheduledEnd = _unset,
    WorkOrderStatus? status,
    Object? notes = _unset,
    Object? createdByUserId = _unset,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? completedAt = _unset,
    Object? cancelledAt = _unset,
    Object? remoteVersion = _unset,
  }) {
    return WorkOrder(
      workOrderId: workOrderId ?? this.workOrderId,
      incidentId: _nullable<String>(incidentId, this.incidentId),
      recommendationId: _nullable<String>(
        recommendationId,
        this.recommendationId,
      ),
      routeId: routeId,
      vehicleId: vehicleId ?? this.vehicleId,
      taskType: taskType ?? this.taskType,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      assignedTo: _nullable<String>(assignedTo, this.assignedTo),
      scheduledStart: _nullable<DateTime>(scheduledStart, this.scheduledStart),
      scheduledEnd: _nullable<DateTime>(scheduledEnd, this.scheduledEnd),
      status: status ?? this.status,
      notes: _nullable<String>(notes, this.notes),
      createdByUserId: _nullable<String>(createdByUserId, this.createdByUserId),
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: _nullable<DateTime>(completedAt, this.completedAt),
      cancelledAt: _nullable<DateTime>(cancelledAt, this.cancelledAt),
      remoteVersion: _nullable<int>(remoteVersion, this.remoteVersion),
    );
  }

  void _validate({required bool allowLegacyScheduleEquality}) {
    validateWorkOrderSchedule(
      scheduledStart,
      scheduledEnd,
      allowLegacyScheduleEquality: allowLegacyScheduleEquality,
    );
    if (updatedAt.isBefore(createdAt)) {
      throw const WorkOrderValidationException(
        'Updated time cannot be earlier than created time.',
      );
    }
    if (remoteVersion != null && remoteVersion! < 1) {
      throw const WorkOrderValidationException(
        'Confirmed remote version must be at least 1.',
      );
    }
    if (remoteVersion != null && createdByUserId == null) {
      throw const WorkOrderValidationException(
        'Confirmed work orders require a creator user ID.',
      );
    }
    if ({
          WorkOrderStatus.assigned,
          WorkOrderStatus.inProgress,
          WorkOrderStatus.completed,
        }.contains(status) &&
        assignedTo == null) {
      throw const WorkOrderValidationException(
        'Responsible staff is required for this work-order status.',
      );
    }
    switch (status) {
      case WorkOrderStatus.completed:
        if (completedAt == null || cancelledAt != null) {
          throw const WorkOrderValidationException(
            'Completed work orders require only a completion time.',
          );
        }
        _validateTerminalTime(completedAt!);
      case WorkOrderStatus.cancelled:
        if (cancelledAt == null || completedAt != null) {
          throw const WorkOrderValidationException(
            'Cancelled work orders require only a cancellation time.',
          );
        }
        _validateTerminalTime(cancelledAt!);
      case WorkOrderStatus.draft ||
          WorkOrderStatus.open ||
          WorkOrderStatus.assigned ||
          WorkOrderStatus.inProgress:
        if (completedAt != null || cancelledAt != null) {
          throw const WorkOrderValidationException(
            'Open work orders cannot contain terminal timestamps.',
          );
        }
    }
  }

  void _validateTerminalTime(DateTime terminalAt) {
    if (terminalAt.isBefore(createdAt) || terminalAt.isAfter(updatedAt)) {
      throw const WorkOrderValidationException(
        'Terminal time must be between created and updated times.',
      );
    }
  }

  static String _required(String value, String label) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw WorkOrderValidationException('$label is required.');
    }
    return normalized;
  }

  static String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static String? _optionalUuid(String? value, String label) {
    final normalized = _optional(value);
    if (normalized == null) return null;
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!uuid.hasMatch(normalized)) {
      throw WorkOrderValidationException('$label must be a valid UUID.');
    }
    return normalized;
  }

  static T? _nullable<T>(Object? value, T? current) =>
      identical(value, _unset) ? current : value as T?;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkOrder &&
          workOrderId == other.workOrderId &&
          incidentId == other.incidentId &&
          recommendationId == other.recommendationId &&
          routeId == other.routeId &&
          vehicleId == other.vehicleId &&
          taskType == other.taskType &&
          description == other.description &&
          priority == other.priority &&
          assignedTo == other.assignedTo &&
          scheduledStart == other.scheduledStart &&
          scheduledEnd == other.scheduledEnd &&
          status == other.status &&
          notes == other.notes &&
          createdByUserId == other.createdByUserId &&
          createdBy == other.createdBy &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          completedAt == other.completedAt &&
          cancelledAt == other.cancelledAt &&
          remoteVersion == other.remoteVersion;

  @override
  int get hashCode => Object.hash(
    workOrderId,
    incidentId,
    recommendationId,
    routeId,
    vehicleId,
    taskType,
    description,
    priority,
    assignedTo,
    scheduledStart,
    scheduledEnd,
    status,
    notes,
    createdByUserId,
    createdBy,
    createdAt,
    updatedAt,
    completedAt,
    cancelledAt,
    remoteVersion,
  );
}

void validateWorkOrderSchedule(
  DateTime? scheduledStart,
  DateTime? scheduledEnd, {
  bool allowLegacyScheduleEquality = false,
}) {
  if ((scheduledStart == null) != (scheduledEnd == null)) {
    throw const WorkOrderValidationException(
      'Provide both scheduled start and scheduled end.',
    );
  }
  if (scheduledStart == null) return;
  final endIsBefore = scheduledEnd!.isBefore(scheduledStart);
  final endIsEqual = scheduledEnd.isAtSameMomentAs(scheduledStart);
  if (endIsBefore || (endIsEqual && !allowLegacyScheduleEquality)) {
    throw const WorkOrderValidationException(
      'Scheduled end must be later than scheduled start.',
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
