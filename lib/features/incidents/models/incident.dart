import 'delay_estimate.dart';
import 'incident_enums.dart';
import 'incident_status_change.dart';

class Incident {
  Incident({
    required this.incidentId,
    required this.incidentType,
    required this.title,
    required this.description,
    required this.routeId,
    required this.location,
    required this.reportedAt,
    required this.severity,
    required this.status,
    required this.vehicleCondition,
    required this.disruptionScope,
    required this.delayEstimate,
    required this.reportedBy,
    required this.dataSource,
    required this.createdAt,
    required this.updatedAt,
    required List<IncidentStatusChange> statusHistory,
    this.routeName,
    this.vehicleId,
    this.version = 1,
  }) : statusHistory = List<IncidentStatusChange>.unmodifiable(statusHistory);

  static const Object _notProvided = Object();

  final String incidentId;
  final IncidentType incidentType;
  final String title;
  final String description;
  final String routeId;
  final String? routeName;
  final String? vehicleId;
  final String location;
  final DateTime reportedAt;
  final IncidentSeverity severity;
  final IncidentStatus status;
  final VehicleCondition vehicleCondition;
  final DisruptionScope disruptionScope;
  final DelayEstimate delayEstimate;
  final String reportedBy;
  final IncidentDataSource dataSource;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<IncidentStatusChange> statusHistory;
  final int version;

  int get estimatedDelayMinutes => delayEstimate.estimatedDelayMinutes;

  OperationalImpactLevel get impactLevel => delayEstimate.impactLevel;

  List<String> get estimationReasons => delayEstimate.reasons;

  Incident copyWith({
    String? incidentId,
    IncidentType? incidentType,
    String? title,
    String? description,
    String? routeId,
    Object? routeName = _notProvided,
    Object? vehicleId = _notProvided,
    String? location,
    DateTime? reportedAt,
    IncidentSeverity? severity,
    IncidentStatus? status,
    VehicleCondition? vehicleCondition,
    DisruptionScope? disruptionScope,
    DelayEstimate? delayEstimate,
    String? reportedBy,
    IncidentDataSource? dataSource,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<IncidentStatusChange>? statusHistory,
    int? version,
  }) {
    return Incident(
      incidentId: incidentId ?? this.incidentId,
      incidentType: incidentType ?? this.incidentType,
      title: title ?? this.title,
      description: description ?? this.description,
      routeId: routeId ?? this.routeId,
      routeName: identical(routeName, _notProvided)
          ? this.routeName
          : routeName as String?,
      vehicleId: identical(vehicleId, _notProvided)
          ? this.vehicleId
          : vehicleId as String?,
      location: location ?? this.location,
      reportedAt: reportedAt ?? this.reportedAt,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      vehicleCondition: vehicleCondition ?? this.vehicleCondition,
      disruptionScope: disruptionScope ?? this.disruptionScope,
      delayEstimate: delayEstimate ?? this.delayEstimate,
      reportedBy: reportedBy ?? this.reportedBy,
      dataSource: dataSource ?? this.dataSource,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      statusHistory: statusHistory ?? this.statusHistory,
      version: version ?? this.version,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Incident &&
            incidentId == other.incidentId &&
            incidentType == other.incidentType &&
            title == other.title &&
            description == other.description &&
            routeId == other.routeId &&
            routeName == other.routeName &&
            vehicleId == other.vehicleId &&
            location == other.location &&
            reportedAt == other.reportedAt &&
            severity == other.severity &&
            status == other.status &&
            vehicleCondition == other.vehicleCondition &&
            disruptionScope == other.disruptionScope &&
            delayEstimate == other.delayEstimate &&
            reportedBy == other.reportedBy &&
            dataSource == other.dataSource &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt &&
            _listsAreEqual(statusHistory, other.statusHistory) &&
            version == other.version;
  }

  @override
  int get hashCode => Object.hash(
    incidentId,
    incidentType,
    title,
    description,
    routeId,
    routeName,
    vehicleId,
    location,
    reportedAt,
    severity,
    status,
    vehicleCondition,
    disruptionScope,
    delayEstimate,
    reportedBy,
    dataSource,
    createdAt,
    updatedAt,
    Object.hashAll(statusHistory),
    version,
  );

  static bool _listsAreEqual(
    List<IncidentStatusChange> first,
    List<IncidentStatusChange> second,
  ) {
    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }
    return true;
  }
}
