import '../models/work_order.dart';

/// Local demonstration records only. They are not live, real-time, or
/// government data.
final List<WorkOrder> mockWorkOrders = [
  WorkOrder(
    workOrderId: 'WO-DEMO-001',
    vehicleId: 'B1023',
    taskType: 'Vehicle inspection',
    description:
        'Inspect Bus B1023 after it broke down during peak hour on Route 300.',
    priority: WorkOrderPriority.urgent,
    scheduledStart: DateTime(2026, 8, 27, 10),
    scheduledEnd: DateTime(2026, 8, 27, 12),
    status: WorkOrderStatus.draft,
    notes: 'Demonstration scenario. Staff must review before confirming.',
    createdBy: 'Demo operations staff',
    createdAt: DateTime(2026, 8, 27, 9),
    updatedAt: DateTime(2026, 8, 27, 9),
  ),
];
