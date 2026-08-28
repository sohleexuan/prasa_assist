import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/models/delay_estimate.dart';
import 'package:prasa_assist/features/incidents/models/incident.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';
import 'package:prasa_assist/features/incidents/models/incident_status_change.dart';
import 'package:prasa_assist/features/incidents/services/incident_validator.dart';

void main() {
  final validationTime = DateTime(2026, 8, 28, 12);

  group('IncidentValidator', () {
    test('valid Bus B1023 demonstration incident has no issues', () {
      expect(
        IncidentValidator.validate(_incident(), now: validationTime),
        isEmpty,
      );
    });

    test('validates required text and title boundaries', () {
      _expectIssue(
        _incident().copyWith(incidentId: ' '),
        validationTime,
        IncidentValidationField.incidentId,
        'Incident ID is required.',
      );
      _expectIssue(
        _incident().copyWith(title: 'AB'),
        validationTime,
        IncidentValidationField.title,
        'Title must be between 3 and 100 characters.',
      );
      _expectIssue(
        _incident().copyWith(title: 'A' * 101),
        validationTime,
        IncidentValidationField.title,
        'Title must be between 3 and 100 characters.',
      );
      _expectIssue(
        _incident().copyWith(description: 'Too short'),
        validationTime,
        IncidentValidationField.description,
        'Description must contain at least 10 characters.',
      );
      _expectIssue(
        _incident().copyWith(routeId: ''),
        validationTime,
        IncidentValidationField.routeId,
        'Route ID is required.',
      );
      _expectIssue(
        _incident().copyWith(location: ' '),
        validationTime,
        IncidentValidationField.location,
        'Location is required.',
      );
      _expectIssue(
        _incident().copyWith(reportedBy: ''),
        validationTime,
        IncidentValidationField.reportedBy,
        'Reported by is required.',
      );
    });

    test('rejects blank optional route and vehicle values', () {
      _expectIssue(
        _incident().copyWith(routeName: ' '),
        validationTime,
        IncidentValidationField.routeName,
        'Route name cannot be blank when provided.',
      );
      _expectIssue(
        _incident(incidentType: IncidentType.serviceDisruption)
            .copyWith(vehicleId: ' '),
        validationTime,
        IncidentValidationField.vehicleId,
        'Vehicle ID cannot be blank when provided.',
      );
    });

    test('requires vehicle ID for breakdowns and accidents', () {
      for (final type in [
        IncidentType.vehicleBreakdown,
        IncidentType.accident,
      ]) {
        _expectIssue(
          _incident(incidentType: type).copyWith(vehicleId: null),
          validationTime,
          IncidentValidationField.vehicleId,
          'Vehicle ID is required for this incident type.',
        );
      }
    });

    test('allows vehicle ID to be absent for other incident types', () {
      final incident = _incident(incidentType: IncidentType.infrastructureIssue)
          .copyWith(vehicleId: null);

      expect(
        IncidentValidator.validate(incident, now: validationTime),
        isEmpty,
      );
    });

    test('rejects future reported time', () {
      _expectIssue(
        _incident().copyWith(
          reportedAt: validationTime.add(const Duration(seconds: 1)),
        ),
        validationTime,
        IncidentValidationField.reportedAt,
        'Reported time cannot be in the future.',
      );
    });

    test('rejects update time before creation time', () {
      final createdAt = DateTime(2026, 8, 28, 8);
      _expectIssue(
        _incident(
          createdAt: createdAt,
          updatedAt: createdAt.subtract(const Duration(seconds: 1)),
        ),
        validationTime,
        IncidentValidationField.updatedAt,
        'Updated time cannot be earlier than created time.',
      );
    });

    test('includes delay estimate validation issues', () {
      final incident = _incident().copyWith(
        delayEstimate: DelayEstimate(
          estimatedDelayMinutes: 121,
          impactLevel: OperationalImpactLevel.severe,
          reasons: const [],
        ),
      );
      final issues = IncidentValidator.validate(incident, now: validationTime);

      expect(
        issues,
        contains(
          const IncidentValidationIssue(
            field: IncidentValidationField.delayEstimate,
            message: 'Estimated delay must be between 5 and 120 minutes.',
          ),
        ),
      );
      expect(
        issues,
        contains(
          const IncidentValidationIssue(
            field: IncidentValidationField.delayEstimate,
            message: 'At least one estimation reason is required.',
          ),
        ),
      );
    });

    test('requires an initial status history entry', () {
      _expectIssue(
        _incident(statusHistory: const []),
        validationTime,
        IncidentValidationField.statusHistory,
        'Status history must include the initial Reported entry.',
      );
    });

    test('requires continuous chronological status history', () {
      final createdAt = DateTime(2026, 8, 28, 8);
      final incident = _incident(
        status: IncidentStatus.active,
        createdAt: createdAt,
        updatedAt: createdAt.add(const Duration(minutes: 20)),
        statusHistory: [
          _initialStatus(createdAt),
          IncidentStatusChange(
            fromStatus: IncidentStatus.underReview,
            toStatus: IncidentStatus.active,
            changedAt: createdAt.subtract(const Duration(minutes: 1)),
            changedBy: 'Operations Staff',
          ),
        ],
      );
      final issues = IncidentValidator.validate(incident, now: validationTime);

      expect(
        issues,
        contains(
          const IncidentValidationIssue(
            field: IncidentValidationField.statusHistory,
            message: 'Status history entries must form a continuous chain.',
          ),
        ),
      );
      expect(
        issues,
        contains(
          const IncidentValidationIssue(
            field: IncidentValidationField.statusHistory,
            message: 'Status history must be in chronological order.',
          ),
        ),
      );
    });

    test('requires current status to match latest history entry', () {
      _expectIssue(
        _incident(status: IncidentStatus.active),
        validationTime,
        IncidentValidationField.statusHistory,
        'Current status must match the latest status history entry.',
      );
    });

    test('requires history times to stay within record timestamps', () {
      final createdAt = DateTime(2026, 8, 28, 8);
      final tooEarly = _incident(
        createdAt: createdAt,
        statusHistory: [
          _initialStatus(createdAt.subtract(const Duration(seconds: 1))),
        ],
      );
      _expectIssue(
        tooEarly,
        validationTime,
        IncidentValidationField.statusHistory,
        'Status history cannot begin before the record was created.',
      );

      final tooLate = _incident(
        createdAt: createdAt,
        updatedAt: createdAt,
        statusHistory: [
          _initialStatus(createdAt.add(const Duration(seconds: 1))),
        ],
      );
      _expectIssue(
        tooLate,
        validationTime,
        IncidentValidationField.statusHistory,
        'Status history cannot be later than the record update time.',
      );
    });
  });
}

