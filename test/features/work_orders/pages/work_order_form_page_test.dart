import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/work_orders/controllers/work_orders_controller.dart';
import 'package:prasa_assist/features/work_orders/data/in_memory_work_order_repository.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/models/work_order_prefill.dart';
import 'package:prasa_assist/features/work_orders/pages/work_order_form_page.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';

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

  testWidgets(
    'uses editable create-mode recommendation prefill and links IDs',
    (tester) async {
      final controller = WorkOrdersController(
        InMemoryWorkOrderRepository(initialWorkOrders: []),
      );
      addTearDown(controller.dispose);
      await controller.load();
      final prefill = WorkOrderPrefill(
        incidentId: 'INC-1',
        recommendationId: 'REC-1',
        vehicleId: 'B1023',
        taskType: 'Vehicle inspection',
        description: 'Inspect the confirmed breakdown.',
        priority: WorkOrderPriority.high,
        notes: 'AI-generated summary: Staff must verify the vehicle.',
      );

      await tester.pumpWidget(
        _TestHost(
          child: WorkOrderFormPage(controller: controller, prefill: prefill),
        ),
      );

      expect(find.text('Create work order'), findsOneWidget);
      expect(controller.workOrders, isEmpty);
      expect(
        find.widgetWithText(DropdownButtonFormField<WorkOrderPriority>, 'High'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('taskTypeField')),
        'Safety inspection',
      );
      await _scrollToBottom(tester);
      await tester.tap(find.byKey(const Key('saveWorkOrderButton')));
      await tester.pumpAndSettle();

      expect(controller.workOrders.single.recommendationId, 'REC-1');
      expect(controller.workOrders.single.incidentId, 'INC-1');
      expect(controller.workOrders.single.taskType, 'Safety inspection');
      expect(controller.workOrders.single.priority, WorkOrderPriority.high);
    },
  );

  test('domain rejects a schedule whose end is before its start', () {
    final now = DateTime(2026, 8, 27);
    expect(
      () => WorkOrder(
        workOrderId: 'WO-1',
        vehicleId: 'B1023',
        taskType: 'Inspection',
        description: 'Inspect vehicle',
        priority: WorkOrderPriority.high,
        scheduledStart: now.add(const Duration(hours: 2)),
        scheduledEnd: now,
        status: WorkOrderStatus.draft,
        createdByUserId: '11111111-1111-4111-8111-111111111111',
        createdBy: 'Staff A',
        createdAt: now,
        updatedAt: now,
      ),
      throwsA(isA<WorkOrderValidationException>()),
    );
  });

  testWidgets('defensively blocks editing a terminal record', (tester) async {
    final now = DateTime(2026, 8, 27);
    final completed = WorkOrder(
      workOrderId: 'WO-1',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Completed inspection',
      priority: WorkOrderPriority.high,
      assignedTo: 'Staff B',
      status: WorkOrderStatus.completed,
      createdByUserId: '11111111-1111-4111-8111-111111111111',
      createdBy: 'Staff A',
      createdAt: now,
      updatedAt: now,
      completedAt: now,
    );
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: [completed]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _TestHost(
        child: WorkOrderFormPage(controller: controller, workOrder: completed),
      ),
    );

    expect(find.text('Editing unavailable'), findsOneWidget);
    expect(find.byKey(const Key('saveWorkOrderButton')), findsNothing);
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
