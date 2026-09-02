import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/core/database/local_sync_state.dart';
import 'package:prasa_assist/features/work_orders/controllers/work_orders_controller.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_draft.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_record.dart';
import 'package:prasa_assist/features/work_orders/data/in_memory_work_order_repository.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/models/work_order_read_result.dart';
import 'package:prasa_assist/features/work_orders/pages/work_order_detail_page.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_hybrid_operations.dart';

void main() {
  final now = DateTime.utc(2026, 8, 27, 1);

  WorkOrder record({WorkOrderStatus status = WorkOrderStatus.draft}) =>
      WorkOrder(
        workOrderId: 'WO-DEMO-001',
        vehicleId: 'B1023',
        taskType: 'Vehicle inspection',
        description: 'Inspect breakdown on Route 300.',
        priority: WorkOrderPriority.urgent,
        assignedTo:
            status == WorkOrderStatus.assigned ||
                status == WorkOrderStatus.inProgress ||
                status == WorkOrderStatus.completed
            ? 'Staff B'
            : null,
        scheduledStart: DateTime.utc(2026, 8, 28, 1),
        scheduledEnd: DateTime.utc(2026, 8, 28, 3),
        status: status,
        createdByUserId: '11111111-1111-4111-8111-111111111111',
        createdBy: 'Demo operations staff',
        createdAt: now,
        updatedAt: now,
        completedAt: status == WorkOrderStatus.completed ? now : null,
        cancelledAt: status == WorkOrderStatus.cancelled ? now : null,
      );

  testWidgets('shows complete local record details and staff-control wording', (
    tester,
  ) async {
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: [record()]),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(
      _TestHost(
        child: WorkOrderDetailPage(
          controller: controller,
          workOrderId: 'WO-DEMO-001',
        ),
      ),
    );

    expect(find.text('B1023'), findsOneWidget);
    expect(find.textContaining('Route 300'), findsOneWidget);
    expect(find.text('Not assigned'), findsOneWidget);
    expect(find.text('2026-08-28 09:00 MYT'), findsOneWidget);
    expect(find.text('2026-08-28 11:00 MYT'), findsOneWidget);
    expect(find.text('2026-08-27 09:00 MYT'), findsNWidgets(2));
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('AI recommends. Staff decides.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Edit work order'), findsOneWidget);
  });

  testWidgets('does not offer edit for a terminal retained record', (
    tester,
  ) async {
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(
        initialWorkOrders: [record(status: WorkOrderStatus.completed)],
      ),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(
      _TestHost(
        child: WorkOrderDetailPage(
          controller: controller,
          workOrderId: 'WO-DEMO-001',
        ),
      ),
    );

    expect(find.text('Completed'), findsOneWidget);
    expect(find.byTooltip('Edit work order'), findsNothing);
    expect(controller.workOrders, hasLength(1));
  });

  testWidgets('requires confirmation before opening a draft', (tester) async {
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: [record()]),
    );
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      _TestHost(
        child: WorkOrderDetailPage(
          controller: controller,
          workOrderId: 'WO-DEMO-001',
        ),
      ),
    );
    await _scrollToActions(tester);

    await tester.tap(find.byKey(const Key('openWorkOrderAction')));
    await tester.pumpAndSettle();
    expect(find.text('Open work order?'), findsOneWidget);
    expect(controller.findById('WO-DEMO-001')?.status, WorkOrderStatus.draft);

    await tester.tap(find.byKey(const Key('confirmWorkOrderAction')));
    await tester.pumpAndSettle();
    expect(controller.findById('WO-DEMO-001')?.status, WorkOrderStatus.open);
    expect(find.byKey(const Key('assignWorkOrderAction')), findsOneWidget);
  });

  testWidgets('assignment dialog validates and stores responsible staff', (
    tester,
  ) async {
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(
        initialWorkOrders: [record(status: WorkOrderStatus.open)],
      ),
    );
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      _TestHost(
        child: WorkOrderDetailPage(
          controller: controller,
          workOrderId: 'WO-DEMO-001',
        ),
      ),
    );
    await _scrollToActions(tester);

    await tester.tap(find.byKey(const Key('assignWorkOrderAction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmAssignmentAction')));
    await tester.pump();
    expect(find.text('Responsible staff is required.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('assignedToField')),
      ' Staff B ',
    );
    await tester.tap(find.byKey(const Key('confirmAssignmentAction')));
    await tester.pumpAndSettle();
    expect(controller.findById('WO-DEMO-001')?.assignedTo, 'Staff B');
    expect(
      controller.findById('WO-DEMO-001')?.status,
      WorkOrderStatus.assigned,
    );
  });

  testWidgets('dismissed cancellation leaves the record unchanged', (
    tester,
  ) async {
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: [record()]),
    );
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      _TestHost(
        child: WorkOrderDetailPage(
          controller: controller,
          workOrderId: 'WO-DEMO-001',
        ),
      ),
    );
    await _scrollToActions(tester);

    await tester.tap(find.byKey(const Key('cancelWorkOrderAction')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();

    expect(controller.findById('WO-DEMO-001')?.status, WorkOrderStatus.draft);
  });

  testWidgets('successful publication switches detail to the remote identity', (
    tester,
  ) async {
    final operations = _DetailHybridOperations.withLocalDraft();
    final controller = WorkOrdersController.hybrid(operations);
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(
      _TestHost(
        child: WorkOrderDetailPage(
          controller: controller,
          workOrderId: 'local-publication-key',
        ),
      ),
    );
    await _scrollToActions(tester);
    await tester.tap(find.byKey(const Key('publishWorkOrderAction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmWorkOrderAction')));
    await tester.pumpAndSettle();

    expect(find.text('Work order unavailable'), findsNothing);
    expect(find.text('WO-20260831-000001'), findsOneWidget);
    expect(operations.publicationKeys, ['local-publication-key']);
  });

  testWidgets('unscheduled confirmed Draft explains why Open is disabled', (
    tester,
  ) async {
    final operations = _DetailHybridOperations.withConfirmed(
      _remoteDraft(includeSchedule: false),
    );
    final controller = WorkOrdersController.hybrid(operations);
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(
      _TestHost(
        child: WorkOrderDetailPage(
          controller: controller,
          workOrderId: 'WO-20260831-000001',
        ),
      ),
    );
    await _scrollToActions(tester);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('openWorkOrderAction')),
    );
    expect(button.onPressed, isNull);
    expect(
      find.text('A scheduled start and end are required before continuing.'),
      findsOneWidget,
    );
    expect(operations.transitionCalls, 0);
  });
}

