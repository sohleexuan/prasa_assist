import '../models/incident.dart';
import '../models/incident_query.dart';
import '../models/incident_read_result.dart';
import '../models/local_incident_work_item.dart';

enum IncidentStateStatus { initial, loading, loaded, empty, error }

class IncidentState {
  IncidentState({
    required this.status,
    required List<Incident> incidents,
    required this.query,
    this.selectedIncident,
    this.errorMessage,
    this.listProvenance,
    this.localWorkItems = const [],
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
  final IncidentReadProvenance? listProvenance;
  final List<LocalIncidentWorkItem> localWorkItems;

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
    Object? listProvenance = _notProvided,
    List<LocalIncidentWorkItem>? localWorkItems,
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
      listProvenance: identical(listProvenance, _notProvided)
          ? this.listProvenance
          : listProvenance as IncidentReadProvenance?,
      localWorkItems: localWorkItems ?? this.localWorkItems,
    );
  }
}
