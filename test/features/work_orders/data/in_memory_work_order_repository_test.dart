import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/work_orders/data/in_memory_work_order_repository.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';

void main() {
  final now = DateTime(2026, 8, 27);
  WorkOrder record(String id,
          {String description = 'Inspect vehicle', String? routeId = '300'}) =>
      WorkOrder(
        workOrderId: id,
        incidentId: 'INC-1',
        recommendationId: 'REC-1',
        routeId: routeId,
        vehicleId: 'B1023',
        taskType: 'Inspection',
        description: description,
        priority: WorkOrderPriority.urgent,
        status: WorkOrderStatus.draft,
        createdByUserId: '11111111-1111-4111-8111-111111111111',
        createdBy: 'Staff A',
        createdAt: now,
        updatedAt: now,
      );

  test('creates, reads, and updates local records', () async {
    final repository = InMemoryWorkOrderRepository(initialWorkOrders: []);
    await repository.create(record('WO-1'));

    expect((await repository.readAll()), hasLength(1));
    expect((await repository.read('WO-1'))?.vehicleId, 'B1023');

    await repository.update(record('WO-1', description: 'Updated'));
    expect((await repository.read('WO-1'))?.description, 'Updated');
  });

  test('rejects duplicate creation and update of missing record', () async {
    final repository = InMemoryWorkOrderRepository(
      initialWorkOrders: [record('WO-1')],
    );

    expect(
      () => repository.create(record('WO-1')),
      throwsA(isA<WorkOrderDuplicateException>()),
    );
    expect(
      () => repository.update(record('WO-2')),
      throwsA(isA<WorkOrderNotFoundException>()),
    );
  });

  test('readAll returns an unmodifiable view', () async {
    final repository = InMemoryWorkOrderRepository(
      initialWorkOrders: [record('WO-1')],
    );
    final records = await repository.readAll();

    expect(() => records.add(record('WO-2')), throwsUnsupportedError);
  });

  test('rejects linkage mutation at the repository boundary', () async {
    final repository = InMemoryWorkOrderRepository(
      initialWorkOrders: [record('WO-1')],
    );

    await expectLater(
      repository.update(record('WO-1', routeId: '999')),
      throwsA(isA<WorkOrderValidationException>()),
    );
    expect((await repository.read('WO-1'))?.routeId, '300');
  });
}
