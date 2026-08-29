import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/local_sync_state.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_draft.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_record.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';

void main() {
  test(
    'unpublished record keeps owner and creator UUID separate in meaning',
    () {
      final record = LocalWorkOrderRecord(
        localId: 'draft-1',
        ownerUserId: '11111111-1111-4111-8111-111111111111',
        createdByUserId: '11111111-1111-4111-8111-111111111111',
        draft: _draft(),
        status: WorkOrderStatus.draft,
        syncState: LocalSyncState.localDraft,
        localCreatedAt: DateTime.utc(2026, 8, 29),
        localModifiedAt: DateTime.utc(2026, 8, 29),
      );
      expect(record.ownerUserId, record.createdByUserId);
      expect(record.remoteStorageId, isNull);
    },
  );

  test('confirmed state rejects incomplete remote metadata', () {
    expect(
      () => LocalWorkOrderRecord(
        localId: 'cache-1',
        ownerUserId: '11111111-1111-4111-8111-111111111111',
        createdByUserId: '22222222-2222-4222-8222-222222222222',
        draft: _draft(),
        status: WorkOrderStatus.open,
        syncState: LocalSyncState.cachedRemote,
        localCreatedAt: DateTime.utc(2026, 8, 29),
        localModifiedAt: DateTime.utc(2026, 8, 29),
      ),
      throwsA(isA<WorkOrderValidationException>()),
    );
  });
}

LocalWorkOrderDraft _draft() => LocalWorkOrderDraft(
  vehicleId: 'B1023',
  taskType: 'Inspection',
  description: 'Inspect Route 300 breakdown.',
  priority: WorkOrderPriority.urgent,
  createdByLabel: 'Staff A',
);
