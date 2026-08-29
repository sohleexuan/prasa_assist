import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';

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
      createdByUserId: '11111111-1111-4111-8111-111111111111',
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
      createdByUserId: '11111111-1111-4111-8111-111111111111',
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
      assignedTo: status == WorkOrderStatus.completed ? 'Staff B' : null,
      status: status,
      createdByUserId: '11111111-1111-4111-8111-111111111111',
      createdBy: 'Staff A',
      createdAt: createdAt,
      updatedAt: createdAt,
      completedAt: status == WorkOrderStatus.completed ? createdAt : null,
      cancelledAt: status == WorkOrderStatus.cancelled ? createdAt : null,
    );

    expect(record(WorkOrderStatus.completed).isTerminal, isTrue);
    expect(record(WorkOrderStatus.cancelled).isTerminal, isTrue);
  });

  test('allows only the approved status workflow', () {
    expect(WorkOrderStatus.draft.canTransitionTo(WorkOrderStatus.open), isTrue);
    expect(
      WorkOrderStatus.open.canTransitionTo(WorkOrderStatus.assigned),
      isTrue,
    );
    expect(
      WorkOrderStatus.assigned.canTransitionTo(WorkOrderStatus.inProgress),
      isTrue,
    );
    expect(
      WorkOrderStatus.inProgress.canTransitionTo(WorkOrderStatus.completed),
      isTrue,
    );
    for (final status in WorkOrderStatus.values.where(
      (status) => !status.isTerminal,
    )) {
      expect(status.canTransitionTo(WorkOrderStatus.cancelled), isTrue);
    }
    expect(
      WorkOrderStatus.draft.canTransitionTo(WorkOrderStatus.assigned),
      isFalse,
    );
    expect(
      WorkOrderStatus.completed.canTransitionTo(WorkOrderStatus.cancelled),
      isFalse,
    );
    expect(
      WorkOrderStatus.cancelled.canTransitionTo(WorkOrderStatus.open),
      isFalse,
    );
  });

  test('normalizes timestamps to UTC and validates remote version', () {
    final local = DateTime.parse('2026-08-29T10:00:00+08:00');
    final workOrder = WorkOrder(
      workOrderId: 'WO-1',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Inspect vehicle',
      priority: WorkOrderPriority.high,
      status: WorkOrderStatus.draft,
      createdByUserId: '11111111-1111-4111-8111-111111111111',
      createdBy: 'Staff A',
      createdAt: local,
      updatedAt: local,
      remoteVersion: 1,
    );
    expect(workOrder.createdAt, DateTime.utc(2026, 8, 29, 2));
    expect(workOrder.createdAt.isUtc, isTrue);
    expect(
      () => workOrder.copyWith(remoteVersion: 0),
      throwsA(isA<WorkOrderValidationException>()),
    );
  });

  test('creator UUID is optional locally and required when confirmed', () {
    final local = WorkOrder(
      workOrderId: 'WO-LOCAL-1',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Inspect vehicle',
      priority: WorkOrderPriority.high,
      status: WorkOrderStatus.draft,
      createdBy: 'Demo staff',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    expect(local.createdByUserId, isNull);
    expect(
      () => local.copyWith(remoteVersion: 1),
      throwsA(isA<WorkOrderValidationException>()),
    );
  });

  test('copyWith explicitly clears every nullable field', () {
    final value = WorkOrder(
      workOrderId: 'WO-1',
      incidentId: 'INC-1',
      recommendationId: 'REC-1',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Inspect vehicle',
      priority: WorkOrderPriority.high,
      assignedTo: 'Staff B',
      scheduledStart: createdAt,
      scheduledEnd: createdAt,
      status: WorkOrderStatus.open,
      notes: 'Note',
      createdByUserId: '11111111-1111-4111-8111-111111111111',
      createdBy: 'Staff A',
      createdAt: createdAt,
      updatedAt: createdAt,
      remoteVersion: 2,
    );
    final cleared = value.copyWith(
      incidentId: null,
      recommendationId: null,
      assignedTo: null,
      scheduledStart: null,
      scheduledEnd: null,
      notes: null,
      completedAt: null,
      cancelledAt: null,
      remoteVersion: null,
    );
    expect(cleared.incidentId, isNull);
    expect(cleared.recommendationId, isNull);
    expect(cleared.assignedTo, isNull);
    expect(cleared.scheduledStart, isNull);
    expect(cleared.scheduledEnd, isNull);
    expect(cleared.notes, isNull);
    expect(cleared.remoteVersion, isNull);
  });

  test('uses package-free value equality and hashCode', () {
    final first = WorkOrder(
      workOrderId: 'WO-1',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Inspect vehicle',
      priority: WorkOrderPriority.high,
      status: WorkOrderStatus.draft,
      createdByUserId: '11111111-1111-4111-8111-111111111111',
      createdBy: 'Staff A',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final second = first.copyWith();
    expect(second, first);
    expect(second.hashCode, first.hashCode);
  });
}
