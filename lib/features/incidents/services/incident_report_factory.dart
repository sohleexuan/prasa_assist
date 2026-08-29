import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../models/incident_status_change.dart';
import 'delay_estimator.dart';

typedef IncidentIdGenerator = String Function(DateTime now);

/// Builds a new staff-entered Incident with the required initial audit entry.
class IncidentReportFactory {
  const IncidentReportFactory({this.estimator = const DelayEstimator()});

  final DelayEstimator estimator;

  Incident create({
    required String incidentId,
    required IncidentType incidentType,
    required String title,
    required String description,
    required String routeId,
    required String? routeName,
    required String? vehicleId,
    required String location,
    required DateTime reportedAt,
    required IncidentSeverity severity,
    required VehicleCondition vehicleCondition,
    required DisruptionScope disruptionScope,
    required String reportedBy,
    required DateTime createdAt,
  }) {
    final normalizedReporter = reportedBy.trim();
    return Incident(
      incidentId: incidentId.trim(),
      incidentType: incidentType,
      title: title.trim(),
      description: description.trim(),
      routeId: routeId.trim(),
      routeName: _optionalText(routeName),
      vehicleId: _optionalText(vehicleId),
      location: location.trim(),
      reportedAt: reportedAt,
      severity: severity,
      status: IncidentStatus.reported,
      vehicleCondition: vehicleCondition,
      disruptionScope: disruptionScope,
      delayEstimate: estimator.estimate(
        incidentType: incidentType,
        severity: severity,
        vehicleCondition: vehicleCondition,
        disruptionScope: disruptionScope,
        reportedAt: reportedAt,
      ),
      reportedBy: normalizedReporter,
      dataSource: IncidentDataSource.staffEntered,
      createdAt: createdAt,
      updatedAt: createdAt,
      statusHistory: [
        IncidentStatusChange(
          fromStatus: null,
          toStatus: IncidentStatus.reported,
          changedAt: createdAt,
          changedBy: normalizedReporter,
          note: 'Incident reported by staff.',
        ),
      ],
    );
  }

  static String defaultId(DateTime now) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    String threeDigits(int value) => value.toString().padLeft(3, '0');
    return 'INC-${now.year}${twoDigits(now.month)}${twoDigits(now.day)}-'
        '${twoDigits(now.hour)}${twoDigits(now.minute)}'
        '${twoDigits(now.second)}${threeDigits(now.millisecond)}';
  }

  static String? _optionalText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
