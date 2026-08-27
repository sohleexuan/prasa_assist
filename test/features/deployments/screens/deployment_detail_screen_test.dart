import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/deployments/controllers/deployment_controller.dart';
import 'package:prasa_assist/features/deployments/models/deployment_status.dart';
import 'package:prasa_assist/features/deployments/models/service_deployment.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_repository.dart';
import 'package:prasa_assist/features/deployments/repositories/in_memory_deployment_repository.dart';
import 'package:prasa_assist/features/deployments/screens/deployment_detail_screen.dart';
import 'package:prasa_assist/features/deployments/widgets/deployment_status_chip.dart';

void main() {
  testWidgets('shows a loading state while retrieving the deployment', (
    tester,
  ) async {
    final repository = _DelayedGetRepository();
    await _pumpDetail(tester, repository: repository, finishLoading: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.complete(_deployment());
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('DEP-DETAIL'), findsOneWidget);
  });

  testWidgets('loads the requested deployment exactly once', (tester) async {
    final repository = _CountingRepository(seedData: [_deployment()]);

    await _pumpDetail(tester, repository: repository);
    await tester.pump();

    expect(repository.getByIdCallCount, 1);
    expect(find.text('Deployment Details'), findsOneWidget);
    expect(find.byType(DeploymentStatusChip), findsOneWidget);
  });

  testWidgets('shows a clear not-found state for an unknown ID', (
    tester,
  ) async {
    await _pumpDetail(tester, deploymentId: 'DEP-MISSING');

    expect(find.text('Deployment not found'), findsOneWidget);
    expect(
      find.text('No deployment with ID DEP-MISSING could be found.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows a controller error when loading fails', (tester) async {
    await _pumpDetail(tester, repository: _AlwaysFailingGetRepository());

    expect(find.text('Unable to load deployment'), findsOneWidget);
    expect(find.text('Test repository failure'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Retry retrieves the same deployment again', (tester) async {
    final repository = _RetryGetRepository(seedData: [_deployment()]);
    await _pumpDetail(tester, repository: repository);
    expect(find.text('Unable to load deployment'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(repository.requestedIds, ['DEP-DETAIL', 'DEP-DETAIL']);
    expect(find.text('DEP-DETAIL'), findsOneWidget);
    expect(find.text('Unable to load deployment'), findsNothing);
  });

  testWidgets('displays every deployment field using fixed date formatting', (
    tester,
  ) async {
    await _pumpDetail(tester, deployments: [_deployment()]);

    expect(find.text('DEP-DETAIL'), findsOneWidget);
    expect(find.text('Scheduled'), findsWidgets);
    expect(find.text('Route Three Hundred'), findsOneWidget);
    expect(find.text('300'), findsOneWidget);
    expect(find.text('2 vehicles'), findsOneWidget);
    expect(find.text('BUS-1001'), findsOneWidget);
    expect(find.text('BUS-1002'), findsOneWidget);
    expect(find.text('2026-08-27 08:05'), findsOneWidget);
    expect(find.text('2026-08-27 10:35'), findsOneWidget);
    expect(find.text('Peak-hour replacement service'), findsOneWidget);
    expect(find.text('Operations Tester'), findsOneWidget);
    expect(find.text('2026-08-26 14:15'), findsOneWidget);
    expect(find.text('2026-08-27 07:45'), findsOneWidget);
  });

  testWidgets('shows optional Incident and Recommendation links when present', (
    tester,
  ) async {
    await _pumpDetail(tester, deployments: [_deployment()]);

    expect(
      find.byKey(const ValueKey('linked-records-section')),
      findsOneWidget,
    );
    expect(find.text('Incident ID'), findsOneWidget);
    expect(find.text('INC-2026-0142'), findsOneWidget);
    expect(find.text('Recommendation ID'), findsOneWidget);
    expect(find.text('REC-0088'), findsOneWidget);
  });

  testWidgets('omits the Linked records section when both links are null', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      deployments: [
        _deployment(incidentId: null, sourceRecommendationId: null),
      ],
    );

    expect(find.byKey(const ValueKey('linked-records-section')), findsNothing);
    expect(find.text('Linked records'), findsNothing);
    expect(find.text('Incident ID'), findsNothing);
    expect(find.text('Recommendation ID'), findsNothing);
  });

  testWidgets(
    'labels displayed data as prototype rather than live operations',
    (tester) async {
      await _pumpDetail(tester, deployments: [_deployment()]);

      expect(find.text('Prototype data — not live operations'), findsOneWidget);
      expect(
        find.textContaining(
          RegExp(
            r'occupancy|live load|vehicle availability',
            caseSensitive: false,
          ),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('Edit calls back with the latest displayed deployment', (
    tester,
  ) async {
    final repository = InMemoryDeploymentRepository(
      seedData: [_deployment(status: DeploymentStatus.draft)],
    );
    ServiceDeployment? edited;
    ServiceDeployment? changed;
    await _pumpDetail(
      tester,
      repository: repository,
      onEditDeployment: (deployment) => edited = deployment,
      onStatusChanged: (deployment) => changed = deployment,
    );

    await _openStatusDialog(tester, 'schedule-detail-button');
    await tester.tap(find.byKey(const ValueKey('confirm-status-scheduled')));
    await _finishOperation(tester);
    await _tapAction(tester, 'edit-deployment-button');

    expect(changed, isNotNull);
    expect(edited, changed);
    expect(edited!.status, DeploymentStatus.scheduled);
    expect(edited!.updatedAt, _operationTime);
  });

  testWidgets('Draft offers Edit, Schedule, Cancel and Delete', (tester) async {
    await _pumpDetail(
      tester,
      deployments: [_deployment(status: DeploymentStatus.draft)],
    );

    _expectAction('edit-deployment-button', findsOneWidget);
    _expectAction('schedule-detail-button', findsOneWidget);
    _expectAction('cancel-deployment-status-button', findsOneWidget);
    _expectAction('delete-deployment-button', findsOneWidget);
    _expectAction('start-deployment-button', findsNothing);
    _expectAction('complete-deployment-button', findsNothing);
  });

  testWidgets('Scheduled offers only Edit, Start and Cancel', (tester) async {
    await _pumpDetail(
      tester,
      deployments: [_deployment(status: DeploymentStatus.scheduled)],
    );

    _expectAction('edit-deployment-button', findsOneWidget);
    _expectAction('start-deployment-button', findsOneWidget);
    _expectAction('cancel-deployment-status-button', findsOneWidget);
    _expectAction('schedule-detail-button', findsNothing);
    _expectAction('complete-deployment-button', findsNothing);
    _expectAction('delete-deployment-button', findsNothing);
  });

  testWidgets('Active offers only Complete and Cancel', (tester) async {
    await _pumpDetail(
      tester,
      deployments: [_deployment(status: DeploymentStatus.active)],
    );

    _expectAction('complete-deployment-button', findsOneWidget);
    _expectAction('cancel-deployment-status-button', findsOneWidget);
    _expectAction('edit-deployment-button', findsNothing);
    _expectAction('schedule-detail-button', findsNothing);
    _expectAction('start-deployment-button', findsNothing);
    _expectAction('delete-deployment-button', findsNothing);
  });

  testWidgets('Completed offers no status change or deletion', (tester) async {
    await _pumpDetail(
      tester,
      deployments: [_deployment(status: DeploymentStatus.completed)],
    );

    _expectNoOperationalStatusActions();
    _expectAction('edit-deployment-button', findsNothing);
    _expectAction('delete-deployment-button', findsNothing);
    expect(
      find.byKey(const ValueKey('completed-workflow-message')),
      findsOneWidget,
    );
  });

  testWidgets('Cancelled offers only prototype record deletion', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      deployments: [_deployment(status: DeploymentStatus.cancelled)],
    );

    _expectNoOperationalStatusActions();
    _expectAction('edit-deployment-button', findsNothing);
    _expectAction('delete-deployment-button', findsOneWidget);
    expect(
      find.byKey(const ValueKey('cancelled-workflow-message')),
      findsOneWidget,
    );
  });

  testWidgets('Schedule requires staff confirmation and can be dismissed', (
    tester,
  ) async {
    final repository = InMemoryDeploymentRepository(
      seedData: [_deployment(status: DeploymentStatus.draft)],
    );
    await _pumpDetail(tester, repository: repository);

    await _openStatusDialog(tester, 'schedule-detail-button');

    expect(find.text('Schedule deployment?'), findsOneWidget);
    expect(
      find.textContaining('route, actual vehicles and service window'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Recommendation data does not automatically schedule',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('AI recommends. Staff decides.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('dismiss-status-dialog')));
    await tester.pump();

    expect(
      (await repository.getById('DEP-DETAIL'))!.status,
      DeploymentStatus.draft,
    );
  });

  testWidgets('Schedule performs Draft to Scheduled with the injected clock', (
    tester,
  ) async {
    final repository = InMemoryDeploymentRepository(
      seedData: [_deployment(status: DeploymentStatus.draft)],
    );
    ServiceDeployment? callbackValue;
    await _pumpDetail(
      tester,
      repository: repository,
      onStatusChanged: (deployment) => callbackValue = deployment,
    );

    await _openStatusDialog(tester, 'schedule-detail-button');
    await tester.tap(find.byKey(const ValueKey('confirm-status-scheduled')));
    await _finishOperation(tester);

    final stored = await repository.getById('DEP-DETAIL');
    expect(stored!.status, DeploymentStatus.scheduled);
    expect(stored.updatedAt, _operationTime);
    expect(callbackValue, stored);
    expect(find.text('Scheduled'), findsWidgets);
    _expectAction('start-deployment-button', findsOneWidget);
  });

  testWidgets('Start requires confirmation before Scheduled becomes Active', (
    tester,
  ) async {
    final repository = InMemoryDeploymentRepository(
      seedData: [_deployment(status: DeploymentStatus.scheduled)],
    );
    await _pumpDetail(tester, repository: repository);

    await _openStatusDialog(tester, 'start-deployment-button');
    expect(find.text('Start deployment?'), findsOneWidget);
    expect(find.textContaining('physically started'), findsOneWidget);
    expect(find.text('Keep Scheduled'), findsOneWidget);
    expect(
      (await repository.getById('DEP-DETAIL'))!.status,
      DeploymentStatus.scheduled,
    );

    await tester.tap(find.byKey(const ValueKey('confirm-status-active')));
    await _finishOperation(tester);

    expect(
      (await repository.getById('DEP-DETAIL'))!.status,
      DeploymentStatus.active,
    );
    _expectAction('complete-deployment-button', findsOneWidget);
  });

  testWidgets(
    'Complete requires confirmation before Active becomes Completed',
    (tester) async {
      final repository = InMemoryDeploymentRepository(
        seedData: [_deployment(status: DeploymentStatus.active)],
      );
      await _pumpDetail(tester, repository: repository);

      await _openStatusDialog(tester, 'complete-deployment-button');
      expect(find.text('Complete deployment?'), findsOneWidget);
      expect(find.textContaining('operation has finished'), findsOneWidget);
      expect(find.text('Keep Active'), findsOneWidget);
      expect(
        (await repository.getById('DEP-DETAIL'))!.status,
        DeploymentStatus.active,
      );

      await tester.tap(find.byKey(const ValueKey('confirm-status-completed')));
      await _finishOperation(tester);

      expect(
        (await repository.getById('DEP-DETAIL'))!.status,
        DeploymentStatus.completed,
      );
      _expectNoOperationalStatusActions();
    },
  );

  testWidgets('Cancel requires confirmation and dismissal preserves status', (
    tester,
  ) async {
    final repository = InMemoryDeploymentRepository(
      seedData: [_deployment(status: DeploymentStatus.active)],
    );
    await _pumpDetail(tester, repository: repository);

    await _openStatusDialog(tester, 'cancel-deployment-status-button');
    expect(find.text('Cancel deployment?'), findsOneWidget);
    expect(
      find.textContaining('stop further workflow progression'),
      findsOneWidget,
    );
    expect(find.text('Keep Current Status'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dismiss-status-dialog')));
    await tester.pump();

    expect(
      (await repository.getById('DEP-DETAIL'))!.status,
      DeploymentStatus.active,
    );
  });

  for (final initialStatus in [
    DeploymentStatus.draft,
    DeploymentStatus.scheduled,
    DeploymentStatus.active,
  ]) {
    testWidgets('can cancel a ${initialStatus.displayLabel} deployment', (
      tester,
    ) async {
      final repository = InMemoryDeploymentRepository(
        seedData: [_deployment(status: initialStatus)],
      );
      await _pumpDetail(tester, repository: repository);

      await _openStatusDialog(tester, 'cancel-deployment-status-button');
      await tester.tap(find.byKey(const ValueKey('confirm-status-cancelled')));
      await _finishOperation(tester);

      final stored = await repository.getById('DEP-DETAIL');
      expect(stored!.status, DeploymentStatus.cancelled);
      expect(stored.updatedAt, _operationTime);
      _expectAction('delete-deployment-button', findsOneWidget);
      _expectNoOperationalStatusActions();
    });
  }

  testWidgets('Delete requires destructive confirmation and can be dismissed', (
    tester,
  ) async {
    final repository = InMemoryDeploymentRepository(
      seedData: [_deployment(status: DeploymentStatus.draft)],
    );
    await _pumpDetail(tester, repository: repository);

    await _tapAction(tester, 'delete-deployment-button');

    expect(find.text('Delete prototype record?'), findsOneWidget);
    expect(find.textContaining('prototype deployment record'), findsOneWidget);
    expect(
      find.textContaining('does not affect live operations'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('dismiss-delete-dialog')));
    await tester.pump();

    expect(await repository.getById('DEP-DETAIL'), isNotNull);
  });

  for (final status in [DeploymentStatus.draft, DeploymentStatus.cancelled]) {
    testWidgets('deletes a ${status.displayLabel} prototype record', (
      tester,
    ) async {
      final repository = InMemoryDeploymentRepository(
        seedData: [_deployment(status: status)],
      );
      var deletedCount = 0;
      await _pumpDetail(
        tester,
        repository: repository,
        onDeleted: () => deletedCount++,
      );

      await _tapAction(tester, 'delete-deployment-button');
      await tester.tap(find.byKey(const ValueKey('confirm-delete-deployment')));
      await _finishOperation(tester);

      expect(await repository.getById('DEP-DETAIL'), isNull);
      expect(deletedCount, 1);
      expect(find.text('Deployment deleted'), findsOneWidget);
    });
  }

  testWidgets('failed status change preserves the screen and shows the error', (
    tester,
  ) async {
    final repository = _FailingUpdateRepository(
      seedData: [_deployment(status: DeploymentStatus.draft)],
    );
    var callbackCount = 0;
    await _pumpDetail(
      tester,
      repository: repository,
      onStatusChanged: (_) => callbackCount++,
    );

    await _openStatusDialog(tester, 'schedule-detail-button');
    await tester.tap(find.byKey(const ValueKey('confirm-status-scheduled')));
    await _finishOperation(tester);

    expect(find.text('Test status failure'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('deployment-operation-error')),
      findsOneWidget,
    );
    expect(callbackCount, 0);
    expect(
      (await repository.getById('DEP-DETAIL'))!.status,
      DeploymentStatus.draft,
    );
    _expectAction('schedule-detail-button', findsOneWidget);
  });

  testWidgets('failed deletion does not call onDeleted and shows the error', (
    tester,
  ) async {
    final repository = _FailingDeleteRepository(
      seedData: [_deployment(status: DeploymentStatus.draft)],
    );
    var deletedCount = 0;
    await _pumpDetail(
      tester,
      repository: repository,
      onDeleted: () => deletedCount++,
    );

    await _tapAction(tester, 'delete-deployment-button');
    await tester.tap(find.byKey(const ValueKey('confirm-delete-deployment')));
    await _finishOperation(tester);

    expect(find.text('Test deletion failure'), findsOneWidget);
    expect(deletedCount, 0);
    expect(await repository.getById('DEP-DETAIL'), isNotNull);
    _expectAction('delete-deployment-button', findsOneWidget);
  });

  testWidgets('disables operations and prevents duplicate status submissions', (
    tester,
  ) async {
    final repository = _DelayedUpdateRepository(
      seedData: [_deployment(status: DeploymentStatus.draft)],
    );
    await _pumpDetail(tester, repository: repository);

    await _openStatusDialog(tester, 'schedule-detail-button');
    await tester.tap(find.byKey(const ValueKey('confirm-status-scheduled')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('deployment-operation-progress')),
      findsOneWidget,
    );
    final scheduleButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('schedule-detail-button')),
    );
    final cancelButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('cancel-deployment-status-button')),
    );
    expect(scheduleButton.onPressed, isNull);
    expect(cancelButton.onPressed, isNull);
    expect(repository.updateCallCount, 1);

    repository.release();
    await _finishOperation(tester);

    expect(repository.updateCallCount, 1);
    expect(
      (await repository.getById('DEP-DETAIL'))!.status,
      DeploymentStatus.scheduled,
    );
  });

  testWidgets('prevents duplicate deletion submissions', (tester) async {
    final repository = _DelayedDeleteRepository(
      seedData: [_deployment(status: DeploymentStatus.draft)],
    );
    var deletedCount = 0;
    await _pumpDetail(
      tester,
      repository: repository,
      onDeleted: () => deletedCount++,
    );

    await _tapAction(tester, 'delete-deployment-button');
    await tester.tap(find.byKey(const ValueKey('confirm-delete-deployment')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('deployment-operation-progress')),
      findsOneWidget,
    );
    final deleteButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('delete-deployment-button')),
    );
    expect(deleteButton.onPressed, isNull);
    expect(repository.deleteCallCount, 1);

    repository.release();
    await _finishOperation(tester);

    expect(repository.deleteCallCount, 1);
    expect(deletedCount, 1);
    expect(await repository.getById('DEP-DETAIL'), isNull);
  });

  testWidgets('uses callbacks for Back rather than direct navigation', (
    tester,
  ) async {
    var backCount = 0;
    await _pumpDetail(
      tester,
      deployments: [_deployment()],
      onBack: () => backCount++,
    );

    await tester.tap(find.byKey(const ValueKey('back-from-deployment-button')));
    await tester.pump();

    expect(backCount, 1);
    expect(find.byType(DeploymentDetailScreen), findsOneWidget);
  });

  testWidgets('does not dispose its externally supplied controller', (
    tester,
  ) async {
    final repository = InMemoryDeploymentRepository(seedData: [_deployment()]);
    final controller = DeploymentController(repository: repository);
    await _pumpDetail(tester, controller: controller);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await controller.loadDeployments();

    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNull);
  });

  testWidgets('long values scroll without overflow at 320px width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final longValue = List.filled(10, 'long-operational-value').join('-');

    await _pumpDetail(
      tester,
      deployments: [
        _deployment(
          deploymentId: 'DEP-$longValue',
          routeName: 'Route $longValue',
          routeId: longValue,
          vehicleIds: ['BUS-$longValue', 'SECOND-$longValue'],
          purpose: 'Purpose $longValue',
          incidentId: 'INC-$longValue',
          sourceRecommendationId: 'REC-$longValue',
          createdBy: 'Staff $longValue',
        ),
      ],
      deploymentId: 'DEP-$longValue',
    );

    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1800),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Purpose $longValue'), findsOneWidget);
  });
}

