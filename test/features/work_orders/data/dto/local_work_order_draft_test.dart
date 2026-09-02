import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_draft.dart';
import 'package:prasa_assist/features/work_orders/data/dto/work_order_update_input.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';

void main() {
  test('normalizes values and preserves optional linkage', () {
    final draft = LocalWorkOrderDraft(
      incidentId: ' INC-1 ',
      recommendationId: ' REC-1 ',
      routeId: ' 300 ',
      vehicleId: ' B1023 ',
      taskType: ' Inspection ',
      description: ' Inspect Route 300 ',
      priority: WorkOrderPriority.urgent,
      createdByLabel: ' Staff A ',
    );
    expect(draft.incidentId, 'INC-1');
    expect(draft.recommendationId, 'REC-1');
    expect(draft.routeId, '300');
    expect(draft.vehicleId, 'B1023');
  });

  test('rejects a half-filled or reversed schedule', () {
    expect(
      () => LocalWorkOrderDraft(
        vehicleId: 'B1023',
        taskType: 'Inspection',
        description: 'Inspect',
        priority: WorkOrderPriority.high,
        createdByLabel: 'Staff A',
        scheduledStart: DateTime.utc(2026, 8, 29),
      ),
      throwsA(isA<WorkOrderValidationException>()),
    );
  });

  test('rejects equal schedule instants and accepts a later end', () {
    LocalWorkOrderDraft build(DateTime end) => LocalWorkOrderDraft(
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Inspect',
      priority: WorkOrderPriority.high,
      createdByLabel: 'Staff A',
      scheduledStart: DateTime.utc(2026, 9, 2, 1),
      scheduledEnd: end,
    );

    expect(
      () => build(DateTime.utc(2026, 9, 2, 1)),
      throwsA(isA<WorkOrderValidationException>()),
    );
    expect(build(DateTime.utc(2026, 9, 2, 1, 1)), isA<LocalWorkOrderDraft>());
  });

  test('confirmed update input requires strict schedule ordering', () {
    final instant = DateTime.utc(2026, 9, 2, 1);

    expect(
      () => WorkOrderUpdateInput(
        vehicleId: 'B1023',
        taskType: 'Inspection',
        description: 'Inspect',
        priority: WorkOrderPriority.high,
        scheduledStart: instant,
        scheduledEnd: instant,
      ),
      throwsA(isA<WorkOrderValidationException>()),
    );
  });
}
