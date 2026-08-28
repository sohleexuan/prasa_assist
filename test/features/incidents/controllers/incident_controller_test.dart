import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/controllers/incident_controller.dart';
import 'package:prasa_assist/features/incidents/controllers/incident_state.dart';
import 'package:prasa_assist/features/incidents/models/incident.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';
import 'package:prasa_assist/features/incidents/models/incident_query.dart';
import 'package:prasa_assist/features/incidents/models/incident_status_change.dart';
import 'package:prasa_assist/features/incidents/repositories/in_memory_incident_repository.dart';
import 'package:prasa_assist/features/incidents/repositories/incident_data_exception.dart';
import 'package:prasa_assist/features/incidents/repositories/incident_repository.dart';
import 'package:prasa_assist/features/incidents/services/delay_estimator.dart';

void main() {
  group('IncidentController loading and selection', () {
    test('starts in the documented initial state', () {
      final controller = IncidentController(
        repository: InMemoryIncidentRepository(),
      );

      expect(controller.state.status, IncidentStateStatus.initial);
      expect(controller.incidents, isEmpty);
      expect(controller.selectedIncident, isNull);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
    });

    test('exposes loading then immutable loaded data', () async {
      final repository = _DelayedIncidentRepository();
      final controller = IncidentController(repository: repository);
      var notificationCount = 0;
      controller.addListener(() => notificationCount++);

      final loadFuture = controller.loadIncidents();

      expect(controller.state.status, IncidentStateStatus.loading);
      expect(controller.isLoading, isTrue);
      repository.completeGetAll([_incident()]);
      await loadFuture;

      expect(controller.state.status, IncidentStateStatus.loaded);
      expect(controller.incidents, [_incident()]);
      expect(
        () => controller.incidents.add(_incident(incidentId: 'INC-002')),
        throwsUnsupportedError,
      );
      expect(notificationCount, 2);
    });

    test('uses Empty when the repository has no incidents', () async {
      final controller = IncidentController(
        repository: InMemoryIncidentRepository(),
      );

      await controller.loadIncidents();

      expect(controller.state.status, IncidentStateStatus.empty);
      expect(controller.incidents, isEmpty);
      expect(controller.errorMessage, isNull);
    });

    test(
      'selects an Incident and reports a missing selection safely',
      () async {
        final repository = InMemoryIncidentRepository(
          seedData: [_incident()],
          clock: () => DateTime(2026, 8, 28, 12),
        );
        final controller = IncidentController(repository: repository);
        await controller.loadIncidents();

        expect(await controller.selectIncident('INC-001'), _incident());
        expect(controller.selectedIncident, _incident());

        expect(await controller.selectIncident('MISSING'), isNull);
        expect(controller.state.status, IncidentStateStatus.error);
        expect(controller.errorMessage, 'Incident MISSING does not exist.');
        expect(controller.selectedIncident, isNull);
      },
    );

    test('clearSelection removes only the selected Incident', () async {
      final repository = InMemoryIncidentRepository(
        seedData: [_incident()],
        clock: () => DateTime(2026, 8, 28, 12),
      );
      final controller = IncidentController(repository: repository);
      await controller.loadIncidents();
      await controller.selectIncident('INC-001');

      controller.clearSelection();

      expect(controller.selectedIncident, isNull);
      expect(controller.incidents, [_incident()]);
      expect(controller.state.status, IncidentStateStatus.loaded);
    });
  });

  group('IncidentController errors and retry', () {
    test('uses safe repository messages and can clear the error', () async {
      final controller = IncidentController(
        repository: _AlwaysFailingRepository(
          const IncidentReadOnlyException('Safe incident error.'),
        ),
      );

      await controller.loadIncidents();

      expect(controller.state.status, IncidentStateStatus.error);
      expect(controller.errorMessage, 'Safe incident error.');
      expect(controller.isLoading, isFalse);

      controller.clearError();

      expect(controller.state.status, IncidentStateStatus.empty);
      expect(controller.errorMessage, isNull);
    });

    test('does not expose unknown exception details', () async {
      final controller = IncidentController(
        repository: _AlwaysFailingRepository(Exception('secret details')),
      );

      await controller.loadIncidents();

      expect(
        controller.errorMessage,
        'Unable to complete the incident operation.',
      );
      expect(controller.errorMessage, isNot(contains('secret')));
    });

    test('a later load retries after a temporary failure', () async {
      final repository = _FailOnceRepository([_incident()]);
      final controller = IncidentController(repository: repository);

      await controller.loadIncidents();
      expect(controller.state.status, IncidentStateStatus.error);

      await controller.loadIncidents();
      expect(controller.state.status, IncidentStateStatus.loaded);
      expect(controller.incidents, [_incident()]);
      expect(controller.errorMessage, isNull);
    });
  });

  group('IncidentController query', () {
    test('stores the query and refreshes matching data', () async {
      final repository = InMemoryIncidentRepository(
        seedData: [
          _incident(),
          _incident(
            incidentId: 'INC-002',
            title: 'Platform safety incident',
            incidentType: IncidentType.safetyIncident,
            vehicleId: null,
          ),
        ],
        clock: () => DateTime(2026, 8, 28, 12),
      );
      final controller = IncidentController(repository: repository);
      final query = IncidentQuery(searchTerm: 'B1023');

      await controller.updateQuery(query);

      expect(controller.state.query, same(query));
      expect(controller.state.hasActiveQuery, isTrue);
      expect(controller.incidents.map((incident) => incident.incidentId), [
        'INC-001',
      ]);
    });

    test('uses Empty for a query with no matches', () async {
      final controller = IncidentController(
        repository: InMemoryIncidentRepository(
          seedData: [_incident()],
          clock: () => DateTime(2026, 8, 28, 12),
        ),
      );

      await controller.updateQuery(IncidentQuery(searchTerm: 'no match'));

      expect(controller.state.status, IncidentStateStatus.empty);
      expect(controller.state.hasActiveQuery, isTrue);
      expect(controller.incidents, isEmpty);
    });

    test(
      'keeps the newest query when responses complete out of order',
      () async {
        final repository = _OutOfOrderQueryRepository();
        final controller = IncidentController(repository: repository);
        final olderQuery = IncidentQuery(searchTerm: 'older');
        final newerQuery = IncidentQuery(searchTerm: 'newer');

        final olderLoad = controller.updateQuery(olderQuery);
        final newerLoad = controller.updateQuery(newerQuery);
        repository.complete(newerQuery, [
          _incident(incidentId: 'INC-NEW', title: 'Newer result'),
        ]);
        await newerLoad;
        repository.complete(olderQuery, [
          _incident(incidentId: 'INC-OLD', title: 'Older result'),
        ]);
        await olderLoad;

        expect(controller.state.query, same(newerQuery));
        expect(controller.incidents.single.incidentId, 'INC-NEW');
        expect(controller.state.status, IncidentStateStatus.loaded);
      },
    );
  });

  test(
    'does not notify after disposal when a pending load completes',
    () async {
      final repository = _DelayedIncidentRepository();
      final controller = IncidentController(repository: repository);
      var notificationCount = 0;
      controller.addListener(() => notificationCount++);

      final load = controller.loadIncidents();
      expect(notificationCount, 1);
      controller.dispose();
      repository.completeGetAll([_incident()]);

      await expectLater(load, completes);
      expect(notificationCount, 1);
    },
  );

  group('IncidentController mutations', () {
    test('creates, updates, and deletes while refreshing the list', () async {
      final clock = _MutableClock(DateTime(2026, 8, 28, 10));
      final repository = InMemoryIncidentRepository(clock: clock.call);
      final controller = IncidentController(repository: repository);

      expect(await controller.createIncident(_incident()), isTrue);
      expect(controller.incidents, hasLength(1));
      expect(controller.selectedIncident, controller.incidents.single);

      clock.value = DateTime(2026, 8, 28, 10, 5);
      final edited = controller.selectedIncident!.copyWith(
        title: 'Updated Bus B1023 breakdown',
      );
      expect(await controller.updateIncident(edited), isTrue);
      expect(controller.incidents.single.title, startsWith('Updated'));
      expect(controller.selectedIncident, controller.incidents.single);

      expect(await controller.deleteIncident(' inc-001 '), isTrue);
      expect(controller.state.status, IncidentStateStatus.empty);
      expect(controller.incidents, isEmpty);
      expect(controller.selectedIncident, isNull);
      expect(controller.errorMessage, isNull);
    });

    test('refreshes using the active query after a mutation', () async {
      final clock = _MutableClock(DateTime(2026, 8, 28, 10));
      final repository = InMemoryIncidentRepository(clock: clock.call);
      final controller = IncidentController(repository: repository);
      await controller.updateQuery(IncidentQuery(searchTerm: 'safety'));

      final created = _incident(
        title: 'Bus B1023 breakdown',
        incidentType: IncidentType.vehicleBreakdown,
      );
      expect(await controller.createIncident(created), isTrue);

      expect(controller.selectedIncident, isNotNull);
      expect(controller.incidents, isEmpty);
      expect(controller.state.status, IncidentStateStatus.empty);
      expect(controller.state.query.searchTerm, 'safety');
    });

    test(
      'changes status through the repository and refreshes history',
      () async {
        final clock = _MutableClock(DateTime(2026, 8, 28, 10));
        final repository = InMemoryIncidentRepository(clock: clock.call);
        final controller = IncidentController(repository: repository);
        await controller.createIncident(_incident());
        clock.value = DateTime(2026, 8, 28, 10, 10);

        expect(
          await controller.changeStatus(
            'INC-001',
            IncidentStatus.underReview,
            changedBy: 'Control Centre Staff',
            note: 'Review started.',
          ),
          isTrue,
        );

        expect(controller.selectedIncident!.status, IncidentStatus.underReview);
        expect(controller.selectedIncident!.statusHistory, hasLength(2));
        expect(controller.incidents.single.status, IncidentStatus.underReview);
        expect(controller.errorMessage, isNull);
      },
    );

    test('keeps data and exposes a safe message when mutation fails', () async {
      final active = _incident(status: IncidentStatus.active);
      final repository = InMemoryIncidentRepository(
        seedData: [active],
        clock: () => DateTime(2026, 8, 28, 12),
      );
      final controller = IncidentController(repository: repository);
      await controller.loadIncidents();

      expect(await controller.deleteIncident(active.incidentId), isFalse);

      expect(controller.state.status, IncidentStateStatus.error);
      expect(controller.errorMessage, contains('Reported or Cancelled'));
      expect(controller.incidents, [active]);
      expect(await repository.getById(active.incidentId), active);
    });

    test('returns false for an invalid status transition', () async {
      final repository = InMemoryIncidentRepository(
        seedData: [_incident()],
        clock: () => DateTime(2026, 8, 28, 12),
      );
      final controller = IncidentController(repository: repository);
      await controller.loadIncidents();

      expect(
        await controller.changeStatus(
          'INC-001',
          IncidentStatus.resolved,
          changedBy: 'Operations Staff',
        ),
        isFalse,
      );
      expect(controller.errorMessage, contains('Reported to Resolved'));
      expect(controller.incidents.single.status, IncidentStatus.reported);
    });
  });
}