const _notProvided = Object();
final _operationTime = DateTime(2026, 8, 27, 12, 34);

ServiceDeployment _deployment({
  String deploymentId = 'DEP-DETAIL',
  String routeId = '300',
  String routeName = 'Route Three Hundred',
  List<String> vehicleIds = const ['BUS-1001', 'BUS-1002'],
  DeploymentStatus status = DeploymentStatus.scheduled,
  String purpose = 'Peak-hour replacement service',
  String createdBy = 'Operations Tester',
  Object? incidentId = _notProvided,
  Object? sourceRecommendationId = _notProvided,
}) {
  return ServiceDeployment(
    deploymentId: deploymentId,
    routeId: routeId,
    routeName: routeName,
    vehicleIds: vehicleIds,
    startTime: DateTime(2026, 8, 27, 8, 5),
    endTime: DateTime(2026, 8, 27, 10, 35),
    status: status,
    purpose: purpose,
    createdBy: createdBy,
    createdAt: DateTime(2026, 8, 26, 14, 15),
    updatedAt: DateTime(2026, 8, 27, 7, 45),
    incidentId: identical(incidentId, _notProvided)
        ? 'INC-2026-0142'
        : incidentId as String?,
    sourceRecommendationId: identical(sourceRecommendationId, _notProvided)
        ? 'REC-0088'
        : sourceRecommendationId as String?,
  );
}

