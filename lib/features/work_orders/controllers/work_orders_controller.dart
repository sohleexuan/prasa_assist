import 'package:flutter/foundation.dart';

import '../data/work_order_repository.dart';
import '../models/work_order.dart';

class WorkOrdersController extends ChangeNotifier {
  WorkOrdersController(this._repository);

  final WorkOrderRepository _repository;
  List<WorkOrder> _workOrders = const [];
  bool _isLoading = false;
  String? _errorMessage;
  int _nextLocalId = 1;

  List<WorkOrder> get workOrders => List.unmodifiable(_workOrders);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _workOrders = await _repository.readAll();
    } catch (_) {
      _errorMessage = 'Unable to load local demonstration work orders.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  WorkOrder? findById(String workOrderId) {
    for (final workOrder in _workOrders) {
      if (workOrder.workOrderId == workOrderId) return workOrder;
    }
    return null;
  }

  Future<WorkOrder> createDraft({
    required String vehicleId,
    required String taskType,
    required String description,
    required WorkOrderPriority priority,
    required String createdBy,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? notes,
  }) async {
    final now = DateTime.now();
    final workOrder = WorkOrder(
      workOrderId: 'WO-LOCAL-${now.microsecondsSinceEpoch}-${_nextLocalId++}',
      vehicleId: vehicleId.trim(),
      taskType: taskType.trim(),
      description: description.trim(),
      priority: priority,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      status: WorkOrderStatus.draft,
      notes: _optional(notes),
      createdBy: createdBy.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _repository.create(workOrder);
    await load();
    return workOrder;
  }

  Future<WorkOrder> updateEligible({
    required WorkOrder original,
    required String vehicleId,
    required String taskType,
    required String description,
    required WorkOrderPriority priority,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? notes,
  }) async {
    if (original.isTerminal) {
      throw StateError('Completed or cancelled work orders cannot be edited.');
    }
    final updated = WorkOrder(
      workOrderId: original.workOrderId,
      incidentId: original.incidentId,
      recommendationId: original.recommendationId,
      vehicleId: vehicleId.trim(),
      taskType: taskType.trim(),
      description: description.trim(),
      priority: priority,
      assignedTo: original.assignedTo,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      status: original.status,
      notes: _optional(notes),
      createdBy: original.createdBy,
      createdAt: original.createdAt,
      updatedAt: DateTime.now(),
      completedAt: original.completedAt,
      cancelledAt: original.cancelledAt,
    );
    await _repository.update(updated);
    await load();
    return updated;
  }

  String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
