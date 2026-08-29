import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/work_orders/data/dto/work_order_record_dto.dart';
import 'package:prasa_assist/features/work_orders/data/mappers/work_order_mapper.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';

void main() {
  test('maps confirmed DTO to domain without losing linkage or version', () {
    final dto = WorkOrderRecordDto(
      storageId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      workOrderId: 'WO-1',
      incidentId: 'INC-1',
      recommendationId: 'REC-1',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Inspect Route 300 breakdown.',
      priority: WorkOrderPriority.urgent,
      status: WorkOrderStatus.open,
      createdByUserId: '11111111-1111-4111-8111-111111111111',
      createdByLabel: 'Staff A',
      createdAt: DateTime.utc(2026, 8, 29),
      updatedAt: DateTime.utc(2026, 8, 29),
      remoteVersion: 4,
    );
    final domain = const WorkOrderMapper().toDomain(dto);
    expect(domain.incidentId, 'INC-1');
    expect(domain.recommendationId, 'REC-1');
    expect(domain.remoteVersion, 4);
    expect(domain.createdByUserId, dto.createdByUserId);
  });

  test('toDto rejects an absent remote version with a safe exception', () {
    final local = WorkOrder(
      workOrderId: 'WO-LOCAL-1',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Inspect vehicle',
      priority: WorkOrderPriority.high,
      status: WorkOrderStatus.draft,
      createdBy: 'Demo staff',
      createdAt: DateTime.utc(2026, 8, 29),
      updatedAt: DateTime.utc(2026, 8, 29),
    );

    expect(
      () => const WorkOrderMapper().toDto(
        local,
        storageId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      ),
      throwsA(
        isA<WorkOrderMappingException>().having(
          (error) => error.message,
          'message',
          'Confirmed work-order data requires a valid remote version.',
        ),
      ),
    );
  });
}
