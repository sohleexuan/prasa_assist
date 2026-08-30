import 'work_order.dart';

class WorkOrderPrefill {
  WorkOrderPrefill({
    required String vehicleId,
    required String taskType,
    required String description,
    required this.priority,
    String? incidentId,
    String? recommendationId,
    String? notes,
  }) : vehicleId = _required(vehicleId, 'vehicleId'),
       taskType = _required(taskType, 'taskType'),
       description = _required(description, 'description'),
       incidentId = _optional(incidentId),
       recommendationId = _optional(recommendationId),
       notes = _optional(notes);

  final String? incidentId;
  final String? recommendationId;
  final String vehicleId;
  final String taskType;
  final String description;
  final WorkOrderPriority priority;
  final String? notes;

  static String _required(String value, String name) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(value, name);
    return trimmed;
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
