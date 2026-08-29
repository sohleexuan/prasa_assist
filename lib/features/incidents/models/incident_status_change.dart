import 'incident_enums.dart';

class IncidentStatusChange {
  const IncidentStatusChange({
    required this.fromStatus,
    required this.toStatus,
    required this.changedAt,
    required this.changedBy,
    this.note,
  });

  final IncidentStatus? fromStatus;
  final IncidentStatus toStatus;
  final DateTime changedAt;
  final String changedBy;
  final String? note;

  List<String> validate() {
    final errors = <String>[];

    if (changedBy.trim().isEmpty) {
      errors.add('Status change operator is required.');
    }
    if (note != null && note!.trim().isEmpty) {
      errors.add('Status change note cannot be blank when provided.');
    }

    final previousStatus = fromStatus;
    if (previousStatus == null) {
      if (toStatus != IncidentStatus.reported) {
        errors.add('The initial status must be Reported.');
      }
    } else if (!previousStatus.canTransitionTo(toStatus)) {
      errors.add(
        '${previousStatus.displayLabel} cannot transition to '
        '${toStatus.displayLabel}.',
      );
    }

    return List<String>.unmodifiable(errors);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is IncidentStatusChange &&
            fromStatus == other.fromStatus &&
            toStatus == other.toStatus &&
            changedAt == other.changedAt &&
            changedBy == other.changedBy &&
            note == other.note;
  }

  @override
  int get hashCode =>
      Object.hash(fromStatus, toStatus, changedAt, changedBy, note);
}
