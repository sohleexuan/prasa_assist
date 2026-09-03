import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/incidents/data/incident_demo_data.dart';
import 'package:prasa_assist/features/incidents/models/incident.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';
import 'package:prasa_assist/features/incidents/models/incident_query.dart';
import 'package:prasa_assist/features/incidents/models/incident_status_change.dart';
import 'package:prasa_assist/features/incidents/pages/incident_list_page.dart';
import 'package:prasa_assist/features/incidents/repositories/in_memory_incident_repository.dart';
import 'package:prasa_assist/features/incidents/repositories/incident_repository.dart';
import 'package:prasa_assist/features/incidents/services/delay_estimator.dart';
import 'package:prasa_assist/features/incidents/widgets/incident_card.dart';
import 'package:prasa_assist/shared/staff/staff_directory_repository.dart';
import 'package:prasa_assist/shared/staff/staff_profile.dart';

void main() {
  testWidgets('is a normal page and loads labelled demonstration data', (
    tester,
  ) async {
    await _pumpPage(tester);

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(IncidentListPage), findsOneWidget);
    expect(find.text('Incident Management'), findsOneWidget);
    expect(find.text('Module 1 Prototype'), findsOneWidget);
    expect(find.text('Mock / Demonstration Data'), findsWidgets);
    expect(
      find.textContaining('Changes reset when the app restarts'),
      findsOneWidget,
    );
    expect(_card('INC-20260828-001'), findsOneWidget);
    expect(find.text('Bus B1023 breakdown'), findsOneWidget);
    expect(_resultCount(tester), '1 record');
  });

  testWidgets('shows Loading while the repository is waiting', (tester) async {
    final repository = _DelayedRepository();

    await _pumpPage(tester, repository: repository, finishLoading: false);

    expect(find.text('Loading incidents...'), findsOneWidget);
    repository.complete([IncidentDemoData.busB1023()]);
    await tester.pump();
    await tester.pump();
    expect(_card('INC-20260828-001'), findsOneWidget);
  });

  testWidgets('shows the true empty state and report action', (tester) async {
    var reportCount = 0;
    await _pumpPage(
      tester,
      repository: InMemoryIncidentRepository(),
      onReportIncident: () => reportCount++,
    );

    expect(find.text('No incidents reported'), findsOneWidget);
    expect(find.textContaining('Report the first operational'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('report-incident-button')));
    await tester.pump();
    expect(reportCount, 1);
  });

  testWidgets('shows a safe error and Retry reloads data', (tester) async {
    final repository = _RetryRepository(
      seedData: [IncidentDemoData.busB1023()],
    );
    await _pumpPage(tester, repository: repository);

    expect(find.text('Unable to load incidents'), findsOneWidget);
    expect(find.text('Temporary incident failure.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(_card('INC-20260828-001'), findsOneWidget);
    expect(repository.getAllCallCount, 2);
  });

  testWidgets('searches, distinguishes no matches, and clears filters', (
    tester,
  ) async {
    await _pumpPage(tester, incidents: _filterIncidents());

    await tester.enterText(
      find.byKey(const ValueKey('incident-search-field')),
      'platform',
    );
    await _finishQuery(tester);

    expect(_card('INC-SAFETY'), findsOneWidget);
    expect(_card('INC-BUS'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('incident-search-field')),
      'not present',
    );
    await _finishQuery(tester);
    expect(find.text('No matching incidents'), findsOneWidget);
    expect(find.text('No incidents reported'), findsNothing);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('clear-incident-filters')),
    );
    await _finishQuery(tester);
    expect(_resultCount(tester), '3 records');
    expect(find.text('No matching incidents'), findsNothing);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('incident-search-field')),
          )
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('combines status, severity, and type UI filters', (tester) async {
    await _pumpPage(tester, incidents: _filterIncidents());

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('incident-status-filter-underReview')),
    );
    await _finishQuery(tester);
    expect(_card('INC-SAFETY'), findsOneWidget);
    expect(_card('INC-BUS'), findsNothing);

    await _selectDropdown(
      tester,
      keyPrefix: 'incident-severity-filter-',
      option: 'Critical',
    );
    await _finishQuery(tester);
    expect(_card('INC-SAFETY'), findsOneWidget);

    await _selectDropdown(
      tester,
      keyPrefix: 'incident-type-filter-',
      option: 'Vehicle Breakdown',
    );
    await _finishQuery(tester);
    expect(find.text('No matching incidents'), findsOneWidget);
  });

  testWidgets('sort control changes the visible Incident order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpPage(tester, incidents: _filterIncidents());

    expect(_visibleCardIds(tester), ['INC-SAFETY', 'INC-BUS', 'INC-SERVICE']);

    await _selectDropdown(
      tester,
      keyPrefix: 'incident-sort-',
      option: 'Oldest Reported First',
    );
    await _finishQuery(tester);

    expect(_visibleCardIds(tester), ['INC-SERVICE', 'INC-BUS', 'INC-SAFETY']);
  });

  testWidgets('invokes report and open callbacks', (tester) async {
    var reportCount = 0;
    Incident? openedIncident;
    await _pumpPage(
      tester,
      onReportIncident: () => reportCount++,
      onOpenIncident: (incident) => openedIncident = incident,
    );

    await tester.tap(find.byKey(const ValueKey('report-incident-button')));
    await tester.pump();
    expect(reportCount, 1);

    await _tapVisible(tester, _card('INC-20260828-001'));
    await tester.pump();
    expect(openedIncident?.incidentId, 'INC-20260828-001');
  });

  testWidgets('report form resolves the current label from full directory', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      staffDirectoryRepository: _IncidentDirectoryFake(),
      currentUserId: _staffUserId,
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('report-incident-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Operations Staff (O-001)'), findsOneWidget);
    expect(find.textContaining(_staffUserId), findsNothing);
  });

  testWidgets('remains overflow-free at 320px width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpPage(tester, incidents: _filterIncidents());

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  IncidentRepository? repository,
  Iterable<Incident>? incidents,
  VoidCallback? onReportIncident,
  ValueChanged<Incident>? onOpenIncident,
  StaffDirectoryRepository? staffDirectoryRepository,
  String? currentUserId,
  bool finishLoading = true,
}) async {
  final effectiveRepository =
      repository ??
      (incidents == null
          ? InMemoryIncidentRepository.withDemonstrationData(
              clock: () => DateTime(2026, 8, 28, 12),
            )
          : InMemoryIncidentRepository(
              seedData: incidents,
              clock: () => DateTime(2026, 8, 28, 12),
            ));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: IncidentListPage(
        currentStaffId: 'staff-001',
        currentUserId: currentUserId,
        staffDirectoryRepository: staffDirectoryRepository,
        repository: effectiveRepository,
        onReportIncident: onReportIncident,
        onOpenIncident: onOpenIncident,
      ),
    ),
  );
  await tester.pump();
  if (finishLoading) {
    await tester.pump();
  }
}

