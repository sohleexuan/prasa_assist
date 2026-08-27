import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/work_orders/controllers/work_orders_controller.dart';
import 'package:prasa_assist/features/work_orders/data/in_memory_work_order_repository.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/pages/work_order_form_page.dart';

void main() {
  testWidgets('validates required fields before creating a draft', (
    tester,
  ) async {
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: []),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(
      _TestHost(child: WorkOrderFormPage(controller: controller)),
    );
    await _scrollToBottom(tester);
    await tester.tap(find.byKey(const Key('saveWorkOrderButton')));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, 700));
    await tester.pumpAndSettle();

    expect(find.text('Vehicle ID is required.'), findsOneWidget);
    expect(find.text('Task type is required.'), findsOneWidget);
    expect(find.text('Description is required.'), findsOneWidget);
    expect(controller.workOrders, isEmpty);
  });

  testWidgets('creates a local draft after staff review', (tester) async {
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: []),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(
      _TestHost(child: WorkOrderFormPage(controller: controller)),
    );
    await tester.enterText(find.byKey(const Key('vehicleIdField')), 'B2040');
    await tester.enterText(
      find.byKey(const Key('taskTypeField')),
      'Brake inspection',
    );
    await tester.enterText(
      find.byKey(const Key('descriptionField')),
      'Inspect reported brake issue.',
    );
    await _scrollToBottom(tester);
    await tester.tap(find.byKey(const Key('saveWorkOrderButton')));
    await tester.pumpAndSettle();

    expect(controller.workOrders, hasLength(1));
    expect(controller.workOrders.single.status, WorkOrderStatus.draft);
    expect(controller.workOrders.single.vehicleId, 'B2040');
  });

  testWidgets('rejects a schedule whose end is before its start', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 27);
    final invalid = WorkOrder(
      workOrderId: 'WO-1',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Inspect vehicle',
      priority: WorkOrderPriority.high,
      scheduledStart: now.add(const Duration(hours: 2)),
      scheduledEnd: now,
      status: WorkOrderStatus.draft,
      createdBy: 'Staff A',
      createdAt: now,
      updatedAt: now,
    );
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: [invalid]),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(
      _TestHost(
        child: WorkOrderFormPage(controller: controller, workOrder: invalid),
      ),
    );
    await _scrollToBottom(tester);
    await tester.tap(find.byKey(const Key('saveWorkOrderButton')));
    await tester.pump();

    expect(
      find.text('Scheduled end cannot be earlier than scheduled start.'),
      findsOneWidget,
    );
  });
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -700));
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
