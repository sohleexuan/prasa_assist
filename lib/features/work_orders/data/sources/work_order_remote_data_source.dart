import '../../models/work_order.dart';
import '../dto/local_work_order_draft.dart';
import '../dto/work_order_record_dto.dart';
import '../dto/work_order_update_input.dart';

abstract interface class WorkOrderRemoteDataSource {
  Future<List<WorkOrderRecordDto>> fetchAll();
  Future<WorkOrderRecordDto?> fetchById(String workOrderId);
  Future<WorkOrderRecordDto> create(LocalWorkOrderDraft draft);
  Future<WorkOrderRecordDto> update(
    String workOrderId,
    WorkOrderUpdateInput input, {
    required int expectedVersion,
  });
  Future<WorkOrderRecordDto> assign(
    String workOrderId, {
    required String assignedTo,
    required int expectedVersion,
  });
  Future<WorkOrderRecordDto> transitionStatus(
    String workOrderId, {
    required WorkOrderStatus fromStatus,
    required WorkOrderStatus toStatus,
    required int expectedVersion,
  });
}
