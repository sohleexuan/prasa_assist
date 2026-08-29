import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/incidents/controllers/incident_controller.dart';
import 'package:prasa_assist/features/incidents/data/incident_demo_data.dart';
import 'package:prasa_assist/features/incidents/models/incident.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';
import 'package:prasa_assist/features/incidents/pages/incident_edit_page.dart';
import 'package:prasa_assist/features/incidents/pages/incident_report_page.dart';
import 'package:prasa_assist/features/incidents/repositories/in_memory_incident_repository.dart';

void main() {
  testWidgets('prefills every editable value and preserves identity labels', (
    tester,
  ) async {
    final setup = await _setup();
    addTearDown(setup.controller.dispose);
    await _pumpEdit(tester, setup: setup);

    expect(find.byType(IncidentEditPage), findsOneWidget);
    expect(find.byType(IncidentReportPage), findsOneWidget);
    expect(find.text('Edit Incident'), findsOneWidget);
    expect(find.text('Current status'), findsOneWidget);
    expect(find.text('Reported'), findsOneWidget);
    expect(find.text('Mock / Demonstration Data'), findsWidgets);
    expect(find.text('Reporter: Demo Operations Staff'), findsOneWidget);
    expect(_fieldText(tester, 'incident-id-field'), 'INC-20260828-001');
    expect(_fieldText(tester, 'incident-title-field'), 'Bus B1023 breakdown');
    expect(_fieldText(tester, 'incident-route-id-field'), '300');
    expect(_fieldText(tester, 'incident-route-name-field'), 'Route 300');
    expect(_fieldText(tester, 'incident-vehicle-id-field'), 'B1023');
    expect(
      find.byKey(const ValueKey('submit-incident-edit-button')),
      findsOneWidget,
    );
  });

  testWidgets('updates fields and estimate while preserving audit ownership', (
    tester,
  ) async {
    final setup = await _setup(status: IncidentStatus.underReview);
    final original = setup.incident;
    Incident? saved;
    addTearDown(setup.controller.dispose);
    await _pumpEdit(tester, setup: setup, onSaved: (value) => saved = value);

    await tester.enterText(
      find.byKey(const ValueKey('incident-title-field')),
      'Updated Bus B1023 breakdown',
    );
    await tester.enterText(
      find.byKey(const ValueKey('incident-location-field')),
      'Updated staff-observed location',
    );
    await _selectDropdown(tester, 'incident-severity-field', 'Critical');
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('submit-incident-edit-button')),
    );
    await tester.pump();
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.title, 'Updated Bus B1023 breakdown');
    expect(saved!.location, 'Updated staff-observed location');
    expect(saved!.severity, IncidentSeverity.critical);
    expect(saved!.estimatedDelayMinutes, 94);
    expect(saved!.incidentId, original.incidentId);
    expect(saved!.reportedBy, original.reportedBy);
    expect(saved!.createdAt, original.createdAt);
    expect(saved!.dataSource, original.dataSource);
    expect(saved!.status, IncidentStatus.underReview);
    expect(saved!.statusHistory, original.statusHistory);
    expect(saved!.updatedAt, _clock());
  });

  testWidgets('validation prevents an invalid update', (tester) async {
    final setup = await _setup();
    var saveCount = 0;
    addTearDown(setup.controller.dispose);
    await _pumpEdit(tester, setup: setup, onSaved: (_) => saveCount++);
    await tester.enterText(
      find.byKey(const ValueKey('incident-title-field')),
      'x',
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('submit-incident-edit-button')),
    );
    await tester.pump();

    expect(
      find.text('Title must be between 3 and 100 characters.'),
      findsOneWidget,
    );
    expect(saveCount, 0);
    expect(
      (await setup.repository.getById(setup.incident.incidentId))?.title,
      setup.incident.title,
    );
  });

  testWidgets('requires current staff identity before saving changes', (
    tester,
  ) async {
    final setup = await _setup();
    addTearDown(setup.controller.dispose);
    await _pumpEdit(tester, setup: setup, currentStaffId: '   ');

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('submit-incident-edit-button')),
    );
    await tester.pump();

    expect(find.text('Unable to save incident'), findsOneWidget);
    expect(find.textContaining('staff identity is required'), findsOneWidget);
  });

  testWidgets('shows a safe failure when the record no longer exists', (
    tester,
  ) async {
    final repository = InMemoryIncidentRepository(clock: _clock);
    final controller = IncidentController(repository: repository);
    final setup = (
      repository: repository,
      controller: controller,
      incident: IncidentDemoData.busB1023(),
    );
    var saveCount = 0;
    addTearDown(controller.dispose);
    await _pumpEdit(tester, setup: setup, onSaved: (_) => saveCount++);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('submit-incident-edit-button')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Unable to save incident'), findsOneWidget);
    expect(find.textContaining('does not exist'), findsOneWidget);
    expect(saveCount, 0);
  });

  testWidgets('terminal incidents are read-only', (tester) async {
    final setup = await _setup(status: IncidentStatus.resolved);
    var cancelCount = 0;
    addTearDown(setup.controller.dispose);
    await _pumpEdit(tester, setup: setup, onCancel: () => cancelCount++);

    expect(find.text('Resolved Incident'), findsOneWidget);
    expect(find.textContaining('read-only'), findsWidgets);
    expect(
      find.byKey(const ValueKey('submit-incident-edit-button')),
      findsNothing,
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('incident-title-field')),
              matching: find.byType(EditableText),
            ),
          )
          .readOnly,
      isTrue,
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('cancel-incident-report-button')),
    );
    expect(cancelCount, 1);
  });

  testWidgets('Cancel returns without updating the repository', (tester) async {
    final setup = await _setup();
    var cancelCount = 0;
    addTearDown(setup.controller.dispose);
    await _pumpEdit(tester, setup: setup, onCancel: () => cancelCount++);
    await tester.enterText(
      find.byKey(const ValueKey('incident-title-field')),
      'Unsaved title',
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('cancel-incident-report-button')),
    );

    expect(cancelCount, 1);
    expect(
      (await setup.repository.getById(setup.incident.incidentId))?.title,
      setup.incident.title,
    );
  });

  testWidgets('remains overflow-free at 320px width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final setup = await _setup();
    addTearDown(setup.controller.dispose);

    await _pumpEdit(tester, setup: setup);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1400),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<
  ({
    InMemoryIncidentRepository repository,
    IncidentController controller,
    Incident incident,
  })
