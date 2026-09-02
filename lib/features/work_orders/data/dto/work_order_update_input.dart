import '../../models/work_order.dart';
import '../../repositories/work_order_data_exception.dart';

class WorkOrderUpdateInput {
  WorkOrderUpdateInput({
    required String vehicleId,
    required String taskType,
    required String description,
    required this.priority,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? notes,
  }) : vehicleId = _required(vehicleId, 'Vehicle ID'),
       taskType = _required(taskType, 'Task type'),
       description = _required(description, 'Description'),
       scheduledStart = scheduledStart?.toUtc(),
       scheduledEnd = scheduledEnd?.toUtc(),
       notes = _optional(notes) {
    validateWorkOrderSchedule(this.scheduledStart, this.scheduledEnd);
  }

  final String vehicleId;
  final String taskType;
  final String description;
  final WorkOrderPriority priority;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final String? notes;

  static String _required(String value, String label) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw WorkOrderValidationException('$label is required.');
    }
    return trimmed;
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
