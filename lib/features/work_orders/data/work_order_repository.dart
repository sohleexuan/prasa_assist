import '../models/work_order.dart';

abstract interface class WorkOrderRepository {
  /// Reads records available through the implementation's persistence mode.
  Future<List<WorkOrder>> readAll();

  Future<WorkOrder?> read(String workOrderId);

  /// In-memory mode creates a local demonstration record. A future persistent
  /// implementation must use the remote authority for confirmed creation.
  Future<WorkOrder> create(WorkOrder workOrder);

  /// In-memory mode updates local demonstration data. A future persistent
  /// implementation must send only staff-editable values to its remote source.
  Future<WorkOrder> update(WorkOrder workOrder);
}
