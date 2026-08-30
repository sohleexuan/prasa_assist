import '../data/dto/local_work_order_draft.dart';
import '../data/dto/local_work_order_record.dart';
import '../data/dto/work_order_update_input.dart';
import '../models/work_order.dart';
import '../models/work_order_read_result.dart';

abstract interface class WorkOrderHybridOperations {
  Future<WorkOrderReadResult<List<WorkOrder>>> readAllWithProvenance();
  Future<WorkOrderReadResult<WorkOrder?>> readWithProvenance(
    String workOrderId,
  );
  Future<List<LocalWorkOrderRecord>> readLocalWorkItems();
  Future<LocalWorkOrderRecord?> readLocalWorkItem(String localId);
  Future<LocalWorkOrderRecord> createLocalDraft(LocalWorkOrderDraft draft);
  Future<LocalWorkOrderRecord> updateLocalDraft(
    String localId,
    LocalWorkOrderDraft draft,
  );
  Future<void> discardLocalDraft(String localId);
  Future<WorkOrder> publishLocalDraft(String localId);
  Future<WorkOrder> updateConfirmed(
    String workOrderId,
    WorkOrderUpdateInput input, {
    required int expectedVersion,
  });
  Future<WorkOrder> assignConfirmed(
    String workOrderId, {
    required String assignedTo,
    required int expectedVersion,
  });
  Future<WorkOrder> transitionConfirmed(
    String workOrderId, {
    required WorkOrderStatus fromStatus,
    required WorkOrderStatus toStatus,
    required int expectedVersion,
  });
}
