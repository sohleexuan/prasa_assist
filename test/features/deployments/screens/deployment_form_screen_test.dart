import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/controllers/deployment_controller.dart';
import 'package:prasa_assist/features/deployments/models/deployment_prefill.dart';
import 'package:prasa_assist/features/deployments/models/deployment_status.dart';
import 'package:prasa_assist/features/deployments/models/service_deployment.dart';
import 'package:prasa_assist/features/deployments/repositories/in_memory_deployment_repository.dart';
import 'package:prasa_assist/features/deployments/screens/deployment_form_screen.dart';

void main() {
  group('Create mode', () {
    testWidgets('shows a generated read-only deployment ID', (tester) async {
      await _pumpForm(tester);

      expect(find.text('New Deployment'), findsOneWidget);
      expect(_fieldText(tester, 'deployment-id-field'), 'DEP-TEST-001');
      expect(_fieldIsReadOnly(tester, 'deployment-id-field'), isTrue);
    });

    testWidgets('uses sensible defaults from the injected clock', (
      tester,
    ) async {
      await _pumpForm(tester);

      expect(find.text('2026-08-27'), findsNWidgets(2));
      expect(find.text('08:30'), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);
    });

    testWidgets('opens Flutter built-in date and time pickers', (tester) async {
      await _pumpForm(tester);

      await _tapVisible(tester, const ValueKey('start-date-button'));
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pump();

      await _tapVisible(tester, const ValueKey('start-time-button'));
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pump();
    });

    testWidgets('shows required-field validation messages', (tester) async {
      await _pumpForm(tester);

      await _submit(tester, 'save-draft-button');

      expect(find.text('Route ID is required.'), findsOneWidget);
      expect(find.text('Route name is required.'), findsOneWidget);
      expect(
        find.text('At least one vehicle must be selected.'),
        findsOneWidget,
      );
      expect(find.text('Purpose is required.'), findsOneWidget);
    });

    testWidgets('rejects case-insensitive duplicate vehicle IDs', (
      tester,
    ) async {
      await _pumpForm(tester);
      await _fillRequiredFields(tester, vehicleIds: 'ABC 1230, abc 1230');

      await _submit(tester, 'save-draft-button');

      expect(
        find.text('Vehicle IDs cannot contain duplicates.'),
        findsOneWidget,
      );
    });

    testWidgets('rejects empty vehicle tokens between commas', (tester) async {
      await _pumpForm(tester);
      await _fillRequiredFields(tester, vehicleIds: 'ABC 1230, , DEF 4567');

      await _submit(tester, 'save-draft-button');

      expect(find.text('Vehicle IDs cannot be empty.'), findsOneWidget);
    });

    testWidgets('validates that end time is after start time', (tester) async {
      final time = DateTime(2026, 8, 27, 8, 30);
      await _pumpForm(
        tester,
        prefill: DeploymentPrefill(
          suggestedStartTime: time,
          suggestedEndTime: time,
        ),
      );
      await _fillRequiredFields(tester);

      await _submit(tester, 'save-draft-button');

      expect(find.text('End time must be after start time.'), findsOneWidget);
    });

    testWidgets('parses, trims, and counts comma-separated vehicles', (
      tester,
    ) async {
      ServiceDeployment? savedDeployment;
      final harness = await _pumpForm(
        tester,
        onSaved: (deployment) => savedDeployment = deployment,
      );
      await _fillRequiredFields(tester, vehicleIds: '  ABC 1230 , DEF 4567  ');

      expect(find.text('2 vehicles selected'), findsOneWidget);
      await _submit(tester, 'save-draft-button');

      expect(savedDeployment!.vehicleIds, ['ABC 1230', 'DEF 4567']);
      expect(
        (await harness.repository.getById('DEP-TEST-001'))!.vehicleCount,
        2,
      );
    });

    testWidgets('converts blank optional links to null', (tester) async {
      ServiceDeployment? savedDeployment;
      await _pumpForm(
        tester,
        onSaved: (deployment) => savedDeployment = deployment,
      );
      await _fillRequiredFields(tester);
      await tester.enterText(
        find.byKey(const ValueKey('incident-id-field')),
        '   ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('recommendation-id-field')),
        ' ',
      );

      await _submit(tester, 'save-draft-button');

      expect(savedDeployment!.incidentId, isNull);
      expect(savedDeployment!.sourceRecommendationId, isNull);
    });

    testWidgets('Save Draft creates a Draft and calls onSaved', (tester) async {
      ServiceDeployment? savedDeployment;
      final harness = await _pumpForm(
        tester,
        onSaved: (deployment) => savedDeployment = deployment,
      );
      await _fillRequiredFields(tester);

      await _submit(tester, 'save-draft-button');

      final stored = await harness.repository.getById('DEP-TEST-001');
      expect(stored!.status, DeploymentStatus.draft);
      expect(stored.createdBy, 'staff-001');
      expect(stored.createdAt, _testNow);
      expect(savedDeployment, stored);
    });

    testWidgets('Schedule creates Draft then explicitly transitions it', (
      tester,
    ) async {
      final repository = _RecordingRepository();
      ServiceDeployment? savedDeployment;
      await _pumpForm(
        tester,
        repository: repository,
        onSaved: (deployment) => savedDeployment = deployment,
      );
      await _fillRequiredFields(tester);

      await _submit(tester, 'schedule-deployment-button');

      expect(repository.createdStatuses, [DeploymentStatus.draft]);
      expect(repository.updatedStatuses, [DeploymentStatus.scheduled]);
      expect(savedDeployment!.status, DeploymentStatus.scheduled);
      expect(
        (await repository.getById('DEP-TEST-001'))!.status,
        DeploymentStatus.scheduled,
      );
    });

    testWidgets('does not call onSaved when repository creation fails', (
      tester,
    ) async {
      ServiceDeployment? savedDeployment;
      await _pumpForm(
        tester,
        repository: _FailingCreateRepository(),
        onSaved: (deployment) => savedDeployment = deployment,
      );
      await _fillRequiredFields(tester);

      await _submit(tester, 'save-draft-button');

      expect(savedDeployment, isNull);
      expect(find.text('Test create failure'), findsOneWidget);
      expect(_fieldText(tester, 'route-id-field'), '300');
    });

    testWidgets('Cancel invokes the supplied callback', (tester) async {
      var cancelCount = 0;
      await _pumpForm(tester, onCancel: () => cancelCount++);

      await _tapVisible(tester, const ValueKey('cancel-deployment-button'));

      expect(cancelCount, 1);
    });

    testWidgets('prevents duplicate submission while saving', (tester) async {
      final repository = _DelayedCreateRepository();
      var savedCount = 0;
      await _pumpForm(
        tester,
        repository: repository,
        onSaved: (_) => savedCount++,
      );
      await _fillRequiredFields(tester);
      final button = find.byKey(const ValueKey('save-draft-button'));
      await tester.ensureVisible(button);

      await tester.tap(button);
      await tester.pump();
      await tester.tap(button, warnIfMissed: false);

      expect(repository.createCallCount, 1);
      expect(
        find.byKey(const ValueKey('deployment-form-progress')),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      repository.completeCreate();
      await tester.pump();
      await tester.pump();
      expect(savedCount, 1);
    });

    testWidgets('validates blank current user and generated ID', (
      tester,
    ) async {
      await _pumpForm(tester, currentUserId: ' ');
      await _fillRequiredFields(tester);
      await _submit(tester, 'save-draft-button');
      expect(find.text('Current user ID is required.'), findsOneWidget);

      await _pumpForm(tester, deploymentIdGenerator: () => '  ');
      await _fillRequiredFields(tester);
      await _submit(tester, 'save-draft-button');
      expect(find.text('Deployment ID is required.'), findsOneWidget);
    });
  });

  group('Prefill', () {
    testWidgets('prefills advisory data without creating fake vehicles', (
      tester,
    ) async {
      final repository = _RecordingRepository();
      await _pumpForm(
        tester,
        repository: repository,
        prefill: DeploymentPrefill(
          routeId: '300',
          routeName: 'Route 300',
          incidentId: 'INC-2026-0142',
          recommendationId: 'REC-0088',
          suggestedVehicleCount: 2,
          suggestedStartTime: DateTime(2026, 8, 27, 9),
          suggestedEndTime: DateTime(2026, 8, 27, 11),
          suggestedPurpose: 'Deploy replacement buses after staff review',
        ),
      );

      expect(_fieldText(tester, 'route-id-field'), '300');
      expect(_fieldText(tester, 'route-name-field'), 'Route 300');
      expect(_fieldText(tester, 'incident-id-field'), 'INC-2026-0142');
      expect(_fieldText(tester, 'recommendation-id-field'), 'REC-0088');
      expect(
        _fieldText(tester, 'purpose-field'),
        'Deploy replacement buses after staff review',
      );
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget);
      expect(
        find.text(
          'Recommendation suggests 2 vehicles. '
          'Staff must select the actual vehicles.',
        ),
        findsOneWidget,
      );
      expect(_fieldText(tester, 'vehicle-ids-field'), isEmpty);
      expect(find.text('0 vehicles selected'), findsOneWidget);
      expect(repository.createCallCount, 0);
      expect(repository.updateCallCount, 0);
      expect(find.text('Schedule Deployment'), findsOneWidget);
    });
  });

  group('Edit mode', () {
    testWidgets('populates every existing value', (tester) async {
      final existing = _existingDeployment();
      await _pumpForm(tester, existingDeployment: existing);

      expect(find.text('Edit Deployment'), findsOneWidget);
      expect(_fieldText(tester, 'deployment-id-field'), existing.deploymentId);
      expect(_fieldText(tester, 'route-id-field'), existing.routeId);
      expect(_fieldText(tester, 'route-name-field'), existing.routeName);
      expect(
        _fieldText(tester, 'vehicle-ids-field'),
        existing.vehicleIds.join(', '),
      );
      expect(_fieldText(tester, 'purpose-field'), existing.purpose);
      expect(_fieldText(tester, 'incident-id-field'), existing.incidentId);
      expect(
        _fieldText(tester, 'recommendation-id-field'),
        existing.sourceRecommendationId,
      );
      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('Draft edits preserve identity and audit creation fields', (
      tester,
    ) async {
      final existing = _existingDeployment();
      ServiceDeployment? savedDeployment;
      final harness = await _pumpForm(
        tester,
        existingDeployment: existing,
        onSaved: (deployment) => savedDeployment = deployment,
      );
      await tester.enterText(
        find.byKey(const ValueKey('route-name-field')),
        'Updated Route 300',
      );

      await _submit(tester, 'save-changes-button');

      final stored = await harness.repository.getById(existing.deploymentId);
      expect(stored!.deploymentId, existing.deploymentId);
      expect(stored.createdBy, existing.createdBy);
      expect(stored.createdAt, existing.createdAt);
      expect(stored.updatedAt, _testNow);
      expect(stored.routeName, 'Updated Route 300');
      expect(stored.status, DeploymentStatus.draft);
      expect(savedDeployment, stored);
    });

    testWidgets('Draft can be scheduled only through the explicit action', (
      tester,
    ) async {
      final existing = _existingDeployment();
      final repository = _RecordingRepository(seedData: [existing]);
      ServiceDeployment? savedDeployment;
      await _pumpForm(
        tester,
        existingDeployment: existing,
        repository: repository,
        onSaved: (deployment) => savedDeployment = deployment,
      );

      await _submit(tester, 'schedule-deployment-button');

      expect(repository.updatedStatuses, [
        DeploymentStatus.draft,
        DeploymentStatus.scheduled,
      ]);
      expect(savedDeployment!.status, DeploymentStatus.scheduled);
    });

    testWidgets('Scheduled edits do not change status', (tester) async {
      final existing = _existingDeployment(status: DeploymentStatus.scheduled);
      final repository = _RecordingRepository(seedData: [existing]);
      await _pumpForm(
        tester,
        existingDeployment: existing,
        repository: repository,
      );
      await tester.enterText(
        find.byKey(const ValueKey('purpose-field')),
        'Updated scheduled purpose',
      );

      await _submit(tester, 'save-changes-button');

      expect(
        find.byKey(const ValueKey('schedule-deployment-button')),
        findsNothing,
      );
      expect(repository.updatedStatuses, [DeploymentStatus.scheduled]);
      expect(
        (await repository.getById(existing.deploymentId))!.status,
        DeploymentStatus.scheduled,
      );
    });

    testWidgets('Active, Completed, and Cancelled records are read-only', (
      tester,
    ) async {
      for (final status in const [
        DeploymentStatus.active,
        DeploymentStatus.completed,
        DeploymentStatus.cancelled,
      ]) {
        final existing = _existingDeployment(status: status);
        final repository = _RecordingRepository(seedData: [existing]);
        await _pumpForm(
          tester,
          existingDeployment: existing,
          repository: repository,
        );

        expect(
          find.byKey(const ValueKey('read-only-deployment-message')),
          findsOneWidget,
          reason: '${status.displayLabel} should explain read-only mode',
        );
        expect(_fieldIsReadOnly(tester, 'route-id-field'), isTrue);
        expect(find.byKey(const ValueKey('save-changes-button')), findsNothing);
        expect(
          find.byKey(const ValueKey('schedule-deployment-button')),
          findsNothing,
        );
        expect(repository.updateCallCount, 0);
      }
    });

    testWidgets('invalid edits do not update the repository', (tester) async {
      final existing = _existingDeployment();
      final repository = _RecordingRepository(seedData: [existing]);
      await _pumpForm(
        tester,
        existingDeployment: existing,
        repository: repository,
      );
      await tester.enterText(find.byKey(const ValueKey('route-id-field')), ' ');

      await _submit(tester, 'save-changes-button');

      expect(find.text('Route ID is required.'), findsOneWidget);
      expect(repository.updateCallCount, 0);
      expect(
        (await repository.getById(existing.deploymentId))!.routeId,
        existing.routeId,
      );
    });

    testWidgets('does not dispose the externally supplied controller', (
      tester,
    ) async {
      final repository = InMemoryDeploymentRepository();
      final controller = DeploymentController(
        repository: repository,
        clock: () => _controllerNow,
      );
      await _pumpForm(tester, controller: controller);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      await controller.loadDeployments();
      expect(controller.errorMessage, isNull);
    });
  });

  testWidgets('long values fit a 320px-wide scrolling layout', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpForm(
      tester,
      existingDeployment: _existingDeployment(
        routeName: 'A very long prototype route name that needs to wrap safely',
        vehicleIds: const [
          'VEHICLE-WITH-A-LONG-IDENTIFIER-001',
          'VEHICLE-WITH-A-LONG-IDENTIFIER-002',
        ],
        purpose:
            'A long operational purpose that staff must be able to review and '
            'edit without introducing a RenderFlex overflow on narrow screens.',
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -900),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('occupancy'), findsNothing);
    expect(find.textContaining('current load'), findsNothing);
  });
}

final DateTime _testNow = DateTime(2026, 8, 27, 8, 30);
final DateTime _controllerNow = DateTime(2026, 8, 27, 8, 31);

class _FormHarness {
  const _FormHarness({required this.repository, required this.controller});

  final InMemoryDeploymentRepository repository;
  final DeploymentController controller;
}

Future<_FormHarness> _pumpForm(
  WidgetTester tester, {
  String currentUserId = 'staff-001',
  ServiceDeployment? existingDeployment,
  DeploymentPrefill? prefill,
  InMemoryDeploymentRepository? repository,
  DeploymentController? controller,
  ValueChanged<ServiceDeployment>? onSaved,
  VoidCallback? onCancel,
  String Function()? deploymentIdGenerator,
}) async {
  final effectiveRepository =
      repository ??
      InMemoryDeploymentRepository(
        seedData: existingDeployment == null ? [] : [existingDeployment],
      );
  final effectiveController =
      controller ??
      DeploymentController(
        repository: effectiveRepository,
        clock: () => _controllerNow,
      );

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: DeploymentFormScreen(
        key: UniqueKey(),
        controller: effectiveController,
        currentUserId: currentUserId,
        existingDeployment: existingDeployment,
        prefill: prefill,
        onSaved: onSaved,
        onCancel: onCancel,
        deploymentIdGenerator: deploymentIdGenerator ?? () => 'DEP-TEST-001',
        clock: () => _testNow,
      ),
    ),
  );
  await tester.pump();
  return _FormHarness(
    repository: effectiveRepository,
    controller: effectiveController,
  );
}

