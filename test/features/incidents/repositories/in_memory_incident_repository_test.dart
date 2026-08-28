import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/models/delay_estimate.dart';
import 'package:prasa_assist/features/incidents/models/incident.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';
import 'package:prasa_assist/features/incidents/models/incident_query.dart';
import 'package:prasa_assist/features/incidents/models/incident_status_change.dart';
import 'package:prasa_assist/features/incidents/repositories/in_memory_incident_repository.dart';
import 'package:prasa_assist/features/incidents/repositories/incident_data_exception.dart';
import 'package:prasa_assist/features/incidents/services/delay_estimator.dart';

void main() {
  group('InMemoryIncidentRepository demonstration data', () {
    test('provides the labelled Bus B1023 and Route 300 scenario', () async {
      final repository = InMemoryIncidentRepository.withDemonstrationData(
        clock: () => DateTime(2026, 8, 28, 12),
      );

      final incidents = await repository.getAll();

      expect(incidents, hasLength(1));
      expect(incidents.single.vehicleId, 'B1023');
      expect(incidents.single.routeId, '300');
      expect(incidents.single.dataSource, IncidentDataSource.mockDemonstration);
      expect(incidents.single.estimatedDelayMinutes, 75);
      expect(incidents.single.impactLevel, OperationalImpactLevel.severe);
    });
  });

  group('InMemoryIncidentRepository CRUD', () {
    test('creates a normalized Incident with repository timestamps', () async {
      final clock = _MutableClock(DateTime(2026, 8, 28, 10));
      final repository = InMemoryIncidentRepository(clock: clock.call);
      final input = _incident(
        incidentId: ' INC-001 ',
        title: ' Bus B1023 breakdown ',
        reportedBy: ' Leong Yong Quan ',
      );

      final created = await repository.create(input);

      expect(created.incidentId, 'INC-001');
      expect(created.title, 'Bus B1023 breakdown');
      expect(created.reportedBy, 'Leong Yong Quan');
      expect(created.createdAt, clock.value);
      expect(created.updatedAt, clock.value);
      expect(created.statusHistory.single.changedAt, clock.value);
      expect(await repository.getById(' inc-001 '), created);
    });

    test('recalculates delay instead of trusting the input result', () async {
      final repository = InMemoryIncidentRepository(
        clock: () => DateTime(2026, 8, 28, 10),
      );
      final input = _incident().copyWith(
        delayEstimate: DelayEstimate(
          estimatedDelayMinutes: 5,
          impactLevel: OperationalImpactLevel.minor,
          reasons: const ['Stale value.'],
        ),
      );

      final created = await repository.create(input);

      expect(created.estimatedDelayMinutes, 75);
      expect(created.impactLevel, OperationalImpactLevel.severe);
      expect(created.estimationReasons, isNot(contains('Stale value.')));
    });

    test('rejects duplicate IDs without case sensitivity', () async {
      final repository = InMemoryIncidentRepository(
        clock: () => DateTime(2026, 8, 28, 10),
      );
      await repository.create(_incident(incidentId: 'INC-001'));

      await expectLater(
        repository.create(_incident(incidentId: 'inc-001')),
        throwsA(isA<IncidentDuplicateException>()),
      );
    });

    test('requires a new Incident to begin as Reported', () async {
      final repository = InMemoryIncidentRepository(
        clock: () => DateTime(2026, 8, 28, 10),
      );

      await expectLater(
        repository.create(_incident(status: IncidentStatus.active)),
        throwsA(
          isA<IncidentValidationException>().having(
            (error) => error.message,
            'message',
            contains('must begin with one Reported'),
          ),
        ),
      );
    });

    test('validates before storing a new Incident', () async {
      final repository = InMemoryIncidentRepository(
        clock: () => DateTime(2026, 8, 28, 10),
      );

      await expectLater(
        repository.create(_incident(routeId: '')),
        throwsA(
          isA<IncidentValidationException>().having(
            (error) => error.issues,
            'issues',
            isNotEmpty,
          ),
        ),
      );
      expect(await repository.getAll(), isEmpty);
    });

    test('updates editable data and recalculates the estimate', () async {
      final clock = _MutableClock(DateTime(2026, 8, 28, 10));
      final repository = InMemoryIncidentRepository(clock: clock.call);
      final created = await repository.create(_incident());
      clock.value = DateTime(2026, 8, 28, 10, 5);

      final updated = await repository.update(
        created.copyWith(
          severity: IncidentSeverity.critical,
          description: 'Updated operational details for the breakdown.',
        ),
      );

      expect(updated.severity, IncidentSeverity.critical);
      expect(updated.description, contains('Updated operational details'));
      expect(updated.estimatedDelayMinutes, 94);
      expect(updated.createdAt, created.createdAt);
      expect(updated.updatedAt, clock.value);
      expect(updated.statusHistory, created.statusHistory);
    });

    test('rejects update for a missing Incident', () async {
      final repository = InMemoryIncidentRepository(
        clock: () => DateTime(2026, 8, 28, 10),
      );

      await expectLater(
        repository.update(_incident()),
        throwsA(isA<IncidentNotFoundException>()),
      );
    });

    test('prevents normal update from bypassing status actions', () async {
      final repository = InMemoryIncidentRepository(
        clock: () => DateTime(2026, 8, 28, 10),
      );
      final created = await repository.create(_incident());

      await expectLater(
        repository.update(created.copyWith(status: IncidentStatus.active)),
        throwsA(
          isA<IncidentValidationException>().having(
            (error) => error.message,
            'message',
            contains('explicit status action'),
          ),
        ),
      );
    });

    test('treats Resolved and Cancelled records as read-only', () async {
      for (final status in [
        IncidentStatus.resolved,
        IncidentStatus.cancelled,
      ]) {
        final repository = InMemoryIncidentRepository(
          seedData: [_incident(status: status)],
          clock: () => DateTime(2026, 8, 28, 12),
        );

        await expectLater(
          repository.update(
            (await repository.getById('INC-001'))!
                .copyWith(title: 'Attempted edit'),
          ),
          throwsA(isA<IncidentReadOnlyException>()),
        );
      }
    });

    test('returns an unmodifiable list containing value copies', () async {
      final seed = _incident();
      final repository = InMemoryIncidentRepository(
        seedData: [seed],
        clock: () => DateTime(2026, 8, 28, 12),
      );

      final first = await repository.getAll();
      final second = await repository.getAll();

      expect(() => first.add(_incident()), throwsUnsupportedError);
      expect(identical(first.single, seed), isFalse);
      expect(identical(first.single, second.single), isFalse);
      expect(first.single, second.single);
    });
  });

  group('InMemoryIncidentRepository status and delete rules', () {
    test('performs an explicit transition and appends audit history', () async {
      final clock = _MutableClock(DateTime(2026, 8, 28, 10));
      final repository = InMemoryIncidentRepository(clock: clock.call);
      await repository.create(_incident());
      clock.value = DateTime(2026, 8, 28, 10, 10);

      final updated = await repository.transitionStatus(
        'INC-001',
        IncidentStatus.underReview,
        changedBy: ' Control Centre Staff ',
        note: ' Reviewing vehicle condition. ',
      );

      expect(updated.status, IncidentStatus.underReview);
      expect(updated.updatedAt, clock.value);
      expect(updated.statusHistory, hasLength(2));
      expect(updated.statusHistory.last.changedBy, 'Control Centre Staff');
      expect(updated.statusHistory.last.note, 'Reviewing vehicle condition.');
    });

    test('rejects invalid and incomplete status actions atomically', () async {
      final repository = InMemoryIncidentRepository(
        clock: () => DateTime(2026, 8, 28, 10),
      );
      await repository.create(_incident());

      await expectLater(
        repository.transitionStatus(
          'INC-001',
          IncidentStatus.resolved,
          changedBy: 'Operations Staff',
        ),
        throwsA(isA<IncidentValidationException>()),
      );
      await expectLater(
        repository.transitionStatus(
          'INC-001',
          IncidentStatus.underReview,
          changedBy: ' ',
        ),
        throwsA(isA<IncidentValidationException>()),
      );

      final stored = await repository.getById('INC-001');
      expect(stored!.status, IncidentStatus.reported);
      expect(stored.statusHistory, hasLength(1));
    });

    test('rejects transition for a missing Incident', () async {
      final repository = InMemoryIncidentRepository(
        clock: () => DateTime(2026, 8, 28, 10),
      );

      await expectLater(
        repository.transitionStatus(
          'MISSING',
          IncidentStatus.underReview,
          changedBy: 'Operations Staff',
        ),
        throwsA(isA<IncidentNotFoundException>()),
      );
    });

    test('allows Reported and Cancelled records to be deleted', () async {
      for (final status in [
        IncidentStatus.reported,
        IncidentStatus.cancelled,
      ]) {
        final repository = InMemoryIncidentRepository(
          seedData: [_incident(status: status)],
          clock: () => DateTime(2026, 8, 28, 12),
        );

        await repository.delete(' inc-001 ');

        expect(await repository.getAll(), isEmpty);
      }
    });

    test('rejects deletion of protected operational records', () async {
      for (final status in [
        IncidentStatus.underReview,
        IncidentStatus.active,
        IncidentStatus.resolved,
      ]) {
        final repository = InMemoryIncidentRepository(
          seedData: [_incident(status: status)],
          clock: () => DateTime(2026, 8, 28, 12),
        );

        await expectLater(
          repository.delete('INC-001'),
          throwsA(isA<IncidentDeletionException>()),
          reason: '${status.displayLabel} must not be deleted',
        );
      }
    });

    test('rejects delete for a missing Incident', () async {
      final repository = InMemoryIncidentRepository(
        clock: () => DateTime(2026, 8, 28, 10),
      );

      await expectLater(
        repository.delete('MISSING'),
        throwsA(isA<IncidentNotFoundException>()),
      );
    });
  });

  group('InMemoryIncidentRepository search, filters, and sorting', () {
    late InMemoryIncidentRepository repository;

    setUp(() {
      repository = InMemoryIncidentRepository(
        seedData: [
          _incident(
            incidentId: 'INC-001',
            title: 'Bus B1023 breakdown',
            reportedAt: DateTime(2026, 8, 28, 8),
            severity: IncidentSeverity.high,
            status: IncidentStatus.active,
          ),
          _incident(
            incidentId: 'INC-002',
            incidentType: IncidentType.safetyIncident,
            title: 'Platform safety inspection',
            routeId: '301',
            vehicleId: null,
            reportedAt: DateTime(2026, 8, 28, 9),
            severity: IncidentSeverity.critical,
            status: IncidentStatus.underReview,
          ),
          _incident(
            incidentId: 'INC-003',
            incidentType: IncidentType.serviceDisruption,
            title: 'Route 300 service disruption',
            vehicleId: null,
            reportedAt: DateTime(2026, 8, 28, 7),
            severity: IncidentSeverity.medium,
          ),
        ],
        clock: () => DateTime(2026, 8, 28, 12),
      );
    });

    test('searches without case sensitivity', () async {
      final results = await repository.getAll(
        query: IncidentQuery(searchTerm: '  b1023  '),
      );

      expect(results.map((incident) => incident.incidentId), ['INC-001']);
    });

    test(
      'combines status, severity, and type filters with AND logic',
      () async {
        final results = await repository.getAll(
          query: IncidentQuery(
            statuses: const {
              IncidentStatus.reported,
              IncidentStatus.underReview,
            },
            severities: const {
              IncidentSeverity.medium,
              IncidentSeverity.critical,
            },
            incidentTypes: const {IncidentType.serviceDisruption},
          ),
        );

        expect(results.map((incident) => incident.incidentId), ['INC-003']);
      },
    );

    test('returns an empty list when nothing matches', () async {
      final results = await repository.getAll(
        query: IncidentQuery(searchTerm: 'not present'),
      );

      expect(results, isEmpty);
    });

    test('sorts by every supported order', () async {
      Future<List<String>> idsFor(IncidentSortOrder order) async {
        final results = await repository.getAll(
          query: IncidentQuery(sortOrder: order),
        );
        return results.map((incident) => incident.incidentId).toList();
      }

      expect(await idsFor(IncidentSortOrder.newestReported), [
        'INC-002',
        'INC-001',
        'INC-003',
      ]);
      expect(await idsFor(IncidentSortOrder.oldestReported), [
        'INC-003',
        'INC-001',
        'INC-002',
      ]);
      expect(await idsFor(IncidentSortOrder.highestSeverity), [
        'INC-002',
        'INC-001',
        'INC-003',
      ]);
      expect(await idsFor(IncidentSortOrder.longestEstimatedDelay), [
        'INC-001',
        'INC-002',
        'INC-003',
      ]);
      expect(await idsFor(IncidentSortOrder.recentlyUpdated), [
        'INC-002',
        'INC-001',
        'INC-003',
      ]);
    });
  });

  test('rejects duplicate IDs in seed data without case sensitivity', () {
    expect(
      () => InMemoryIncidentRepository(
        seedData: [
          _incident(incidentId: 'INC-001'),
          _incident(incidentId: 'inc-001'),
        ],
        clock: () => DateTime(2026, 8, 28, 12),
      ),
      throwsA(isA<StateError>()),
    );
  });
}

