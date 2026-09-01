import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/routes/route_catalog.dart';
import 'package:prasa_assist/core/routes/route_catalog_repository.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/incidents/controllers/incident_controller.dart';
import 'package:prasa_assist/features/incidents/data/incident_demo_data.dart';
import 'package:prasa_assist/features/incidents/models/incident.dart';
import 'package:prasa_assist/features/incidents/pages/incident_report_page.dart';
import 'package:prasa_assist/features/incidents/repositories/in_memory_incident_repository.dart';

void main() {
  testWidgets('valid normalized Route ID populates the official Route Name', (
    tester,
  ) async {
    final routeRepository = _FakeRouteCatalogRepository.results([
      () async => _snapshot(),
    ]);
    await _pumpPage(tester, routeRepository: routeRepository);

    await tester.enterText(
      find.byKey(const ValueKey('incident-route-id-field')),
      ' aj01 ',
    );
    await _tapLookup(tester);

    expect(_fieldText(tester, 'incident-route-id-field'), 'AJ01');
    expect(
      _fieldText(tester, 'incident-route-name-field'),
      'Ukay Perdana ~ Taman Melawati via Sg. Sering',
    );
    expect(
      find.byKey(const ValueKey('incident-route-lookup-found')),
      findsOneWidget,
    );
    expect(routeRepository.loadCount, 1);
  });

  testWidgets('unknown Route ID shows a safe not-found message', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      routeRepository: _FakeRouteCatalogRepository.results([
        () async => _snapshot(),
      ]),
    );
    await tester.enterText(
      find.byKey(const ValueKey('incident-route-id-field')),
      '999',
    );
    await _tapLookup(tester);

    expect(
      find.byKey(const ValueKey('incident-route-lookup-notFound')),
      findsOneWidget,
    );
    expect(find.textContaining('No cached government route'), findsOneWidget);
    expect(find.textContaining('enter Route Name manually'), findsOneWidget);
    expect(_fieldText(tester, 'incident-route-name-field'), isEmpty);
  });

  testWidgets(
    'lookup failure preserves data and permits retry or manual entry',
    (tester) async {
      final routeRepository = _FakeRouteCatalogRepository.results([
        () async => throw StateError('private network detail'),
        () async => _snapshot(),
      ]);
      await _pumpPage(tester, routeRepository: routeRepository);
      await tester.enterText(
        find.byKey(const ValueKey('incident-route-id-field')),
        '300',
      );
      await tester.enterText(
        find.byKey(const ValueKey('incident-route-name-field')),
        'Staff-entered route name',
      );

      await _tapLookup(tester);

      expect(
        find.byKey(const ValueKey('incident-route-lookup-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('private network detail'), findsNothing);
      expect(_fieldText(tester, 'incident-route-id-field'), '300');
      expect(
        _fieldText(tester, 'incident-route-name-field'),
        'Staff-entered route name',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('incident-route-name-field')),
            )
            .enabled,
        isTrue,
      );

      await _tapLookup(tester);
      expect(
        _fieldText(tester, 'incident-route-name-field'),
        'Terminal Maluri ~ Lebuh Ampang',
      );
      expect(routeRepository.loadCount, 2);
    },
  );

  testWidgets('blank Route ID performs no lookup', (tester) async {
    final routeRepository = _FakeRouteCatalogRepository.results([
      () async => _snapshot(),
    ]);
    await _pumpPage(tester, routeRepository: routeRepository);

    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('incident-route-lookup-button')),
    );
    expect(button.onPressed, isNull);
    expect(routeRepository.loadCount, 0);
  });

  testWidgets('rapid Route ID changes cannot apply a stale response', (
    tester,
  ) async {
    final catalogCompleter = Completer<RouteCatalogSnapshot>();
    final routeRepository = _FakeRouteCatalogRepository.results([
      () => catalogCompleter.future,
    ]);
    await _pumpPage(tester, routeRepository: routeRepository);

    await tester.enterText(
      find.byKey(const ValueKey('incident-route-id-field')),
      '300',
    );
    await _tapLookup(tester, settle: false);
    expect(
      find.byKey(const ValueKey('incident-route-lookup-progress')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('incident-route-id-field')),
      '302',
    );
    await _tapLookup(tester, settle: false);
    catalogCompleter.complete(_snapshot());
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'incident-route-id-field'), '302');
    expect(
      _fieldText(tester, 'incident-route-name-field'),
      'Titiwangsa ~ KLCC',
    );
    expect(routeRepository.loadCount, 1);
  });

  testWidgets('disposing the form while lookup is pending is safe', (
    tester,
  ) async {
    final catalogCompleter = Completer<RouteCatalogSnapshot>();
    await _pumpPage(
      tester,
      routeRepository: _FakeRouteCatalogRepository.results([
        () => catalogCompleter.future,
      ]),
    );
    await tester.enterText(
      find.byKey(const ValueKey('incident-route-id-field')),
      '300',
    );
    await _tapLookup(tester, settle: false);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    catalogCompleter.complete(_snapshot());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('lookup does not save or submit an Incident', (tester) async {
    final incidentRepository = InMemoryIncidentRepository(clock: _clock);
    await _pumpPage(
      tester,
      incidentRepository: incidentRepository,
      routeRepository: _FakeRouteCatalogRepository.results([
        () async => _snapshot(),
      ]),
    );
    await tester.enterText(
      find.byKey(const ValueKey('incident-route-id-field')),
      '300',
    );
    await _tapLookup(tester);

    expect(await incidentRepository.getAll(), isEmpty);
    expect(
      find.byKey(const ValueKey('submit-incident-report-button')),
      findsOneWidget,
    );
  });

  testWidgets('edit lookup changes fields but waits for explicit save', (
    tester,
  ) async {
    final incidentRepository = InMemoryIncidentRepository(
      seedData: [IncidentDemoData.busB1023()],
      clock: _clock,
    );
    final existing = (await incidentRepository.getById('INC-20260828-001'))!;
    await _pumpPage(
      tester,
      incidentRepository: incidentRepository,
      existingIncident: existing,
      routeRepository: _FakeRouteCatalogRepository.results([
        () async => _snapshot(),
      ]),
    );
    await tester.enterText(
      find.byKey(const ValueKey('incident-route-id-field')),
      '302',
    );
    await _tapLookup(tester);

    expect(_fieldText(tester, 'incident-route-id-field'), '302');
    expect(
      _fieldText(tester, 'incident-route-name-field'),
      'Titiwangsa ~ KLCC',
    );
    expect(
      (await incidentRepository.getById(existing.incidentId))?.routeId,
      '300',
    );
    expect(
      find.byKey(const ValueKey('submit-incident-edit-button')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required RouteCatalogRepository routeRepository,
  InMemoryIncidentRepository? incidentRepository,
  Incident? existingIncident,
}) async {
  final controller = IncidentController(
    repository: incidentRepository ?? InMemoryIncidentRepository(clock: _clock),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: IncidentReportPage(
        controller: controller,
        reportedBy: 'staff-001',
        routeCatalogRepository: routeRepository,
        existingIncident: existingIncident,
        clock: _clock,
        incidentIdGenerator: (_) => 'INC-ROUTE-LOOKUP',
      ),
    ),
  );
  await tester.pump();
}

Future<void> _tapLookup(WidgetTester tester, {bool settle = true}) async {
  final finder = find.byKey(const ValueKey('incident-route-lookup-button'));
  tester.binding.focusManager.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(
    tester.element(finder),
    alignment: 0.5,
    duration: Duration.zero,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

String _fieldText(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(ValueKey(key))).controller!.text;

DateTime _clock() => DateTime(2026, 9, 1, 9);

class _FakeRouteCatalogRepository implements RouteCatalogRepository {
  _FakeRouteCatalogRepository.results(this._results);

  final List<Future<RouteCatalogSnapshot> Function()> _results;
  int loadCount = 0;

  @override
  Future<RouteCatalogSnapshot> loadCatalog() {
    final index = loadCount++;
    return _results[index]();
  }
}

RouteCatalogSnapshot _snapshot() => RouteCatalogSnapshot(
  metadata: RouteCatalogSourceMetadata(
    sourceUrl:
        'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-kl',
    feedName: 'Prasarana Rapid Bus KL',
    attribution: 'Government of Malaysia data.gov.my; Rapid KL',
    retrievedAtUtc: DateTime.utc(2026, 8, 27),
    providerLastModifiedUtc: DateTime.utc(2026, 8, 27),
    providerEtag: 'etag',
    sourceArchiveSha256:
        '977b748d479616ef683afcc8c9857ec01374b6d7f0ff3b371ed16868327ed4f1',
    dataClassification: RouteCatalogDataClassification.cachedGovernmentStatic,
    agencyId: 'rapidkl',
    agencyName: 'Rapid KL',
    agencyUrl: 'http://www.myrapid.com.my',
    agencyTimezone: 'Asia/Kuala_Lumpur',
  ),
  routes: [
    RouteCatalogEntry(
      gtfsRouteId: 'U3000',
      agencyId: 'rapidkl',
      routeShortName: '300',
      routeLongName: 'Terminal Maluri ~ Lebuh Ampang',
      routeType: 3,
    ),
    RouteCatalogEntry(
      gtfsRouteId: 'U3020',
      agencyId: 'rapidkl',
      routeShortName: '302',
      routeLongName: 'Titiwangsa ~ KLCC',
      routeType: 3,
    ),
    RouteCatalogEntry(
      gtfsRouteId: 'S0040',
      agencyId: 'rapidkl',
      routeShortName: 'AJ01',
      routeLongName: 'Ukay Perdana ~ Taman Melawati via Sg. Sering',
      routeType: 3,
    ),
  ],
);
