import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/local_sync_state.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_draft.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_record.dart';
import 'package:prasa_assist/features/work_orders/data/mappers/work_order_local_mapper.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';

void main() {
  test('local mapper round-trips draft linkage and canonical UTC', () {
    final record = LocalWorkOrderRecord(
      localId: 'draft-1',
      ownerUserId: '11111111-1111-4111-8111-111111111111',
      createdByUserId: '11111111-1111-4111-8111-111111111111',
      draft: LocalWorkOrderDraft(
        incidentId: 'INC-1',
        recommendationId: 'REC-1',
        vehicleId: 'B1023',
        taskType: 'Inspection',
        description: 'Inspect Route 300 breakdown.',
        priority: WorkOrderPriority.urgent,
        createdByLabel: 'Staff A',
      ),
      status: WorkOrderStatus.draft,
      syncState: LocalSyncState.localDraft,
      localCreatedAt: DateTime.parse('2026-08-29T08:00:00+08:00'),
      localModifiedAt: DateTime.parse('2026-08-29T08:00:00+08:00'),
    );
    const mapper = WorkOrderLocalMapper();
    final restored = mapper.fromRow(mapper.toRow(record));
    expect(restored.draft.incidentId, 'INC-1');
    expect(restored.draft.recommendationId, 'REC-1');
    expect(restored.localCreatedAt.isUtc, isTrue);
    expect(restored.syncState, LocalSyncState.localDraft);
  });
}