class _MutableClock {
  _MutableClock(this.value);

  DateTime value;

  DateTime call() => value;
}

class _DelayedIncidentRepository implements IncidentRepository {
  final Completer<List<Incident>> _getAllCompleter =
      Completer<List<Incident>>();

  @override
  Future<List<Incident>> getAll({IncidentQuery? query}) =>
      _getAllCompleter.future;

  void completeGetAll(List<Incident> incidents) {
    _getAllCompleter.complete(incidents);
  }

  @override
  Future<Incident> create(Incident incident) => throw UnimplementedError();

  @override
  Future<void> delete(String incidentId) => throw UnimplementedError();

  @override
  Future<Incident?> getById(String incidentId) => throw UnimplementedError();

  @override
  Future<Incident> transitionStatus(
    String incidentId,
    IncidentStatus targetStatus, {
    required String changedBy,
    String? note,
  }) => throw UnimplementedError();

  @override
  Future<Incident> update(Incident incident) => throw UnimplementedError();
}

class _AlwaysFailingRepository implements IncidentRepository {
  _AlwaysFailingRepository(this.error);

  final Object error;

  Never _fail() => throw error;

  @override
  Future<List<Incident>> getAll({IncidentQuery? query}) async => _fail();

  @override
  Future<Incident> create(Incident incident) async => _fail();

