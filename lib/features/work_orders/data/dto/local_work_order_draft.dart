import '../../models/work_order.dart';
import '../../repositories/work_order_data_exception.dart';

class LocalWorkOrderDraft {
  LocalWorkOrderDraft({
    required String vehicleId,
    required String taskType,
    required String description,
    required this.priority,
    required String createdByLabel,
    String? incidentId,
    String? recommendationId,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? notes,
  }) : vehicleId = _required(vehicleId, 'Vehicle ID'),
       taskType = _required(taskType, 'Task type'),
       description = _required(description, 'Description'),
       createdByLabel = _required(createdByLabel, 'Created-by label'),
       incidentId = _optional(incidentId),
       recommendationId = _optional(recommendationId),
       scheduledStart = scheduledStart?.toUtc(),
       scheduledEnd = scheduledEnd?.toUtc(),
       notes = _optional(notes) {
    if ((this.scheduledStart == null) != (this.scheduledEnd == null)) {
      throw const WorkOrderValidationException(
        'Provide both scheduled start and scheduled end.',
      );
    }
    if (this.scheduledStart != null &&
        this.scheduledEnd!.isBefore(this.scheduledStart!)) {
      throw const WorkOrderValidationException(
        'Scheduled end cannot be earlier than scheduled start.',
      );
    }
  }

  final String? incidentId;
  final String? recommendationId;
  final String vehicleId;
  final String taskType;
  final String description;
  final WorkOrderPriority priority;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final String? notes;
  final String createdByLabel;

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
