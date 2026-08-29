import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_draft.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';

void main() {
  test('normalizes values and preserves optional linkage', () {
    final draft = LocalWorkOrderDraft(
      incidentId: ' INC-1 ',
      recommendationId: ' REC-1 ',
      vehicleId: ' B1023 ',
      taskType: ' Inspection ',
      description: ' Inspect Route 300 ',
      priority: WorkOrderPriority.urgent,
      createdByLabel: ' Staff A ',
    );
    expect(draft.incidentId, 'INC-1');
    expect(draft.recommendationId, 'REC-1');
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
}
