import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/work_orders/controllers/work_orders_controller.dart';
import 'package:prasa_assist/features/work_orders/data/in_memory_work_order_repository.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/pages/work_order_detail_page.dart';

void main() {
  final now = DateTime(2026, 8, 27, 9);

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
        scheduledStart: DateTime(2026, 8, 28, 9),
        scheduledEnd: DateTime(2026, 8, 28, 11),
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
}

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