class _MutableClock {
  _MutableClock(this.value);

  DateTime value;

  DateTime call() => value;
}

Incident _incident({
  String incidentId = 'INC-001',
  IncidentType incidentType = IncidentType.vehicleBreakdown,
  String title = 'Bus B1023 breakdown',
  String routeId = '300',
  String? vehicleId = 'B1023',
  DateTime? reportedAt,
  IncidentSeverity severity = IncidentSeverity.high,
  IncidentStatus status = IncidentStatus.reported,
  String reportedBy = 'Leong Yong Quan',
}) {
  final reportTime = reportedAt ?? DateTime(2026, 8, 28, 8);
  final createdAt = reportTime.add(const Duration(minutes: 1));
  final history = _historyFor(status, createdAt);
  final estimator = const DelayEstimator();
  return Incident(
    incidentId: incidentId,
    incidentType: incidentType,
    title: title,
    description: 'Operational incident details recorded for testing.',
    routeId: routeId,
    routeName: 'Route $routeId',
    vehicleId: vehicleId,
    location: 'Test operations location',
    reportedAt: reportTime,
    severity: severity,
    status: status,
    vehicleCondition: vehicleId == null
        ? VehicleCondition.unknown
        : VehicleCondition.immobilised,
    disruptionScope: DisruptionScope.partialObstruction,
    delayEstimate: estimator.estimate(
      incidentType: incidentType,
      severity: severity,
      vehicleCondition: vehicleId == null
          ? VehicleCondition.unknown
          : VehicleCondition.immobilised,
      disruptionScope: DisruptionScope.partialObstruction,
      reportedAt: reportTime,
    ),
    reportedBy: reportedBy,
    dataSource: IncidentDataSource.staffEntered,
    createdAt: createdAt,
    updatedAt: history.last.changedAt,
    statusHistory: history,
  );
}

