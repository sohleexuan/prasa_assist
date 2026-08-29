import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/local_user_scope.dart';
import 'package:prasa_assist/core/database/migrations/app_database_migration_v4.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/work_orders/controllers/work_orders_controller.dart';
import 'package:prasa_assist/features/work_orders/data/in_memory_work_order_repository.dart';
import 'package:prasa_assist/features/work_orders/data/sqlite_draft_work_order_repository.dart';
import 'package:prasa_assist/features/work_orders/data/sources/sqlite_work_order_local_data_source.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/models/work_order_prefill.dart';
import 'package:prasa_assist/features/work_orders/pages/work_order_form_page.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';

import '../../../support/sqlite_test_database.dart';

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
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final localDataSource = SqliteWorkOrderLocalDataSource(
        database: database,
        userScope: LocalUserScope(_ownerUserId),
        localIdGenerator: () => 'work-order-local-1',
        clock: () => DateTime.utc(2026, 8, 29, 9),
      );
      final controller = WorkOrdersController(
        SqliteDraftWorkOrderRepository(localDataSource),
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
      expect(find.text('Edit work order'), findsNothing);
      expect(controller.workOrders, isEmpty);
      expect(await localDataSource.readLocalWorkItems(), isEmpty);
      expect(
        await database.query(AppDatabaseMigrationV4.workOrderRecordsTable),
        isEmpty,
      );
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
      final persisted = await localDataSource.readLocalWorkItems();
      expect(persisted, hasLength(1));
      expect(persisted.single.draft.recommendationId, 'REC-1');
      expect(persisted.single.draft.incidentId, 'INC-1');
      final rows = await database.query(
        AppDatabaseMigrationV4.workOrderRecordsTable,
      );
      expect(rows, hasLength(1));
      expect(rows.single['recommendation_id'], 'REC-1');
      expect(rows.single['incident_id'], 'INC-1');
    },
  );

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
}

const _ownerUserId = '11111111-1111-4111-8111-111111111111';

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
