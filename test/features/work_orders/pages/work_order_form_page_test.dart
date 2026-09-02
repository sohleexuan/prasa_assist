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
        routeId: '300',
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
      expect(find.text('Edit work order'), findsNothing);
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
      expect(find.text('Linked records'), findsOneWidget);
      expect(find.text('INC-1'), findsOneWidget);
      expect(find.text('REC-1'), findsOneWidget);
      expect(find.text('300'), findsOneWidget);
      await tester.tap(find.byKey(const Key('saveWorkOrderButton')));
      await tester.pumpAndSettle();

      expect(controller.workOrders.single.recommendationId, 'REC-1');
      expect(controller.workOrders.single.incidentId, 'INC-1');
      expect(controller.workOrders.single.routeId, '300');
      expect(controller.workOrders.single.taskType, 'Safety inspection');
      expect(controller.workOrders.single.priority, WorkOrderPriority.high);
      expect(
        controller.workOrders.single.notes,
        'AI-generated summary: Staff must verify the vehicle.',
      );
    },
  );

  testWidgets('rapid repeated save taps create at most one local draft', (
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
    await tester.enterText(find.byKey(const Key('vehicleIdField')), 'B1023');
    await tester.enterText(
      find.byKey(const Key('taskTypeField')),
      'Vehicle inspection',
    );
    await tester.enterText(
      find.byKey(const Key('descriptionField')),
      'Inspect the Route 300 breakdown.',
    );
    await _scrollToBottom(tester);

    final save = find.byKey(const Key('saveWorkOrderButton'));
    expect(find.text('Save local draft'), findsOneWidget);
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(controller.workOrders, hasLength(1));
  });

  test('old non-prefill createDraft calls retain absent linkage', () async {
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: []),
    );
    addTearDown(controller.dispose);

    final created = await controller.createDraft(
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Inspect the vehicle.',
      priority: WorkOrderPriority.medium,
      createdBy: 'Staff A',
    );

    expect(created.incidentId, isNull);
    expect(created.recommendationId, isNull);
  });

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

  testWidgets('edits UTC schedule values as Malaysia wall-clock time', (
    tester,
  ) async {
    final start = DateTime.utc(2026, 9, 1, 20, 30);
    final end = DateTime.utc(2026, 9, 1, 21, 30);
    final workOrder = WorkOrder(
      workOrderId: 'WO-1',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Inspect the vehicle.',
      priority: WorkOrderPriority.high,
      scheduledStart: start,
      scheduledEnd: end,
      status: WorkOrderStatus.draft,
      createdBy: 'Staff A',
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: [workOrder]),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(
      _TestHost(
        child: WorkOrderFormPage(controller: controller, workOrder: workOrder),
      ),
    );

    expect(find.text('Scheduled start: 2026-09-02 04:30 MYT'), findsOneWidget);
    expect(find.text('Scheduled end: 2026-09-02 05:30 MYT'), findsOneWidget);
    final startButton = find.text('Scheduled start: 2026-09-02 04:30 MYT');
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('OK'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.text('OK'),
      ),
    );
    await tester.pumpAndSettle();
    await _scrollToBottom(tester);
    expect(find.text('Save local draft'), findsOneWidget);
    await tester.tap(find.byKey(const Key('saveWorkOrderButton')));
    await tester.pumpAndSettle();

    final saved = controller.findById('WO-1')!;
    expect(saved.scheduledStart, start);
    expect(saved.scheduledEnd, end);
    expect(saved.scheduledStart!.isUtc, isTrue);
    expect(saved.scheduledEnd!.isUtc, isTrue);
  });

  testWidgets('form rejects a legacy schedule whose UTC instants are equal', (
    tester,
  ) async {
    final instant = DateTime.utc(2026, 9, 2, 1);
    final workOrder = WorkOrder(
      workOrderId: 'WO-LEGACY-EQUAL',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Legacy equality row',
      priority: WorkOrderPriority.high,
      scheduledStart: instant,
      scheduledEnd: instant,
      status: WorkOrderStatus.draft,
      createdBy: 'Staff A',
      createdAt: DateTime.utc(2026, 9, 2),
      updatedAt: DateTime.utc(2026, 9, 2),
      allowLegacyScheduleEquality: true,
    );
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: [workOrder]),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(
      _TestHost(
        child: WorkOrderFormPage(controller: controller, workOrder: workOrder),
      ),
    );
    await _scrollToBottom(tester);
    await tester.tap(find.byKey(const Key('saveWorkOrderButton')));
    await tester.pumpAndSettle();

    expect(
      find.text('Scheduled end must be later than scheduled start.'),
      findsOneWidget,
    );
    expect(controller.findById(workOrder.workOrderId), workOrder);
  });

  testWidgets('confirmed remote edit uses Save changes wording', (
    tester,
  ) async {
    final workOrder = WorkOrder(
      workOrderId: 'WO-REMOTE-1',
      incidentId: 'INC-LONG-123456789012345678901234567890',
      recommendationId: 'REC-LONG-123456789012345678901234567890',
      routeId: '300',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Inspect the vehicle.',
      priority: WorkOrderPriority.high,
      status: WorkOrderStatus.draft,
      createdByUserId: '11111111-1111-4111-8111-111111111111',
      createdBy: 'Staff A',
      createdAt: DateTime.utc(2026, 9, 2),
      updatedAt: DateTime.utc(2026, 9, 2),
      remoteVersion: 4,
    );
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: [workOrder]),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(
      _TestHost(
        child: WorkOrderFormPage(controller: controller, workOrder: workOrder),
      ),
    );
    await _scrollToBottom(tester);

    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Save local draft'), findsNothing);
  });
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('saveWorkOrderButton')),
    300,
    scrollable: find.byType(Scrollable).first,
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