class _IncidentDirectoryFake implements StaffDirectoryRepository {
  @override
  Future<StaffDirectorySnapshot> load() async => StaffDirectorySnapshot(
    profiles: [
      StaffProfile(
        userId: _staffUserId,
        staffCode: 'o-001',
        displayName: 'Operations Staff',
        role: StaffRole.operationsStaff,
        active: true,
        version: 1,
      ),
    ],
    source: StaffDirectorySource.liveSupabase,
    retrievedAt: DateTime.utc(2026, 9, 4),
    isStale: false,
  );

  @override
  Future<StaffDirectorySnapshot> loadAssignable() async =>
      StaffDirectorySnapshot(
        profiles: const [],
        source: StaffDirectorySource.liveSupabase,
        retrievedAt: DateTime.utc(2026, 9, 4),
        isStale: false,
      );
}

const _staffUserId = '22222222-2222-4222-8222-222222222222';

Future<void> _finishQuery(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _selectDropdown(
  WidgetTester tester, {
  required String keyPrefix,
  required String option,
}) async {
  final dropdown = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        ((widget.key! as ValueKey<String>).value).startsWith(keyPrefix),
  );
  await _tapVisible(tester, dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Finder _card(String incidentId) {
  return find.byKey(ValueKey('incident-card-$incidentId'));
}

String _resultCount(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const ValueKey('incident-result-count')))
      .data!;
}

