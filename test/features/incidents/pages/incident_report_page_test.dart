import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/incidents/controllers/incident_controller.dart';
import 'package:prasa_assist/features/incidents/data/incident_demo_data.dart';
import 'package:prasa_assist/features/incidents/models/incident.dart';
import 'package:prasa_assist/features/incidents/pages/incident_report_page.dart';
import 'package:prasa_assist/features/incidents/repositories/in_memory_incident_repository.dart';

void main() {
  testWidgets('renders an ordinary staff-controlled report form', (
    tester,
  ) async {
    await _pumpPage(tester);

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(IncidentReportPage), findsOneWidget);
    expect(find.text('Report Incident'), findsOneWidget);
    expect(find.text('Staff-entered Data'), findsOneWidget);
    expect(
      find.textContaining('not an official Prasarana model'),
      findsOneWidget,
    );
    expect(find.textContaining('Staff must review'), findsOneWidget);
    expect(find.text('31 minutes'), findsOneWidget);
    expect(find.text('Major'), findsOneWidget);
    expect(find.text('2026-08-28 MYT'), findsOneWidget);
    expect(find.text('08:00 MYT'), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('incident-id-field')),
              matching: find.byType(EditableText),
            ),
          )
          .readOnly,
      isTrue,
    );
  });

  testWidgets('updates the preview when operational inputs change', (
    tester,
  ) async {
    await _pumpPage(tester);

    await _selectDropdown(tester, 'incident-severity-field', 'High');
    await _selectDropdown(
      tester,
      'incident-vehicle-condition-field',
      'Immobilised',
    );
    await _selectDropdown(
      tester,
      'incident-disruption-scope-field',
      'Partial Obstruction',
    );

    expect(find.text('75 minutes'), findsOneWidget);
    expect(find.text('Severe'), findsOneWidget);
    expect(find.textContaining('peak-hour factor'), findsOneWidget);
  });

  testWidgets('shows field validation and requires a vehicle when applicable', (
    tester,
  ) async {
    await _pumpPage(tester);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('submit-incident-report-button')),
    );
    await tester.pump();

    expect(
      find.text('Title must be between 3 and 100 characters.'),
      findsOneWidget,
    );
    expect(
      find.text('Description must contain at least 10 characters.'),
      findsOneWidget,
    );
    expect(find.text('Route ID is required.'), findsOneWidget);
    expect(
      find.text('Vehicle ID is required for this incident type.'),
      findsOneWidget,
    );
    expect(find.text('Location is required.'), findsOneWidget);
  });

  testWidgets('creates and returns the shared Bus B1023 report', (
    tester,
  ) async {
    final repository = InMemoryIncidentRepository(clock: _clock);
    final controller = IncidentController(repository: repository);
    Incident? saved;
    addTearDown(controller.dispose);
    await _pumpPage(
      tester,
      controller: controller,
      onSaved: (value) => saved = value,
    );
    await _fillRequiredReport(tester);

    await _selectDropdown(tester, 'incident-severity-field', 'High');
    await _selectDropdown(
      tester,
      'incident-vehicle-condition-field',
      'Immobilised',
    );
    await _selectDropdown(
      tester,
      'incident-disruption-scope-field',
      'Partial Obstruction',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('submit-incident-report-button')),
    );
    await tester.pump();
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.incidentId, 'INC-TEST-001');
    expect(saved!.routeId, '300');
    expect(saved!.vehicleId, 'B1023');
    expect(saved!.estimatedDelayMinutes, 75);
    expect(saved!.reportedBy, 'staff-001');
    expect(saved!.reportedAt, DateTime.utc(2026, 8, 28));
    expect(saved!.reportedAt.isUtc, isTrue);
    expect(saved!.statusHistory, hasLength(1));
    expect(await repository.getById('INC-TEST-001'), saved);
  });

  testWidgets('bare email reporter is replaced by the unavailable label', (
    tester,
  ) async {
    final repository = InMemoryIncidentRepository(clock: _clock);
    final controller = IncidentController(repository: repository);
    Incident? saved;
    addTearDown(controller.dispose);
    await _pumpPage(
      tester,
      controller: controller,
      reportedBy: 'legacy.reporter@example.test',
      onSaved: (value) => saved = value,
    );

    expect(find.textContaining('legacy.reporter@example.test'), findsNothing);
    expect(find.textContaining('Staff profile unavailable'), findsOneWidget);

    await _fillRequiredReport(tester);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('submit-incident-report-button')),
    );
    await tester.pump();
    await tester.pump();

    expect(saved?.reportedBy, 'Staff profile unavailable');
  });

  testWidgets('allows an optional vehicle for a non-vehicle incident', (
    tester,
  ) async {
    final repository = InMemoryIncidentRepository(clock: _clock);
    final controller = IncidentController(repository: repository);
    Incident? saved;
    addTearDown(controller.dispose);
    await _pumpPage(
      tester,
      controller: controller,
      onSaved: (value) => saved = value,
    );
    await _fillRequiredReport(tester, includeVehicle: false);
    await _selectDropdown(tester, 'incident-type-field', 'Service Disruption');

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('submit-incident-report-button')),
    );
    await tester.pump();
    await tester.pump();

    expect(saved?.vehicleId, isNull);
  });

  testWidgets('does not save without an authenticated staff identity', (
    tester,
  ) async {
    final repository = InMemoryIncidentRepository(clock: _clock);
    final controller = IncidentController(repository: repository);
    addTearDown(controller.dispose);
    await _pumpPage(tester, controller: controller, reportedBy: '   ');
    await _fillRequiredReport(tester);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('submit-incident-report-button')),
    );
    await tester.pump();

    expect(find.text('Unable to save incident'), findsOneWidget);
    expect(find.textContaining('staff identity is required'), findsOneWidget);
    expect(await repository.getAll(), isEmpty);
  });

  testWidgets('shows a repository error and does not invoke onSaved', (
    tester,
  ) async {
    final repository = InMemoryIncidentRepository(
      seedData: [IncidentDemoData.busB1023()],
      clock: _clock,
    );
    final controller = IncidentController(repository: repository);
    var saveCount = 0;
    addTearDown(controller.dispose);
    await _pumpPage(
      tester,
      controller: controller,
      generatedId: 'INC-20260828-001',
      onSaved: (_) => saveCount++,
    );
    await _fillRequiredReport(tester);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('submit-incident-report-button')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Unable to save incident'), findsOneWidget);
    expect(find.textContaining('already exists'), findsOneWidget);
    expect(saveCount, 0);
  });

  testWidgets('invokes Cancel without saving', (tester) async {
    var cancelCount = 0;
    await _pumpPage(tester, onCancel: () => cancelCount++);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('cancel-incident-report-button')),
    );

    expect(cancelCount, 1);
  });

  testWidgets('remains overflow-free at 320px width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpPage(tester);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1400),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  IncidentController? controller,
  String reportedBy = 'staff-001',
  String generatedId = 'INC-TEST-001',
  ValueChanged<Incident>? onSaved,
  VoidCallback? onCancel,
}) async {
  final effectiveController =
      controller ??
      IncidentController(repository: InMemoryIncidentRepository(clock: _clock));
  if (controller == null) {
    addTearDown(effectiveController.dispose);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: IncidentReportPage(
        controller: effectiveController,
        reportedBy: reportedBy,
        clock: _clock,
        incidentIdGenerator: (_) => generatedId,
        onSaved: onSaved,
        onCancel: onCancel,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _fillRequiredReport(
  WidgetTester tester, {
  bool includeVehicle = true,
}) async {
  await tester.enterText(
    find.byKey(const ValueKey('incident-title-field')),
    'Bus B1023 breakdown',
  );
  await tester.enterText(
    find.byKey(const ValueKey('incident-description-field')),
    'Bus cannot continue operating on Route 300.',
  );
  await tester.enterText(
    find.byKey(const ValueKey('incident-route-id-field')),
    ' 300 ',
  );
  await tester.enterText(
    find.byKey(const ValueKey('incident-route-name-field')),
    ' Route 300 ',
  );
  if (includeVehicle) {
    await tester.enterText(
      find.byKey(const ValueKey('incident-vehicle-id-field')),
      ' B1023 ',
    );
  }
  await tester.enterText(
    find.byKey(const ValueKey('incident-location-field')),
    ' Jalan Ampang ',
  );
}

Future<void> _selectDropdown(
  WidgetTester tester,
  String key,
  String option,
) async {
  final finder = find.byKey(ValueKey(key));
  await _tapVisible(tester, finder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  tester.binding.focusManager.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(
    tester.element(finder),
    alignment: 0.35,
    duration: Duration.zero,
  );
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

DateTime _clock() => DateTime.utc(2026, 8, 28);