  @override
  Future<void> delete(String incidentId) async => _fail();

  @override
  Future<Incident?> getById(String incidentId) async => _fail();

  @override
  Future<Incident> transitionStatus(
    String incidentId,
    IncidentStatus targetStatus, {
    required String changedBy,
    String? note,
  }) async => _fail();

  @override
  Future<Incident> update(Incident incident) async => _fail();
}

class _OutOfOrderQueryRepository implements IncidentRepository {
  final Map<IncidentQuery, Completer<List<Incident>>> _requests = {};

  @override
  Future<List<Incident>> getAll({IncidentQuery? query}) {
    final effectiveQuery = query ?? IncidentQuery();
    return (_requests[effectiveQuery] ??= Completer<List<Incident>>()).future;
  }

  void complete(IncidentQuery query, List<Incident> incidents) {
    _requests[query]!.complete(incidents);
  }

  @override
  Future<Incident> create(Incident incident) => throw UnimplementedError();

  @override
  Future<void> delete(String incidentId) => throw UnimplementedError();

  @override
  Future<Incident?> getById(String incidentId) => throw UnimplementedError();

  @override
  Future<Incident> transitionStatus(
    String incidentId,
    IncidentStatus targetStatus, {
    required String changedBy,
    String? note,
  }) => throw UnimplementedError();

