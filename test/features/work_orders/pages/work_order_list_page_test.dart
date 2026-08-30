import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/work_orders/controllers/work_orders_controller.dart';
import 'package:prasa_assist/features/work_orders/data/in_memory_work_order_repository.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/pages/work_order_list_page.dart';

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

WorkOrdersController _controllerWithTwoRecords() {
  final now = DateTime(2026, 8, 27, 9);
  WorkOrder record({
    required String id,
    required String vehicle,
    required String task,
    required String description,
    required WorkOrderStatus status,
    String? assignedTo,
  }) => WorkOrder(
    workOrderId: id,
    vehicleId: vehicle,
    taskType: task,
    description: description,
    priority: WorkOrderPriority.high,
    assignedTo: assignedTo,
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