void _expectIssue(
  Incident incident,
  DateTime now,
  IncidentValidationField field,
  String message,
) {
  expect(
    IncidentValidator.validate(incident, now: now),
    contains(IncidentValidationIssue(field: field, message: message)),
  );
}

Incident _incident({
  IncidentType incidentType = IncidentType.vehicleBreakdown,
  IncidentStatus status = IncidentStatus.reported,
  DateTime? createdAt,
  DateTime? updatedAt,
  List<IncidentStatusChange>? statusHistory,
}) {
  final creationTime = createdAt ?? DateTime(2026, 8, 28, 8);
  return Incident(
    incidentId: 'INC-20260828-001',
    incidentType: incidentType,
    title: 'Bus B1023 breakdown',
    description: 'Bus B1023 became immobilised while operating Route 300.',
    routeId: '300',
    routeName: 'Route 300',
    vehicleId: 'B1023',
    location: 'Route 300 demonstration location',
    reportedAt: DateTime(2026, 8, 28, 7, 55),
    severity: IncidentSeverity.high,
    status: status,
    vehicleCondition: VehicleCondition.immobilised,
    disruptionScope: DisruptionScope.partialObstruction,
    delayEstimate: DelayEstimate(
      estimatedDelayMinutes: 75,
      impactLevel: OperationalImpactLevel.severe,
      reasons: const ['Explainable demonstration estimate.'],
    ),
    reportedBy: 'Leong Yong Quan',
    dataSource: IncidentDataSource.mockDemonstration,
    createdAt: creationTime,
    updatedAt: updatedAt ?? creationTime,
    statusHistory: statusHistory ?? [_initialStatus(creationTime)],
  );
}

IncidentStatusChange _initialStatus(DateTime changedAt) {
  return IncidentStatusChange(
    fromStatus: null,
    toStatus: IncidentStatus.reported,
    changedAt: changedAt,
    changedBy: 'Leong Yong Quan',
  );
}
