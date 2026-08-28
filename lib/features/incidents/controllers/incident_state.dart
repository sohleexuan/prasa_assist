import '../models/incident.dart';
import '../models/incident_query.dart';

enum IncidentStateStatus { initial, loading, loaded, empty, error }

class IncidentState {
  IncidentState({
    required this.status,
    required List<Incident> incidents,
    required this.query,
    this.selectedIncident,
    this.errorMessage,
  }) : incidents = List<Incident>.unmodifiable(incidents);

  factory IncidentState.initial() {
    return IncidentState(
      status: IncidentStateStatus.initial,
      incidents: const [],
      query: IncidentQuery(),
    );
  }

  static const Object _notProvided = Object();

  final IncidentStateStatus status;
  final List<Incident> incidents;
  final IncidentQuery query;
  final Incident? selectedIncident;
  final String? errorMessage;

  bool get isLoading => status == IncidentStateStatus.loading;

  bool get hasActiveQuery =>
      query.searchTerm.trim().isNotEmpty ||
      query.statuses.isNotEmpty ||
      query.severities.isNotEmpty ||
      query.incidentTypes.isNotEmpty;

  IncidentState copyWith({
    IncidentStateStatus? status,
    List<Incident>? incidents,
    IncidentQuery? query,
    Object? selectedIncident = _notProvided,
    Object? errorMessage = _notProvided,
  }) {
    return IncidentState(
      status: status ?? this.status,
      incidents: incidents ?? this.incidents,
      query: query ?? this.query,
      selectedIncident: identical(selectedIncident, _notProvided)
          ? this.selectedIncident
          : selectedIncident as Incident?,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