>
_setup({IncidentStatus status = IncidentStatus.reported}) async {
  final repository = InMemoryIncidentRepository(
    seedData: [IncidentDemoData.busB1023()],
    clock: _clock,
  );
  if (status != IncidentStatus.reported) {
    await repository.transitionStatus(
      'INC-20260828-001',
      IncidentStatus.underReview,
      changedBy: 'supervisor-001',
    );
  }
  if (status == IncidentStatus.active || status == IncidentStatus.resolved) {
    await repository.transitionStatus(
      'INC-20260828-001',
      IncidentStatus.active,
      changedBy: 'supervisor-001',
    );
  }
  if (status == IncidentStatus.resolved) {
    await repository.transitionStatus(
      'INC-20260828-001',
      IncidentStatus.resolved,
      changedBy: 'supervisor-001',
    );
  }
  final incident = (await repository.getById('INC-20260828-001'))!;
  return (
    repository: repository,
    controller: IncidentController(repository: repository),
    incident: incident,
  );
}

Future<void> _pumpEdit(
  WidgetTester tester, {
  required ({
    InMemoryIncidentRepository repository,
    IncidentController controller,
    Incident incident,
  })
  setup,
  String currentStaffId = 'editor-001',
  ValueChanged<Incident>? onSaved,
  VoidCallback? onCancel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: IncidentEditPage(
        controller: setup.controller,
        incident: setup.incident,
        currentStaffId: currentStaffId,
        clock: _clock,
        onSaved: onSaved,
        onCancel: onCancel,
      ),
    ),
  );
  await tester.pump();
}

String _fieldText(WidgetTester tester, String key) {
  return tester
      .widget<TextFormField>(find.byKey(ValueKey(key)))
      .controller!
      .text;
}

Future<void> _selectDropdown(
  WidgetTester tester,
  String key,
  String option,
) async {
  await _tapVisible(tester, find.byKey(ValueKey(key)));
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

DateTime _clock() => DateTime(2026, 8, 28, 12);
