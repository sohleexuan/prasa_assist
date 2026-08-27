import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/work_orders/controllers/work_orders_controller.dart';
import 'package:prasa_assist/features/work_orders/data/in_memory_work_order_repository.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';

void main() {
  test('loads local records and creates a normalized draft', () async {
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: []),
    );
    await controller.load();

    final created = await controller.createDraft(
      vehicleId: ' B1023 ',
      taskType: ' Inspection ',
      description: ' Inspect Route 300 breakdown ',
      priority: WorkOrderPriority.urgent,
      notes: '   ',
      createdBy: ' Staff A ',
    );

    expect(created.status, WorkOrderStatus.draft);
    expect(created.vehicleId, 'B1023');
    expect(created.notes, isNull);
    expect(controller.workOrders, hasLength(1));
  });

  test('updates an eligible local record', () async {
    final now = DateTime(2026, 8, 27);
    final original = WorkOrder(
      workOrderId: 'WO-1',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Original',
      priority: WorkOrderPriority.high,
      status: WorkOrderStatus.draft,
      createdBy: 'Staff A',
      createdAt: now,
      updatedAt: now,
    );
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: [original]),
    );
    await controller.load();

    await controller.updateEligible(
      original: original,
      vehicleId: 'B1023',
      taskType: 'Vehicle inspection',
      description: 'Updated description',
      priority: WorkOrderPriority.urgent,
    );

    expect(controller.findById('WO-1')?.description, 'Updated description');
  });

  test('does not edit a terminal record', () async {
    final now = DateTime(2026, 8, 27);
    final completed = WorkOrder(
      workOrderId: 'WO-1',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Done',
      priority: WorkOrderPriority.high,
      status: WorkOrderStatus.completed,
      createdBy: 'Staff A',
      createdAt: now,
      updatedAt: now,
      completedAt: now,
    );
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: [completed]),
    );
    await controller.load();

    expect(
      () => controller.updateEligible(
        original: completed,
        vehicleId: 'B1023',
        taskType: 'Inspection',
        description: 'Changed',
        priority: WorkOrderPriority.high,
      ),
      throwsStateError,
    );
    expect(controller.workOrders, hasLength(1));
  });
}