Future<void> _fillRequiredFields(
  WidgetTester tester, {
  String vehicleIds = 'ABC 1230, DEF 4567',
}) async {
  await tester.enterText(find.byKey(const ValueKey('route-id-field')), '300');
  await tester.enterText(
    find.byKey(const ValueKey('route-name-field')),
    'Route 300',
  );
  await tester.enterText(
    find.byKey(const ValueKey('vehicle-ids-field')),
    vehicleIds,
  );
  await tester.enterText(
    find.byKey(const ValueKey('purpose-field')),
    'Provide replacement service',
  );
  await tester.pump();
}

Future<void> _submit(WidgetTester tester, String buttonKey) async {
  await _tapVisible(tester, ValueKey(buttonKey));
  await tester.pump();
}

Future<void> _tapVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pump();
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

String _fieldText(WidgetTester tester, String fieldKey) {
  return tester
      .widget<TextFormField>(find.byKey(ValueKey(fieldKey)))
      .controller!
      .text;
}

bool _fieldIsReadOnly(WidgetTester tester, String fieldKey) {
  final editableText = find.descendant(
    of: find.byKey(ValueKey(fieldKey)),
    matching: find.byType(EditableText),
  );
  return tester.widget<EditableText>(editableText).readOnly;
}

class _RecordingRepository extends InMemoryDeploymentRepository {
  _RecordingRepository({super.seedData});

