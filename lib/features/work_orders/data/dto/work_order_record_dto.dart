import '../../models/work_order.dart';
import '../../repositories/work_order_data_exception.dart';

class WorkOrderRecordDto {
  WorkOrderRecordDto({
    required String storageId,
    required String workOrderId,
    required String vehicleId,
    required String taskType,
    required String description,
    required this.priority,
    required this.status,
    required String createdByUserId,
    required String createdByLabel,
    required DateTime createdAt,
    required DateTime updatedAt,
    required this.remoteVersion,
    String? incidentId,
    String? recommendationId,
    String? assignedTo,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? notes,
    DateTime? completedAt,
    DateTime? cancelledAt,
  }) : storageId = _uuid(storageId, 'Remote storage ID'),
       workOrderId = _required(workOrderId, 'Work order ID'),
       incidentId = _optional(incidentId),
       recommendationId = _optional(recommendationId),
       vehicleId = _required(vehicleId, 'Vehicle ID'),
       taskType = _required(taskType, 'Task type'),
       description = _required(description, 'Description'),
       assignedTo = _optional(assignedTo),
       scheduledStart = scheduledStart?.toUtc(),
       scheduledEnd = scheduledEnd?.toUtc(),
       notes = _optional(notes),
       createdByUserId = _uuid(createdByUserId, 'Creator user ID'),
       createdByLabel = _required(createdByLabel, 'Created-by label'),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc(),
       completedAt = completedAt?.toUtc(),
       cancelledAt = cancelledAt?.toUtc() {
    if (remoteVersion < 1) {
      throw const WorkOrderMappingException(
        'Work-order remote version must be at least 1.',
      );
    }
    WorkOrder(
      workOrderId: this.workOrderId,
      incidentId: this.incidentId,
      recommendationId: this.recommendationId,
      vehicleId: this.vehicleId,
      taskType: this.taskType,
      description: this.description,
      priority: priority,
      assignedTo: this.assignedTo,
      scheduledStart: this.scheduledStart,
      scheduledEnd: this.scheduledEnd,
      status: status,
      notes: this.notes,
      createdByUserId: this.createdByUserId,
      createdBy: this.createdByLabel,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt,
      completedAt: this.completedAt,
      cancelledAt: this.cancelledAt,
      remoteVersion: remoteVersion,
    );
  }

  final String storageId;
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
  final String createdByUserId;
  final String createdByLabel;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final int remoteVersion;

  factory WorkOrderRecordDto.fromMap(Map<String, dynamic> map) {
    try {
      return WorkOrderRecordDto(
        storageId: _mapString(map, 'id'),
        workOrderId: _mapString(map, 'work_order_id'),
        incidentId: _mapOptionalString(map, 'incident_id'),
        recommendationId: _mapOptionalString(map, 'recommendation_id'),
        vehicleId: _mapString(map, 'vehicle_id'),
        taskType: _mapString(map, 'task_type'),
        description: _mapString(map, 'description'),
        priority: _priority(map['priority']),
        assignedTo: _mapOptionalString(map, 'assigned_to'),
        scheduledStart: _mapOptionalDate(map, 'scheduled_start'),
        scheduledEnd: _mapOptionalDate(map, 'scheduled_end'),
        status: _status(map['status']),
        notes: _mapOptionalString(map, 'notes'),
        createdByUserId: _mapString(map, 'created_by_user_id'),
        createdByLabel: _mapString(map, 'created_by_label'),
        createdAt: _mapDate(map, 'created_at'),
        updatedAt: _mapDate(map, 'updated_at'),
        completedAt: _mapOptionalDate(map, 'completed_at'),
        cancelledAt: _mapOptionalDate(map, 'cancelled_at'),
        remoteVersion: _mapInt(map, 'version'),
      );
    } on WorkOrderDataException {
      rethrow;
    } catch (error) {
      throw WorkOrderMappingException(
        'Work-order record contains invalid data.',
        cause: error,
      );
    }
  }

  Map<String, dynamic> toMap() => {
    'id': storageId,
    'work_order_id': workOrderId,
    'incident_id': incidentId,
    'recommendation_id': recommendationId,
    'vehicle_id': vehicleId,
    'task_type': taskType,
    'description': description,
    'priority': priority.name,
    'assigned_to': assignedTo,
    'scheduled_start': scheduledStart?.toIso8601String(),
    'scheduled_end': scheduledEnd?.toIso8601String(),
    'status': status == WorkOrderStatus.inProgress
        ? 'in_progress'
        : status.name,
    'notes': notes,
    'created_by_user_id': createdByUserId,
    'created_by_label': createdByLabel,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'cancelled_at': cancelledAt?.toIso8601String(),
    'version': remoteVersion,
  };

  static String _required(String value, String label) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) throw WorkOrderMappingException('$label is required.');
    return trimmed;
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _uuid(String value, String label) {
    final trimmed = value.trim();
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(trimmed)) {
      throw WorkOrderMappingException('$label must be a valid UUID.');
    }
    return trimmed;
  }

  static String _mapString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String) {
      throw WorkOrderMappingException(
        'Work-order field $key is missing or malformed.',
      );
    }
    return value;
  }

  static String? _mapOptionalString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! String) {
      throw WorkOrderMappingException('Work-order field $key is malformed.');
    }
    return value;
  }

  static int _mapInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! int) {
      throw WorkOrderMappingException(
        'Work-order field $key is missing or malformed.',
      );
    }
    return value;
  }

  static DateTime _mapDate(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    throw WorkOrderMappingException(
      'Work-order field $key is missing or malformed.',
    );
  }

  static DateTime? _mapOptionalDate(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    throw WorkOrderMappingException('Work-order field $key is malformed.');
  }

  static WorkOrderPriority _priority(Object? value) => switch (value) {
    'low' => WorkOrderPriority.low,
    'medium' => WorkOrderPriority.medium,
    'high' => WorkOrderPriority.high,
    'urgent' => WorkOrderPriority.urgent,
    _ => throw WorkOrderMappingException(
      'Unknown work-order priority "$value".',
    ),
  };
  static WorkOrderStatus _status(Object? value) => switch (value) {
    'draft' => WorkOrderStatus.draft,
    'open' => WorkOrderStatus.open,
    'assigned' => WorkOrderStatus.assigned,
    'in_progress' => WorkOrderStatus.inProgress,
    'completed' => WorkOrderStatus.completed,
    'cancelled' => WorkOrderStatus.cancelled,
    _ => throw WorkOrderMappingException('Unknown work-order status "$value".'),
  };
}
