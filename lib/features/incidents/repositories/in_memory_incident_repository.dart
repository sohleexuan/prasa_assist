import '../data/incident_demo_data.dart';
import '../../../core/time/malaysia_time.dart';
import '../models/delay_estimate.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../models/incident_query.dart';
import '../models/incident_status_change.dart';
import '../services/delay_estimator.dart';
import '../services/incident_validator.dart';
import 'incident_data_exception.dart';
import 'incident_repository.dart';
import 'incident_repository_capabilities.dart';

typedef IncidentClock = DateTime Function();

/// In-memory Incident storage for development and demonstration only.
///
/// Records reset when the application restarts. This repository does not
/// connect to Supabase or any live government-data source.
class InMemoryIncidentRepository
    implements IncidentRepository, IncidentRepositoryCapabilitiesProvider {
  InMemoryIncidentRepository({
    Iterable<Incident> seedData = const [],
    this._estimator = const DelayEstimator(),
    IncidentClock? clock,
  }) : _clock = clock ?? DateTime.now {
    for (final incident in seedData) {
      final normalized = _normalize(incident);
      _validate(normalized);
      final key = _keyFor(normalized.incidentId);
      if (_incidents.containsKey(key)) {
        throw StateError(
          'An incident with ID ${normalized.incidentId} already exists.',
        );
      }
      _incidents[key] = normalized.copyWith();
    }
  }

  factory InMemoryIncidentRepository.withDemonstrationData({
    IncidentClock? clock,
  }) {
    final effectiveClock = clock ?? DateTime.now;
    return InMemoryIncidentRepository(
      seedData: [IncidentDemoData.busB1023()],
      clock: effectiveClock,
    );
  }

  final DelayEstimator _estimator;
  final IncidentClock _clock;
  final Map<String, Incident> _incidents = {};

  @override
  IncidentRepositoryCapabilities get capabilities =>
      const IncidentRepositoryCapabilities.prototype();

  @override
  Future<List<Incident>> getAll({IncidentQuery? query}) async {
    final effectiveQuery = query ?? IncidentQuery();
    final incidents =
        _incidents.values
            .where(effectiveQuery.matches)
            .map((incident) => incident.copyWith())
            .toList(growable: false)
          ..sort(effectiveQuery.compare);
    return List<Incident>.unmodifiable(incidents);
  }

  @override
  Future<Incident?> getById(String incidentId) async {
    return _incidents[_keyFor(incidentId)]?.copyWith();
  }

  @override
  Future<Incident> create(Incident incident) async {
    if (incident.status != IncidentStatus.reported ||
        incident.statusHistory.length != 1 ||
        incident.statusHistory.single.fromStatus != null ||
        incident.statusHistory.single.toStatus != IncidentStatus.reported) {
      throw const IncidentValidationException(
        'A new incident must begin with one Reported status entry.',
      );
    }

    final normalizedInput = _normalize(incident);
    final key = _keyFor(normalizedInput.incidentId);
    if (_incidents.containsKey(key)) {
      throw IncidentDuplicateException(
        'An incident with ID ${normalizedInput.incidentId} already exists.',
      );
    }

    final now = _clock();
    final initialChange = normalizedInput.statusHistory.single;
    final created = normalizedInput.copyWith(
      delayEstimate: _estimate(normalizedInput),
      createdAt: now,
      updatedAt: now,
      statusHistory: [
        IncidentStatusChange(
          fromStatus: null,
          toStatus: IncidentStatus.reported,
          changedAt: now,
          changedBy: initialChange.changedBy,
          note: initialChange.note,
        ),
      ],
    );
    _validate(created);
    _incidents[key] = created;
    return created.copyWith();
  }

  @override
  Future<Incident> update(Incident incident) async {
    final normalizedInput = _normalize(incident);
    final key = _keyFor(normalizedInput.incidentId);
    final current = _incidents[key];
    if (current == null) {
      throw IncidentNotFoundException(
        'Incident ${normalizedInput.incidentId} does not exist.',
      );
    }
    if (current.status.isTerminal) {
      throw IncidentReadOnlyException(
        '${current.status.displayLabel} incidents are read-only.',
      );
    }
    if (normalizedInput.status != current.status ||
        !_listsAreEqual(normalizedInput.statusHistory, current.statusHistory)) {
      throw const IncidentValidationException(
        'Use the explicit status action to change incident status.',
      );
    }

    final updated = normalizedInput.copyWith(
      dataSource: current.dataSource,
      createdAt: current.createdAt,
      updatedAt: _clock(),
      status: current.status,
      statusHistory: current.statusHistory,
      delayEstimate: _estimate(normalizedInput),
    );
    _validate(updated);
    _incidents[key] = updated;
    return updated.copyWith();
  }

  @override
  Future<Incident> transitionStatus(
    String incidentId,
    IncidentStatus targetStatus, {
    required String changedBy,
    String? note,
  }) async {
    final key = _keyFor(incidentId);
    final current = _incidents[key];
    if (current == null) {
      throw IncidentNotFoundException('Incident $incidentId does not exist.');
    }
    if (!current.status.canTransitionTo(targetStatus)) {
      throw IncidentValidationException(
        'Cannot change incident status from ${current.status.displayLabel} '
        'to ${targetStatus.displayLabel}.',
      );
    }

    final now = _clock();
    final change = IncidentStatusChange(
      fromStatus: current.status,
      toStatus: targetStatus,
      changedAt: now,
      changedBy: changedBy.trim(),
      note: note?.trim(),
    );
    final updated = current.copyWith(
      status: targetStatus,
      updatedAt: now,
      statusHistory: [...current.statusHistory, change],
    );
    _validate(updated);
    _incidents[key] = updated;
    return updated.copyWith();
  }

  @override
  Future<void> delete(String incidentId) async {
    final key = _keyFor(incidentId);
    final incident = _incidents[key];
    if (incident == null) {
      throw IncidentNotFoundException('Incident $incidentId does not exist.');
    }
    if (!incident.status.canBeDeleted) {
      throw IncidentDeletionException(
        'Only Reported or Cancelled incidents may be permanently deleted.',
      );
    }
    _incidents.remove(key);
  }

  void _validate(Incident incident) {
    final issues = IncidentValidator.validate(incident, now: _clock());
    if (issues.isNotEmpty) {
      throw IncidentValidationException(
        issues.map((issue) => issue.message).join(' '),
        issues: List<IncidentValidationIssue>.unmodifiable(issues),
      );
    }
  }

  Incident _normalize(Incident incident) {
    return incident.copyWith(
      incidentId: incident.incidentId.trim(),
      title: incident.title.trim(),
      description: incident.description.trim(),
      routeId: incident.routeId.trim(),
      routeName: incident.routeName?.trim(),
      vehicleId: incident.vehicleId?.trim(),
      location: incident.location.trim(),
      reportedBy: incident.reportedBy.trim(),
      statusHistory: incident.statusHistory
          .map(
            (change) => IncidentStatusChange(
              fromStatus: change.fromStatus,
              toStatus: change.toStatus,
              changedAt: change.changedAt,
              changedBy: change.changedBy.trim(),
              note: change.note?.trim(),
            ),
          )
          .toList(growable: false),
    );
  }

  DelayEstimate _estimate(Incident incident) {
    return _estimator.estimate(
      incidentType: incident.incidentType,
      severity: incident.severity,
      vehicleCondition: incident.vehicleCondition,
      disruptionScope: incident.disruptionScope,
      reportedAt: MalaysiaTime.instantToWallClock(incident.reportedAt),
    );
  }

  static String _keyFor(String incidentId) => incidentId.trim().toLowerCase();

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