class _DetailHybridOperations extends Fake
    implements WorkOrderHybridOperations {
  _DetailHybridOperations.withLocalDraft()
    : _local = [_localDraftRecord()],
      _confirmed = [];

  _DetailHybridOperations.withConfirmed(WorkOrder workOrder)
    : _local = [],
      _confirmed = [workOrder];

  final List<LocalWorkOrderRecord> _local;
  final List<WorkOrder> _confirmed;
  final List<String> publicationKeys = [];
  int transitionCalls = 0;

  @override
  Future<List<LocalWorkOrderRecord>> readLocalWorkItems() async =>
      List.unmodifiable(_local);

  @override
  Future<WorkOrderReadResult<List<WorkOrder>>> readAllWithProvenance() async =>
      WorkOrderReadResult(
        data: List.unmodifiable(_confirmed),
        provenance: WorkOrderReadProvenance(
          source: WorkOrderReadSource.liveSupabase,
          retrievedAtUtc: DateTime.utc(2026, 8, 31, 9),
        ),
      );

  @override
  Future<WorkOrder> publishLocalDraft(String localId) async {
    publicationKeys.add(localId);
    final local = _local.singleWhere((record) => record.localId == localId);
    _local.remove(local);
    final confirmed = _remoteDraft(
      includeSchedule: true,
      notes: local.draft.notes,
    );
    _confirmed.add(confirmed);
    return confirmed;
  }

  @override
  Future<WorkOrder> transitionConfirmed(
    String workOrderId, {
    required WorkOrderStatus fromStatus,
    required WorkOrderStatus toStatus,
    required int expectedVersion,
  }) async {
    transitionCalls++;
    throw UnimplementedError();
  }
}

LocalWorkOrderRecord _localDraftRecord() => LocalWorkOrderRecord(
  localId: 'local-publication-key',
  ownerUserId: '11111111-1111-4111-8111-111111111111',
  createdByUserId: '11111111-1111-4111-8111-111111111111',
  draft: LocalWorkOrderDraft(
    incidentId: 'INC-20260831-000004',
    recommendationId: '460d90f1-d4f1-451f-ac69-761dc972b652',
    vehicleId: 'B1023',
    taskType: 'Vehicle inspection',
    description: 'Inspect the Route 300 breakdown.',
    priority: WorkOrderPriority.high,
    scheduledStart: DateTime.utc(2026, 8, 31, 10),
    scheduledEnd: DateTime.utc(2026, 8, 31, 11),
    notes: 'Review the advisory evidence before starting work.',
    createdByLabel: 'staff@example.com',
  ),
  status: WorkOrderStatus.draft,
  syncState: LocalSyncState.localDraft,
  localCreatedAt: DateTime.utc(2026, 8, 31, 9),
  localModifiedAt: DateTime.utc(2026, 8, 31, 9),
);

WorkOrder _remoteDraft({bool includeSchedule = true, String? notes}) =>
    WorkOrder(
      workOrderId: 'WO-20260831-000001',
      incidentId: 'INC-20260831-000004',
      recommendationId: '460d90f1-d4f1-451f-ac69-761dc972b652',
      vehicleId: 'B1023',
      taskType: 'Vehicle inspection',
      description: 'Inspect the Route 300 breakdown.',
      priority: WorkOrderPriority.high,
      scheduledStart: includeSchedule ? DateTime.utc(2026, 8, 31, 10) : null,
      scheduledEnd: includeSchedule ? DateTime.utc(2026, 8, 31, 11) : null,
      status: WorkOrderStatus.draft,
      notes: notes,
      createdByUserId: '11111111-1111-4111-8111-111111111111',
      createdBy: 'staff@example.com',
      createdAt: DateTime.utc(2026, 8, 31, 9),
      updatedAt: DateTime.utc(2026, 8, 31, 9),
      remoteVersion: 1,
    );

Future<void> _scrollToActions(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -900));
  await tester.pumpAndSettle();
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(theme: AppTheme.light, home: child);
  }
}