List<String> _visibleCardIds(WidgetTester tester) {
  return tester
      .widgetList<IncidentCard>(find.byType(IncidentCard))
      .map((card) => card.incident.incidentId)
      .toList();
}

class _DelayedRepository extends InMemoryIncidentRepository {
  final Completer<List<Incident>> _completer = Completer<List<Incident>>();

  @override
  Future<List<Incident>> getAll({IncidentQuery? query}) => _completer.future;

  void complete(List<Incident> incidents) {
    _completer.complete(incidents);
  }
}

class _RetryRepository extends InMemoryIncidentRepository {
  _RetryRepository({required super.seedData})
    : super(clock: _repositoryTestClock);

  int getAllCallCount = 0;

  @override
  Future<List<Incident>> getAll({IncidentQuery? query}) {
    getAllCallCount++;
    if (getAllCallCount == 1) {
      throw StateError('Temporary incident failure.');
    }
    return super.getAll(query: query);
  }
}

DateTime _repositoryTestClock() => DateTime(2026, 8, 28, 12);

List<Incident> _filterIncidents() {
  return [
    _incident(
      incidentId: 'INC-BUS',
      title: 'Bus B1023 breakdown',
      incidentType: IncidentType.vehicleBreakdown,
      vehicleId: 'B1023',
      severity: IncidentSeverity.high,
      status: IncidentStatus.active,
      reportedAt: DateTime(2026, 8, 28, 8),
    ),
    _incident(
      incidentId: 'INC-SAFETY',
      title: 'Platform safety inspection',
      incidentType: IncidentType.safetyIncident,
      vehicleId: null,
      severity: IncidentSeverity.critical,
      status: IncidentStatus.underReview,
      reportedAt: DateTime(2026, 8, 28, 9),
    ),
    _incident(
      incidentId: 'INC-SERVICE',
      title: 'Route 300 service disruption',
      incidentType: IncidentType.serviceDisruption,
      vehicleId: null,
      severity: IncidentSeverity.medium,
      status: IncidentStatus.reported,
      reportedAt: DateTime(2026, 8, 28, 7),
    ),
  ];
}

Incident _incident({
  required String incidentId,
  required String title,
  required IncidentType incidentType,
  required String? vehicleId,
  required IncidentSeverity severity,
  required IncidentStatus status,
  required DateTime reportedAt,
}) {
  final createdAt = reportedAt.add(const Duration(minutes: 1));
  final history = _historyFor(status, createdAt);
  final vehicleCondition = vehicleId == null
      ? VehicleCondition.unknown
      : VehicleCondition.immobilised;
  return Incident(
    incidentId: incidentId,
    incidentType: incidentType,
    title: title,
    description: 'Operational incident details for list page testing.',
    routeId: incidentId == 'INC-SAFETY' ? '301' : '300',
    routeName: incidentId == 'INC-SAFETY' ? 'Route 301' : 'Route 300',
    vehicleId: vehicleId,
    location: 'Test operations location',
    reportedAt: reportedAt,
    severity: severity,
    status: status,
    vehicleCondition: vehicleCondition,
    disruptionScope: DisruptionScope.partialObstruction,
    delayEstimate: const DelayEstimator().estimate(
      incidentType: incidentType,
      severity: severity,
      vehicleCondition: vehicleCondition,
      disruptionScope: DisruptionScope.partialObstruction,
      reportedAt: reportedAt,
    ),
    reportedBy: 'Operations Staff',
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
  return history;
}
