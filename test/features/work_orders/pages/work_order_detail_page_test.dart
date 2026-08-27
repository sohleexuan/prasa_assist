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
        status: status,
        createdBy: 'Demo operations staff',
        createdAt: now,
        updatedAt: now,
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
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(theme: AppTheme.light, home: child);
  }
}
