import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_draft.dart';
import 'package:prasa_assist/features/work_orders/data/dto/work_order_record_dto.dart';
import 'package:prasa_assist/features/work_orders/data/dto/work_order_update_input.dart';
import 'package:prasa_assist/features/work_orders/data/sources/work_order_remote_data_source.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';

void main() {
  test(
    'remote contract uses staff-editable update input and typed statuses',
    () {
      WorkOrderRemoteDataSource source = _FakeRemote();
      expect(source, isA<WorkOrderRemoteDataSource>());
    },
  );

  test('update input contains only staff-editable fields', () {
    final input = WorkOrderUpdateInput(
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Inspect vehicle',
      priority: WorkOrderPriority.high,
    );
    expect(input.vehicleId, 'B1023');
  });

  test('update input validates required values and schedule ordering', () {
    WorkOrderUpdateInput input({
      String vehicleId = 'B1023',
      String taskType = 'Inspection',
      String description = 'Inspect vehicle',
      DateTime? start,
      DateTime? end,
    }) => WorkOrderUpdateInput(
      vehicleId: vehicleId,
      taskType: taskType,
      description: description,
      priority: WorkOrderPriority.high,
      scheduledStart: start,
      scheduledEnd: end,
      notes: '  reviewed  ',
    );

    for (final invalid in [
      () => input(vehicleId: ' '),
      () => input(taskType: ' '),
      () => input(description: ' '),
      () => input(start: DateTime.utc(2026, 8, 29)),
      () => input(
        start: DateTime.utc(2026, 8, 29, 2),
        end: DateTime.utc(2026, 8, 29, 1),
      ),
    ]) {
      expect(invalid, throwsA(isA<WorkOrderValidationException>()));
    }
    final normalized = input(
      start: DateTime.parse('2026-08-29T10:00:00+08:00'),
      end: DateTime.parse('2026-08-29T11:00:00+08:00'),
    );
    expect(normalized.scheduledStart?.isUtc, isTrue);
    expect(normalized.notes, 'reviewed');
  });
}

class _FakeRemote implements WorkOrderRemoteDataSource {
  @override
  Future<WorkOrderRecordDto> assign(
    String workOrderId, {
    required String assignedToUserId,
    required int expectedVersion,
  }) => throw UnimplementedError();
  @override
  Future<WorkOrderRecordDto> create(
    String publicationKey,
    LocalWorkOrderDraft draft,
  ) => throw UnimplementedError();
  @override
  Future<List<WorkOrderRecordDto>> fetchAll() => throw UnimplementedError();
  @override
  Future<WorkOrderRecordDto?> fetchById(String workOrderId) =>
      throw UnimplementedError();
  @override
  Future<WorkOrderRecordDto> transitionStatus(
    String workOrderId, {
    required WorkOrderStatus toStatus,
    required int expectedVersion,
  }) => throw UnimplementedError();
  @override
  Future<WorkOrderRecordDto> update(
    String workOrderId,
    WorkOrderUpdateInput input, {
    required int expectedVersion,
  }) => throw UnimplementedError();
}
