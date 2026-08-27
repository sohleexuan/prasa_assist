import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';

void main() {
  final createdAt = DateTime(2026, 8, 27, 9);

  test('stores the approved fields and labels enums', () {
    final workOrder = WorkOrder(
      workOrderId: 'WO-1',
      incidentId: 'INC-1',
      recommendationId: 'REC-1',
      vehicleId: 'B1023',
      taskType: 'Vehicle inspection',
      description: 'Inspect breakdown on Route 300.',
      priority: WorkOrderPriority.urgent,
      assignedTo: null,
      scheduledStart: null,
      scheduledEnd: null,
      status: WorkOrderStatus.draft,
      notes: null,
      createdBy: 'Staff A',
      createdAt: createdAt,
      updatedAt: createdAt,
      completedAt: null,
      cancelledAt: null,
    );

    expect(workOrder.workOrderId, 'WO-1');
    expect(workOrder.vehicleId, 'B1023');
    expect(workOrder.priority.label, 'Urgent');
    expect(workOrder.status.label, 'Draft');
    expect(workOrder.isTerminal, isFalse);
  });

  test('copyWith updates eligible values and retains existing values', () {
    final original = WorkOrder(
      workOrderId: 'WO-1',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Original',
      priority: WorkOrderPriority.high,
      status: WorkOrderStatus.draft,
      createdBy: 'Staff A',
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    final updated = original.copyWith(description: 'Updated');

    expect(updated.description, 'Updated');
    expect(updated.workOrderId, original.workOrderId);
    expect(updated.vehicleId, original.vehicleId);
  });

  test('completed and cancelled statuses are terminal', () {
    WorkOrder record(WorkOrderStatus status) => WorkOrder(
      workOrderId: status.name,
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Description',
      priority: WorkOrderPriority.high,
      status: status,
      createdBy: 'Staff A',
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    expect(record(WorkOrderStatus.completed).isTerminal, isTrue);
    expect(record(WorkOrderStatus.cancelled).isTerminal, isTrue);
  });
}
