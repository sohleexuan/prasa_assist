import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/work_orders/data/dto/work_order_record_dto.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';

void main() {
  test('strict confirmed DTO preserves linkage and normalizes UTC', () {
    final dto = _dto();
    expect(dto.storageId, isNotEmpty);
    expect(dto.incidentId, 'INC-1');
    expect(dto.recommendationId, 'REC-1');
    expect(dto.routeId, '300');
    expect(dto.assignedToUserId, '22222222-2222-4222-8222-222222222222');
    expect(dto.assignedToLabelSnapshot, 'Maintenance One (M-001)');
    expect(dto.createdAt.isUtc, isTrue);
    expect(dto.remoteVersion, 3);
    expect(WorkOrderRecordDto.fromMap(dto.toMap()).toMap(), dto.toMap());
  });

  test('requires confirmed identity and positive version', () {
    expect(
      () => _dto(storageId: ''),
      throwsA(isA<WorkOrderMappingException>()),
    );
    expect(() => _dto(version: 0), throwsA(isA<WorkOrderMappingException>()));
  });

  test(
    'legacy equality row maps for read without becoming a valid schedule',
    () {
      final map = _dto().toMap();
      map['scheduled_end'] = map['scheduled_start'];

      final legacy = WorkOrderRecordDto.fromMap(map);

      expect(legacy.hasLegacyScheduleEquality, isTrue);
      expect(legacy.scheduledEnd, legacy.scheduledStart);
    },
  );
}

WorkOrderRecordDto _dto({
  String storageId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  int version = 3,
}) => WorkOrderRecordDto(
  storageId: storageId,
  workOrderId: 'WO-1',
  incidentId: 'INC-1',
  recommendationId: 'REC-1',
  routeId: '300',
  vehicleId: 'B1023',
  taskType: 'Inspection',
  description: 'Inspect Route 300 breakdown.',
  priority: WorkOrderPriority.urgent,
  assignedTo: 'Maintenance One (M-001)',
  assignedToUserId: '22222222-2222-4222-8222-222222222222',
  assignedToLabelSnapshot: 'Maintenance One (M-001)',
  scheduledStart: DateTime.parse('2026-08-29T10:00:00+08:00'),
  scheduledEnd: DateTime.parse('2026-08-29T11:00:00+08:00'),
  status: WorkOrderStatus.assigned,
  createdByUserId: '11111111-1111-4111-8111-111111111111',
  createdByLabel: 'Staff A',
  createdAt: DateTime.parse('2026-08-29T09:00:00+08:00'),
  updatedAt: DateTime.parse('2026-08-29T09:30:00+08:00'),
  remoteVersion: version,
);