  @override
  Future<Incident> update(Incident incident) => throw UnimplementedError();
}

class _FailOnceRepository implements IncidentRepository {
  _FailOnceRepository(this.incidents);

  final List<Incident> incidents;
  var _hasFailed = false;

  @override
  Future<List<Incident>> getAll({IncidentQuery? query}) async {
    if (!_hasFailed) {
      _hasFailed = true;
      throw const IncidentReadOnlyException('Temporary failure.');
    }
    return incidents;
  }

  @override
  Future<Incident> create(Incident incident) => throw UnimplementedError();

  @override
  Future<void> delete(String incidentId) => throw UnimplementedError();

  @override
  Future<Incident?> getById(String incidentId) => throw UnimplementedError();

  @override
  Future<Incident> transitionStatus(
    String incidentId,
    IncidentStatus targetStatus, {
    required String changedBy,
    String? note,
  }) => throw UnimplementedError();

  @override
  Future<Incident> update(Incident incident) => throw UnimplementedError();
}

Incident _incident({
  String incidentId = 'INC-001',
  String title = 'Bus B1023 breakdown',
  IncidentType incidentType = IncidentType.vehicleBreakdown,
  String? vehicleId = 'B1023',
  IncidentStatus status = IncidentStatus.reported,
}) {
  final reportedAt = DateTime(2026, 8, 28, 8);
  final createdAt = DateTime(2026, 8, 28, 8, 1);
  final history = <IncidentStatusChange>[
    IncidentStatusChange(
      fromStatus: null,
      toStatus: IncidentStatus.reported,
      changedAt: createdAt,
      changedBy: 'Operations Staff',
    ),
    if (status == IncidentStatus.active) ...[
      IncidentStatusChange(
        fromStatus: IncidentStatus.reported,
        toStatus: IncidentStatus.underReview,
        changedAt: DateTime(2026, 8, 28, 8, 2),
        changedBy: 'Operations Staff',
      ),
      IncidentStatusChange(
        fromStatus: IncidentStatus.underReview,
        toStatus: IncidentStatus.active,
        changedAt: DateTime(2026, 8, 28, 8, 3),
        changedBy: 'Operations Staff',
      ),
    ],
  ];
  final vehicleCondition = vehicleId == null
      ? VehicleCondition.unknown
      : VehicleCondition.immobilised;
  return Incident(
    incidentId: incidentId,
    incidentType: incidentType,
    title: title,
    description: 'Operational incident details recorded for testing.',
    routeId: '300',
    routeName: 'Route 300',
    vehicleId: vehicleId,
    location: 'Test operations location',
    reportedAt: reportedAt,
    severity: IncidentSeverity.high,
    status: status,
    vehicleCondition: vehicleCondition,
    disruptionScope: DisruptionScope.partialObstruction,
    delayEstimate: const DelayEstimator().estimate(
      incidentType: incidentType,
      severity: IncidentSeverity.high,
      vehicleCondition: vehicleCondition,
      disruptionScope: DisruptionScope.partialObstruction,
      reportedAt: reportedAt,
    ),
    reportedBy: 'Leong Yong Quan',
    dataSource: IncidentDataSource.staffEntered,
    createdAt: createdAt,
    updatedAt: history.last.changedAt,
    statusHistory: history,
  );
}
