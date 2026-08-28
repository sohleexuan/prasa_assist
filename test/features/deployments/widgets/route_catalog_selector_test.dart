import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/controllers/route_catalog_controller.dart';
import 'package:prasa_assist/features/deployments/data/snapshots/rapid_bus_kl_route_snapshot.dart';
import 'package:prasa_assist/features/deployments/models/route_catalog.dart';
import 'package:prasa_assist/features/deployments/repositories/bundled_route_catalog_repository.dart';
import 'package:prasa_assist/features/deployments/repositories/route_catalog_repository.dart';
import 'package:prasa_assist/features/deployments/widgets/route_catalog_selector.dart';

void main() {
  testWidgets('shows a compact loading state', (tester) async {
    final repository = _PendingRouteCatalogRepository();
    final controller = RouteCatalogController(repository);
    unawaited(controller.loadCatalog());

    await _pumpSelector(tester, controller: controller);

    expect(find.byKey(const ValueKey('route-catalog-loading')), findsOneWidget);
    expect(find.text('Loading cached route guidance...'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    repository.complete(rapidBusKlRouteSnapshot);
    await tester.pump();
    controller.dispose();
  });

  testWidgets('shows cached-data provenance and requires explicit selection', (
    tester,
  ) async {
    final controller = await _loadedController();
    addTearDown(controller.dispose);
    var selectionCount = 0;

    await _pumpSelector(
      tester,
      controller: controller,
      onSelected: (_) => selectionCount++,
    );

    expect(find.text('Cached government static data'), findsOneWidget);
    expect(find.text('Government of Malaysia data.gov.my'), findsOneWidget);
    expect(find.text('Prasarana / Rapid KL'), findsOneWidget);
    expect(find.text('Retrieved 27 Aug 2026, 22:32 UTC'), findsOneWidget);
    expect(find.textContaining('2026-08-27T22:32:48.624Z'), findsNothing);
    expect(find.byKey(const ValueKey('route-catalog-results')), findsNothing);
    expect(selectionCount, 0);
  });

  for (final query in const [
    '300',
    'U3000',
    'Terminal Maluri ~ Lebuh Ampang',
  ]) {
    testWidgets('searches Route 300 using "$query"', (tester) async {
      final controller = await _loadedController();
      addTearDown(controller.dispose);
      await _pumpSelector(tester, controller: controller);

      await tester.enterText(
        find.byKey(const ValueKey('route-catalog-search-field')),
        query,
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('route-catalog-result-U3000')),
        findsOneWidget,
      );
      final result = find.byKey(const ValueKey('route-catalog-result-U3000'));
      expect(
        find.descendant(of: result, matching: find.text('300')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: result,
          matching: find.text('Terminal Maluri ~ Lebuh Ampang'),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('returns the exact explicitly selected Route 300', (
    tester,
  ) async {
    final controller = await _loadedController();
    addTearDown(controller.dispose);
    RouteCatalogEntry? selected;
    await _pumpSelector(
      tester,
      controller: controller,
      onSelected: (route) => selected = route,
    );
    await _searchFor300(tester);
    final searchField = find.byKey(
      const ValueKey('route-catalog-search-field'),
    );
    expect(tester.widget<TextField>(searchField).controller!.text, '300');
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: searchField,
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('route-catalog-result-U3000')));
    await tester.pump();

    expect(selected, same(rapidBusKlRouteSnapshot.routeByShortName('300')));
    expect(selected!.gtfsRouteId, 'U3000');
    expect(selected!.routeShortName, '300');
    expect(tester.widget<TextField>(searchField).controller!.text, isEmpty);
    expect(find.byKey(const ValueKey('route-catalog-results')), findsNothing);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: searchField,
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isFalse,
    );

    await tester.enterText(searchField, 'U3000');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('route-catalog-result-U3000')),
      findsOneWidget,
    );
  });

  testWidgets('shows only verified advisory static schedule context', (
    tester,
  ) async {
    final controller = await _loadedController();
    addTearDown(controller.dispose);
    await _pumpSelector(tester, controller: controller);
    await _searchFor300(tester);

    expect(
      find.text('Static schedule (advisory): Daily, 05:00\u201323:45'),
      findsOneWidget,
    );
  });

  testWidgets('unavailable state explains that manual work can continue', (
    tester,
  ) async {
    final controller = RouteCatalogController(
      _UnavailableRouteCatalogRepository(),
    );
    await controller.loadCatalog();
    addTearDown(controller.dispose);

    await _pumpSelector(tester, controller: controller);

    expect(
      find.byKey(const ValueKey('route-catalog-unavailable')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Manual or prefilled route entry remains available'),
      findsOneWidget,
    );
    expect(
      find.textContaining('deployment saving can continue'),
      findsOneWidget,
    );
  });

  testWidgets('does not make unsupported operational-data claims', (
    tester,
  ) async {
    final controller = await _loadedController();
    addTearDown(controller.dispose);
    await _pumpSelector(tester, controller: controller);
    await _searchFor300(tester);

    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .join(' ')
        .toLowerCase();
    for (final unsupported in const [
      'live',
      'realtime',
      'currently running',
      'available vehicle',
      'passenger demand',
      'occupancy',
      'trip update',
      'service alert',
    ]) {
      expect(visibleText, isNot(contains(unsupported)));
    }
  });

  testWidgets('fits a narrow screen without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _loadedController();
    addTearDown(controller.dispose);

    await _pumpSelector(tester, controller: controller);
    await _searchFor300(tester);

    expect(tester.takeException(), isNull);
  });
}

Future<RouteCatalogController> _loadedController() async {
  final controller = RouteCatalogController(
    const BundledRouteCatalogRepository(),
  );
  await controller.loadCatalog();
  return controller;
}

Future<void> _pumpSelector(
  WidgetTester tester, {
  required RouteCatalogController controller,
  ValueChanged<RouteCatalogEntry>? onSelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: RouteCatalogSelector(
            controller: controller,
            onRouteSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _searchFor300(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('route-catalog-search-field')),
    '300',
  );
  await tester.pump();
}

class _PendingRouteCatalogRepository implements RouteCatalogRepository {
  final Completer<RouteCatalogSnapshot> _completer =
      Completer<RouteCatalogSnapshot>();

  @override
  Future<RouteCatalogSnapshot> loadCatalog() => _completer.future;

  void complete(RouteCatalogSnapshot snapshot) => _completer.complete(snapshot);
}

class _UnavailableRouteCatalogRepository implements RouteCatalogRepository {
  @override
  Future<RouteCatalogSnapshot> loadCatalog() {
    throw StateError('Route catalogue unavailable for test');
  }
}