  final List<DeploymentStatus> createdStatuses = [];
  final List<DeploymentStatus> updatedStatuses = [];
  int createCallCount = 0;
  int updateCallCount = 0;

  @override
  Future<void> create(ServiceDeployment deployment) async {
    createCallCount++;
    createdStatuses.add(deployment.status);
    await super.create(deployment);
  }

  @override
  Future<void> update(ServiceDeployment deployment) async {
    updateCallCount++;
    updatedStatuses.add(deployment.status);
    await super.update(deployment);
  }
}

class _FailingCreateRepository extends InMemoryDeploymentRepository {
  @override
  Future<void> create(ServiceDeployment deployment) {
    throw StateError('Test create failure');
  }
}

class _DelayedCreateRepository extends InMemoryDeploymentRepository {
  final Completer<void> _createCompleter = Completer<void>();
  int createCallCount = 0;

  @override
  Future<void> create(ServiceDeployment deployment) async {
    createCallCount++;
    await _createCompleter.future;
    await super.create(deployment);
  }

  void completeCreate() {
    _createCompleter.complete();
  }
}

ServiceDeployment _existingDeployment({
  DeploymentStatus status = DeploymentStatus.draft,
  String routeName = 'Route 300',
  List<String> vehicleIds = const ['ABC 1230', 'DEF 4567'],
  String purpose = 'Replace unavailable Bus B1023 during peak hour',
}) {
  return ServiceDeployment(
    deploymentId: 'DEP-120',
    routeId: '300',
    routeName: routeName,
    vehicleIds: vehicleIds,
    startTime: DateTime(2026, 8, 27, 9),
    endTime: DateTime(2026, 8, 27, 11),
    status: status,
    purpose: purpose,
    createdBy: 'original-staff',
    createdAt: DateTime(2026, 8, 27, 7),
    updatedAt: DateTime(2026, 8, 27, 7, 30),
    incidentId: 'INC-2026-0142',
    sourceRecommendationId: 'REC-0088',
  );
}
