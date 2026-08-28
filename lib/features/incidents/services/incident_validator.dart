import '../models/incident.dart';
import '../models/incident_enums.dart';

enum IncidentValidationField {
  incidentId,
  title,
  description,
  routeId,
  routeName,
  vehicleId,
  location,
  reportedAt,
  reportedBy,
  createdAt,
  updatedAt,
  delayEstimate,
  statusHistory,
  version,
}

class IncidentValidationIssue {
  const IncidentValidationIssue({required this.field, required this.message});

  final IncidentValidationField field;
  final String message;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is IncidentValidationIssue &&
            field == other.field &&
            message == other.message;
  }

  @override
  int get hashCode => Object.hash(field, message);
}

abstract final class IncidentValidator {
  static List<IncidentValidationIssue> validate(
    Incident incident, {
    DateTime? now,
  }) {
    final issues = <IncidentValidationIssue>[];
    final validationTime = now ?? DateTime.now();
    final title = incident.title.trim();
    final description = incident.description.trim();

    if (incident.incidentId.trim().isEmpty) {
      issues.add(
        const IncidentValidationIssue(
          field: IncidentValidationField.incidentId,
          message: 'Incident ID is required.',
        ),
      );
    }
    if (title.length < 3 || title.length > 100) {
      issues.add(
        const IncidentValidationIssue(
          field: IncidentValidationField.title,
          message: 'Title must be between 3 and 100 characters.',
        ),
      );
    }
    if (description.length < 10) {
      issues.add(
        const IncidentValidationIssue(
          field: IncidentValidationField.description,
          message: 'Description must contain at least 10 characters.',
        ),
      );
    }
    if (incident.routeId.trim().isEmpty) {
      issues.add(
        const IncidentValidationIssue(
          field: IncidentValidationField.routeId,
          message: 'Route ID is required.',
        ),
      );
    }
    if (incident.routeName != null && incident.routeName!.trim().isEmpty) {
      issues.add(
        const IncidentValidationIssue(
          field: IncidentValidationField.routeName,
          message: 'Route name cannot be blank when provided.',
        ),
      );
    }

    final vehicleId = incident.vehicleId?.trim();
    if (incident.incidentType.requiresVehicleId &&
        (vehicleId == null || vehicleId.isEmpty)) {
      issues.add(
        const IncidentValidationIssue(
          field: IncidentValidationField.vehicleId,
          message: 'Vehicle ID is required for this incident type.',
        ),
      );
    } else if (incident.vehicleId != null && vehicleId!.isEmpty) {
      issues.add(
        const IncidentValidationIssue(
          field: IncidentValidationField.vehicleId,
          message: 'Vehicle ID cannot be blank when provided.',
        ),
      );
    }

    if (incident.location.trim().isEmpty) {
      issues.add(
        const IncidentValidationIssue(
          field: IncidentValidationField.location,
          message: 'Location is required.',
        ),
      );
    }
    if (incident.reportedAt.isAfter(validationTime)) {
      issues.add(
        const IncidentValidationIssue(
          field: IncidentValidationField.reportedAt,
          message: 'Reported time cannot be in the future.',
        ),
      );
    }
    if (incident.reportedBy.trim().isEmpty) {
      issues.add(
        const IncidentValidationIssue(
          field: IncidentValidationField.reportedBy,
          message: 'Reported by is required.',
        ),
      );
    }
    if (incident.updatedAt.isBefore(incident.createdAt)) {
      issues.add(
        const IncidentValidationIssue(
          field: IncidentValidationField.updatedAt,
          message: 'Updated time cannot be earlier than created time.',
        ),
      );
    }
    if (incident.version < 1) {
      issues.add(
        const IncidentValidationIssue(
          field: IncidentValidationField.version,
          message: 'Incident version must be at least 1.',
        ),
      );
    }

    for (final message in incident.delayEstimate.validate()) {
      issues.add(
        IncidentValidationIssue(
          field: IncidentValidationField.delayEstimate,
          message: message,
        ),
      );
    }

    _validateStatusHistory(incident, issues);
    return List<IncidentValidationIssue>.unmodifiable(issues);
  }

  static void _validateStatusHistory(
    Incident incident,
    List<IncidentValidationIssue> issues,
  ) {
    final history = incident.statusHistory;
    if (history.isEmpty) {
      issues.add(
        const IncidentValidationIssue(
          field: IncidentValidationField.statusHistory,
          message: 'Status history must include the initial Reported entry.',
        ),
      );
      return;
    }

    for (var index = 0; index < history.length; index++) {
      final change = history[index];
      for (final message in change.validate()) {
        issues.add(
          IncidentValidationIssue(
            field: IncidentValidationField.statusHistory,
            message: message,
          ),
        );
      }

      if (index == 0) {
        if (change.fromStatus != null) {
          issues.add(
            const IncidentValidationIssue(
              field: IncidentValidationField.statusHistory,
              message: 'The first status history entry cannot have a source.',
            ),
          );
        }
      } else {
        final previousChange = history[index - 1];
        if (change.fromStatus != previousChange.toStatus) {
          issues.add(
            const IncidentValidationIssue(
              field: IncidentValidationField.statusHistory,
              message: 'Status history entries must form a continuous chain.',
            ),
          );
        }
        if (change.changedAt.isBefore(previousChange.changedAt)) {
          issues.add(
            const IncidentValidationIssue(
              field: IncidentValidationField.statusHistory,
              message: 'Status history must be in chronological order.',
            ),
          );
        }
      }
    }

    if (history.first.changedAt.isBefore(incident.createdAt)) {
      issues.add(
        const IncidentValidationIssue(
          field: IncidentValidationField.statusHistory,
          message: 'Status history cannot begin before the record was created.',
        ),
      );
    }
    if (history.last.changedAt.isAfter(incident.updatedAt)) {
      issues.add(
        const IncidentValidationIssue(
          field: IncidentValidationField.statusHistory,
          message:
              'Status history cannot be later than the record update time.',
        ),
      );
    }
    if (history.last.toStatus != incident.status) {
      issues.add(
        const IncidentValidationIssue(
          field: IncidentValidationField.statusHistory,
          message: 'Current status must match the latest status history entry.',
        ),
      );
    }
  }
}
