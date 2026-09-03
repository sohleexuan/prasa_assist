import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/local_sync_state.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/work_orders/controllers/work_orders_controller.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_draft.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_record.dart';
import 'package:prasa_assist/features/work_orders/data/in_memory_work_order_repository.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/models/work_order_read_result.dart';
import 'package:prasa_assist/features/work_orders/pages/work_order_list_page.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_hybrid_operations.dart';

void main() {
  testWidgets('shows the supplied work-order scenario and opens its details', (
    tester,
  ) async {
    final controller = WorkOrdersController(InMemoryWorkOrderRepository());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _TestHost(child: WorkOrderListPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Draft records stay on this device'),
      findsOneWidget,
    );
    expect(find.text('B1023 · Vehicle inspection'), findsOneWidget);
    expect(find.textContaining('Route 300'), findsOneWidget);
    expect(
      find.textContaining('AI recommends. Staff decides.'),
      findsOneWidget,
    );

    await tester.tap(find.text('B1023 · Vehicle inspection'));
    await tester.pumpAndSettle();
    expect(find.text('Work order details'), findsOneWidget);
    expect(find.text('WO-DEMO-001'), findsOneWidget);
  });

  testWidgets('shows the shared empty state for an empty repository', (
    tester,
  ) async {
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: []),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _TestHost(child: WorkOrderListPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No work orders'), findsOneWidget);
    expect(find.text('Create work order'), findsOneWidget);
  });

  testWidgets(
    'remote failure shows the authenticated owner draft as a partial list',
    (tester) async {
      final operations = _OwnerOfflineOperations();
      final controller = WorkOrdersController.hybrid(
        operations,
        localDraftCreatedByLabel: 'cloud.staff@example.com',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _TestHost(child: WorkOrderListPage(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to load work orders'), findsOneWidget);

      await controller.createDraft(
        vehicleId: 'B1023',
        taskType: 'Vehicle inspection',
        description: 'Inspect the Route 300 breakdown.',
        priority: WorkOrderPriority.high,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('B1023'), findsWidgets);
      expect(find.textContaining('Route 300'), findsOneWidget);
      expect(find.text('Unable to load work orders'), findsNothing);
      expect(
        find.textContaining('Showing owner-scoped local drafts'),
        findsOneWidget,
      );
      expect(operations.createdOwnerIds, [operations.authenticatedOwnerId]);

      operations.failRemoteReads = false;
      await tester.tap(find.byKey(const Key('retryConfirmedWorkOrders')));
      await tester.pumpAndSettle();

      expect(find.textContaining('B1023'), findsWidgets);
      expect(find.textContaining('Route 300'), findsOneWidget);
      expect(find.byKey(const Key('retryConfirmedWorkOrders')), findsNothing);
    },
  );

  testWidgets('remains overflow-free on a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = WorkOrdersController(InMemoryWorkOrderRepository());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _TestHost(child: WorkOrderListPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('searches approved fields and clears no-match results', (
    tester,
  ) async {
    final controller = _controllerWithTwoRecords();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _TestHost(child: WorkOrderListPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('workOrderSearchField')),
      'aina',
    );
    await tester.pump();
    expect(find.text('B2040 · Brake repair'), findsOneWidget);
    expect(find.text('B1023 · Vehicle inspection'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('workOrderSearchField')),
      'no match',
    );
    await tester.pump();
    expect(find.text('No matching work orders'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pump();
    expect(find.text('B1023 · Vehicle inspection'), findsOneWidget);
    expect(find.text('B2040 · Brake repair'), findsOneWidget);
  });

  testWidgets('filters local records by status', (tester) async {
    final controller = _controllerWithTwoRecords();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _TestHost(child: WorkOrderListPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<WorkOrderStatus?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assigned').last);
    await tester.pumpAndSettle();

    expect(find.text('B2040 · Brake repair'), findsOneWidget);
    expect(find.text('B1023 · Vehicle inspection'), findsNothing);
  });
}

class _OwnerOfflineOperations extends Fake
    implements WorkOrderHybridOperations {
  final authenticatedOwnerId = '33333333-3333-4333-8333-333333333333';
  final List<LocalWorkOrderRecord> _local = [];
  final List<String> createdOwnerIds = [];
  bool failRemoteReads = true;

  @override
  Future<List<LocalWorkOrderRecord>> readLocalWorkItems() async =>
      List.unmodifiable(_local);

  @override
  Future<WorkOrderReadResult<List<WorkOrder>>> readAllWithProvenance() async {
    if (failRemoteReads) {
      throw const WorkOrderOfflineException(
        'The confirmed work-order service is unavailable.',
      );
    }
    return WorkOrderReadResult(
      data: const [],
      provenance: WorkOrderReadProvenance(
        source: WorkOrderReadSource.liveSupabase,
        retrievedAtUtc: DateTime.utc(2026, 8, 31),
      ),
    );
  }

  @override
  Future<LocalWorkOrderRecord> createLocalDraft(
    LocalWorkOrderDraft draft,
  ) async {
    createdOwnerIds.add(authenticatedOwnerId);
    final record = LocalWorkOrderRecord(
      localId: 'owner-local-${_local.length + 1}',
      ownerUserId: authenticatedOwnerId,
      createdByUserId: authenticatedOwnerId,
      draft: draft,
      status: WorkOrderStatus.draft,
      syncState: LocalSyncState.localDraft,
      localCreatedAt: DateTime.utc(2026, 8, 31),
      localModifiedAt: DateTime.utc(2026, 8, 31),
    );
    _local.add(record);
    return record;
  }
}

WorkOrdersController _controllerWithTwoRecords() {
  final now = DateTime(2026, 8, 27, 9);
  WorkOrder record({
    required String id,
    required String vehicle,
    required String task,
    required String description,
    required WorkOrderStatus status,
    String? assignedTo,
    String? assignedToUserId,
    String? assignedToLabelSnapshot,
  }) => WorkOrder(
    workOrderId: id,
    vehicleId: vehicle,
    taskType: task,
    description: description,
    priority: WorkOrderPriority.high,
    assignedTo: assignedTo,
    assignedToUserId: assignedToUserId,
    assignedToLabelSnapshot: assignedToLabelSnapshot,
    status: status,
    createdByUserId: '11111111-1111-4111-8111-111111111111',
    createdBy: 'Staff A',
    createdAt: now,
    updatedAt: now,
  );
  return WorkOrdersController(
    InMemoryWorkOrderRepository(
      initialWorkOrders: [
        record(
          id: 'WO-1',
          vehicle: 'B1023',
          task: 'Vehicle inspection',
          description: 'Inspect Route 300 breakdown',
          status: WorkOrderStatus.draft,
        ),
        record(
          id: 'WO-2',
          vehicle: 'B2040',
          task: 'Brake repair',
          description: 'Repair brake pads',
          status: WorkOrderStatus.assigned,
          assignedTo: 'Aina Rahman',
          assignedToUserId: '22222222-2222-4222-8222-222222222222',
          assignedToLabelSnapshot: 'Aina Rahman (M-2040)',
        ),
      ],
    ),
  );
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(theme: AppTheme.light, home: child);
  }
}
