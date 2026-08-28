import 'incident.dart';
import 'incident_enums.dart';

enum IncidentSortOrder {
  newestReported,
  oldestReported,
  highestSeverity,
  longestEstimatedDelay,
  recentlyUpdated,
}

extension IncidentSortOrderDetails on IncidentSortOrder {
  String get displayLabel => switch (this) {
    IncidentSortOrder.newestReported => 'Newest Reported First',
    IncidentSortOrder.oldestReported => 'Oldest Reported First',
    IncidentSortOrder.highestSeverity => 'Highest Severity First',
    IncidentSortOrder.longestEstimatedDelay => 'Longest Estimated Delay First',
    IncidentSortOrder.recentlyUpdated => 'Recently Updated First',
  };
}

class IncidentQuery {
  IncidentQuery({
    this.searchTerm = '',
    Set<IncidentStatus> statuses = const {},
    Set<IncidentSeverity> severities = const {},
    Set<IncidentType> incidentTypes = const {},
    this.sortOrder = IncidentSortOrder.newestReported,
  }) : statuses = Set<IncidentStatus>.unmodifiable(statuses),
       severities = Set<IncidentSeverity>.unmodifiable(severities),
       incidentTypes = Set<IncidentType>.unmodifiable(incidentTypes);

  final String searchTerm;
  final Set<IncidentStatus> statuses;
  final Set<IncidentSeverity> severities;
  final Set<IncidentType> incidentTypes;
  final IncidentSortOrder sortOrder;

  bool matches(Incident incident) {
    if (statuses.isNotEmpty && !statuses.contains(incident.status)) {
      return false;
    }
    if (severities.isNotEmpty && !severities.contains(incident.severity)) {
      return false;
    }
    if (incidentTypes.isNotEmpty &&
        !incidentTypes.contains(incident.incidentType)) {
      return false;
    }

    final normalizedSearch = searchTerm.trim().toLowerCase();
    if (normalizedSearch.isEmpty) {
      return true;
    }

    final searchableValues = <String?>[
      incident.incidentId,
      incident.title,
      incident.description,
      incident.routeId,
      incident.routeName,
      incident.vehicleId,
      incident.location,
      incident.reportedBy,
    ];
    return searchableValues.any(
      (value) => value?.toLowerCase().contains(normalizedSearch) ?? false,
    );
  }

  int compare(Incident first, Incident second) {
    final primaryComparison = switch (sortOrder) {
      IncidentSortOrder.newestReported => second.reportedAt.compareTo(
        first.reportedAt,
      ),
      IncidentSortOrder.oldestReported => first.reportedAt.compareTo(
        second.reportedAt,
      ),
      IncidentSortOrder.highestSeverity => second.severity.priority.compareTo(
        first.severity.priority,
      ),
      IncidentSortOrder.longestEstimatedDelay =>
        second.estimatedDelayMinutes.compareTo(first.estimatedDelayMinutes),
      IncidentSortOrder.recentlyUpdated => second.updatedAt.compareTo(
        first.updatedAt,
      ),
    };
    if (primaryComparison != 0) {
      return primaryComparison;
    }

    if (sortOrder != IncidentSortOrder.newestReported &&
        sortOrder != IncidentSortOrder.oldestReported) {
      final reportedComparison = second.reportedAt.compareTo(first.reportedAt);
      if (reportedComparison != 0) {
        return reportedComparison;
      }
    }

    return first.incidentId.compareTo(second.incidentId);
  }
}