Future<DeploymentController> _pumpDetail(
  WidgetTester tester, {
  Iterable<ServiceDeployment> deployments = const [],
  DeploymentRepository? repository,
  DeploymentController? controller,
  String deploymentId = 'DEP-DETAIL',
  ValueChanged<ServiceDeployment>? onEditDeployment,
  ValueChanged<ServiceDeployment>? onStatusChanged,
  VoidCallback? onDeleted,
  VoidCallback? onBack,
  bool finishLoading = true,
}) async {
  final actualRepository =
      repository ?? InMemoryDeploymentRepository(seedData: deployments);
  final actualController =
      controller ?? DeploymentController(repository: actualRepository);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: DeploymentDetailScreen(
        controller: actualController,
        deploymentId: deploymentId,
        onEditDeployment: onEditDeployment,
        onStatusChanged: onStatusChanged,
        onDeleted: onDeleted,
        onBack: onBack,
        clock: () => _operationTime,
      ),
    ),
  );
  await tester.pump();
  if (finishLoading) {
    await tester.pump();
  }
  return actualController;
}

Future<void> _tapAction(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _openStatusDialog(WidgetTester tester, String actionKey) async {
  await _tapAction(tester, actionKey);
  expect(find.byType(AlertDialog), findsOneWidget);
}

Future<void> _finishOperation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void _expectAction(String key, Matcher matcher) {
  expect(find.byKey(ValueKey(key)), matcher);
}

void _expectNoOperationalStatusActions() {
  _expectAction('schedule-detail-button', findsNothing);
  _expectAction('start-deployment-button', findsNothing);
  _expectAction('complete-deployment-button', findsNothing);
  _expectAction('cancel-deployment-status-button', findsNothing);
}

class _DelayedGetRepository extends InMemoryDeploymentRepository {
  final Completer<ServiceDeployment?> _completer =
      Completer<ServiceDeployment?>();

  @override
  Future<ServiceDeployment?> getById(String deploymentId) => _completer.future;

  void complete(ServiceDeployment deployment) =>
      _completer.complete(deployment);
}

class _CountingRepository extends InMemoryDeploymentRepository {
  _CountingRepository({required super.seedData});

  int getByIdCallCount = 0;

  @override
  Future<ServiceDeployment?> getById(String deploymentId) {
    getByIdCallCount++;
    return super.getById(deploymentId);
  }
}

class _AlwaysFailingGetRepository extends InMemoryDeploymentRepository {
  @override
  Future<ServiceDeployment?> getById(String deploymentId) {
    throw StateError('Test repository failure');
  }
}

class _RetryGetRepository extends InMemoryDeploymentRepository {
  _RetryGetRepository({required super.seedData});

  final List<String> requestedIds = [];

  @override
  Future<ServiceDeployment?> getById(String deploymentId) {
    requestedIds.add(deploymentId);
    if (requestedIds.length == 1) {
      throw StateError('Test repository failure');
    }
    return super.getById(deploymentId);
  }
}

class _FailingUpdateRepository extends InMemoryDeploymentRepository {
  _FailingUpdateRepository({required super.seedData});

  @override
  Future<ServiceDeployment> transitionStatus(
    String deploymentCode,
    DeploymentStatus targetStatus, {
    required String changedByLabel,
    DateTime? changedAt,
  }) {
    throw StateError('Test status failure');
  }
}

class _FailingDeleteRepository extends InMemoryDeploymentRepository {
  _FailingDeleteRepository({required super.seedData});

  @override
  Future<void> delete(String deploymentId) {
    throw StateError('Test deletion failure');
  }
}

class _DelayedUpdateRepository extends InMemoryDeploymentRepository {
  _DelayedUpdateRepository({required super.seedData});

  final Completer<void> _releaseCompleter = Completer<void>();
  int updateCallCount = 0;

  @override
  Future<ServiceDeployment> transitionStatus(
    String deploymentCode,
    DeploymentStatus targetStatus, {
    required String changedByLabel,
    DateTime? changedAt,
  }) async {
    updateCallCount++;
    await _releaseCompleter.future;
    return super.transitionStatus(
      deploymentCode,
      targetStatus,
      changedByLabel: changedByLabel,
      changedAt: changedAt,
    );
  }

  void release() => _releaseCompleter.complete();
}

class _DelayedDeleteRepository extends InMemoryDeploymentRepository {
  _DelayedDeleteRepository({required super.seedData});

  final Completer<void> _releaseCompleter = Completer<void>();
  int deleteCallCount = 0;

  @override
  Future<void> delete(String deploymentId) async {
    deleteCallCount++;
    await _releaseCompleter.future;
    await super.delete(deploymentId);
  }

  void release() => _releaseCompleter.complete();
}
