import '../models/work_order.dart';
import '../repositories/work_order_data_exception.dart';
import 'mock_work_orders.dart';
import 'work_order_repository.dart';

class InMemoryWorkOrderRepository implements WorkOrderRepository {
  InMemoryWorkOrderRepository({List<WorkOrder>? initialWorkOrders})
    : _workOrders = List.of(initialWorkOrders ?? mockWorkOrders);

  final List<WorkOrder> _workOrders;

  @override
  Future<WorkOrder> create(WorkOrder workOrder) async {
    if (_workOrders.any(
      (existing) => existing.workOrderId == workOrder.workOrderId,
    )) {
      throw const WorkOrderDuplicateException(
        'A work order with this ID already exists.',
      );
    }
    _workOrders.add(workOrder);
    return workOrder;
  }

  @override
  Future<WorkOrder?> read(String workOrderId) async {
    for (final workOrder in _workOrders) {
      if (workOrder.workOrderId == workOrderId) return workOrder;
    }
    return null;
  }

  @override
  Future<List<WorkOrder>> readAll() async => List.unmodifiable(_workOrders);

  @override
  Future<WorkOrder> update(WorkOrder workOrder) async {
    final index = _workOrders.indexWhere(
      (existing) => existing.workOrderId == workOrder.workOrderId,
    );
    if (index == -1) {
      throw const WorkOrderNotFoundException('Work order not found.');
    }
    _workOrders[index] = workOrder;
    return workOrder;
  }
}
