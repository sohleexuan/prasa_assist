import '../models/work_order.dart';

abstract interface class WorkOrderRepository {
  Future<List<WorkOrder>> readAll();

  Future<WorkOrder?> read(String workOrderId);

  Future<WorkOrder> create(WorkOrder workOrder);

  Future<WorkOrder> update(WorkOrder workOrder);
}