List<IncidentStatusChange> _historyFor(
  IncidentStatus status,
  DateTime createdAt,
) {
  final history = <IncidentStatusChange>[
    IncidentStatusChange(
      fromStatus: null,
      toStatus: IncidentStatus.reported,
      changedAt: createdAt,
      changedBy: 'Operations Staff',
    ),
  ];
  if (status == IncidentStatus.reported) {
    return history;
  }
  if (status == IncidentStatus.cancelled) {
    return [
      ...history,
      IncidentStatusChange(
        fromStatus: IncidentStatus.reported,
        toStatus: IncidentStatus.cancelled,
        changedAt: createdAt.add(const Duration(minutes: 1)),
        changedBy: 'Operations Staff',
      ),
    ];
  }

  history.add(
    IncidentStatusChange(
      fromStatus: IncidentStatus.reported,
      toStatus: IncidentStatus.underReview,
      changedAt: createdAt.add(const Duration(minutes: 1)),
      changedBy: 'Operations Staff',
    ),
  );
  if (status == IncidentStatus.underReview) {
    return history;
  }
  history.add(
    IncidentStatusChange(
      fromStatus: IncidentStatus.underReview,
      toStatus: IncidentStatus.active,
      changedAt: createdAt.add(const Duration(minutes: 2)),
      changedBy: 'Operations Staff',
    ),
  );
  if (status == IncidentStatus.active) {
    return history;
  }
  history.add(
    IncidentStatusChange(
      fromStatus: IncidentStatus.active,
      toStatus: IncidentStatus.resolved,
      changedAt: createdAt.add(const Duration(minutes: 3)),
      changedBy: 'Operations Staff',
    ),
  );
  return history;
}
