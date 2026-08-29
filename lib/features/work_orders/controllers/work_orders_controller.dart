import 'package:flutter/foundation.dart';

import '../data/work_order_repository.dart';
import '../models/work_order.dart';
import '../repositories/work_order_data_exception.dart';

class WorkOrdersController extends ChangeNotifier {
  WorkOrdersController(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final WorkOrderRepository _repository;
  final DateTime Function() _now;
  List<WorkOrder> _workOrders = const [];
  bool _isLoading = false;
  String? _errorMessage;
  int _nextLocalId = 1;
  WorkOrderStatus? _selectedStatus;
  String _searchQuery = '';

  List<WorkOrder> get workOrders => List.unmodifiable(_workOrders);
  List<WorkOrder> get visibleWorkOrders {
    final query = _searchQuery.trim().toLowerCase();
    return List.unmodifiable(
      _workOrders.where((workOrder) {
        final matchesStatus =
            _selectedStatus == null || workOrder.status == _selectedStatus;
        if (!matchesStatus) return false;
        if (query.isEmpty) return true;
        return [
          workOrder.workOrderId,
          workOrder.vehicleId,
          workOrder.taskType,
          workOrder.description,
          workOrder.assignedTo ?? '',
        ].any((value) => value.toLowerCase().contains(query));
      }),
    );
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  WorkOrderStatus? get selectedStatus => _selectedStatus;
  String get searchQuery => _searchQuery;
  bool get hasActiveFilters =>
      _selectedStatus != null || _searchQuery.trim().isNotEmpty;

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

  void setStatusFilter(WorkOrderStatus? status) {
    if (_selectedStatus == status) return;
    _selectedStatus = status;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    if (!hasActiveFilters) return;
    _selectedStatus = null;
    _searchQuery = '';
    notifyListeners();
  }

  Future<WorkOrder> createDraft({
    String? incidentId,
    String? recommendationId,
    required String vehicleId,
    required String taskType,
    required String description,
    required WorkOrderPriority priority,
    required String createdBy,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? notes,
  }) async {
    final now = _now();
    final workOrder = WorkOrder(
      workOrderId: 'WO-LOCAL-${now.microsecondsSinceEpoch}-${_nextLocalId++}',
      incidentId: _optional(incidentId),
      recommendationId: _optional(recommendationId),
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
    final current = await _current(original.workOrderId);
    if (current.isTerminal) {
      throw StateError('Completed or cancelled work orders cannot be edited.');
    }
    final updated = WorkOrder(
      workOrderId: current.workOrderId,
      incidentId: current.incidentId,
      recommendationId: current.recommendationId,
      vehicleId: vehicleId.trim(),
      taskType: taskType.trim(),
      description: description.trim(),
      priority: priority,
      assignedTo: current.assignedTo,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      status: current.status,
      notes: _optional(notes),
      createdByUserId: current.createdByUserId,
      createdBy: current.createdBy,
      createdAt: current.createdAt,
      updatedAt: _now(),
      completedAt: current.completedAt,
      cancelledAt: current.cancelledAt,
    );
    await _repository.update(updated);
    await load();
    return updated;
  }

  Future<WorkOrder> openWorkOrder(String workOrderId) async {
    final current = await _current(workOrderId);
    _requireTransition(current, WorkOrderStatus.open);
    _validateReady(current);
    return _saveTransition(current, WorkOrderStatus.open);
  }

  Future<WorkOrder> assignWorkOrder(
    String workOrderId, {
    required String assignedTo,
  }) async {
    final current = await _current(workOrderId);
    _requireTransition(current, WorkOrderStatus.assigned);
    _validateReady(current);
    final normalized = assignedTo.trim();
    if (normalized.isEmpty) {
      throw const WorkOrderValidationException(
        'Responsible staff is required before assignment.',
      );
    }
    return _saveTransition(
      current,
      WorkOrderStatus.assigned,
      assignedTo: normalized,
    );
  }

  Future<WorkOrder> startWork(String workOrderId) async {
    final current = await _current(workOrderId);
    _requireTransition(current, WorkOrderStatus.inProgress);
    _validateReady(current);
    _validateAssigned(current);
    return _saveTransition(current, WorkOrderStatus.inProgress);
  }

  Future<WorkOrder> completeWork(String workOrderId) async {
    final current = await _current(workOrderId);
    _requireTransition(current, WorkOrderStatus.completed);
    _validateReady(current);
    _validateAssigned(current);
    return _saveTransition(current, WorkOrderStatus.completed);
  }

  Future<WorkOrder> cancelWorkOrder(String workOrderId) async {
    final current = await _current(workOrderId);
    _requireTransition(current, WorkOrderStatus.cancelled);
    return _saveTransition(current, WorkOrderStatus.cancelled);
  }

  Future<WorkOrder> _current(String workOrderId) async {
    final workOrder = await _repository.read(workOrderId);
    if (workOrder == null) throw StateError('Work order not found.');
    return workOrder;
  }

  void _requireTransition(WorkOrder current, WorkOrderStatus next) {
    if (!current.status.canTransitionTo(next)) {
      throw WorkOrderValidationException(
        'Cannot change ${current.status.label} to ${next.label}.',
      );
    }
  }

  void _validateReady(WorkOrder workOrder) {
    if (workOrder.vehicleId.trim().isEmpty ||
        workOrder.taskType.trim().isEmpty ||
        workOrder.description.trim().isEmpty ||
        workOrder.createdBy.trim().isEmpty) {
      throw const WorkOrderValidationException(
        'Complete all required work-order details before continuing.',
      );
    }
    if (workOrder.scheduledStart == null || workOrder.scheduledEnd == null) {
      throw const WorkOrderValidationException(
        'A scheduled start and end are required before continuing.',
      );
    }
    if (workOrder.scheduledEnd!.isBefore(workOrder.scheduledStart!)) {
      throw const WorkOrderValidationException(
        'Scheduled end cannot be earlier than scheduled start.',
      );
    }
  }

  void _validateAssigned(WorkOrder workOrder) {
    if (workOrder.assignedTo == null || workOrder.assignedTo!.trim().isEmpty) {
      throw const WorkOrderValidationException(
        'Responsible staff is required before continuing.',
      );
    }
  }

  Future<WorkOrder> _saveTransition(
    WorkOrder current,
    WorkOrderStatus status, {
    String? assignedTo,
  }) async {
    final now = _now();
    final updated = WorkOrder(
      workOrderId: current.workOrderId,
      incidentId: current.incidentId,
      recommendationId: current.recommendationId,
      vehicleId: current.vehicleId,
      taskType: current.taskType,
      description: current.description,
      priority: current.priority,
      assignedTo: assignedTo ?? current.assignedTo,
      scheduledStart: current.scheduledStart,
      scheduledEnd: current.scheduledEnd,
      status: status,
      notes: current.notes,
      createdByUserId: current.createdByUserId,
      createdBy: current.createdBy,
      createdAt: current.createdAt,
      updatedAt: now,
      completedAt: status == WorkOrderStatus.completed ? now : null,
      cancelledAt: status == WorkOrderStatus.cancelled ? now : null,
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
