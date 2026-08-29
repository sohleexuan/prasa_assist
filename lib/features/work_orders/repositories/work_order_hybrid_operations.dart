import '../data/dto/local_work_order_draft.dart';
import '../data/dto/local_work_order_record.dart';
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
}
