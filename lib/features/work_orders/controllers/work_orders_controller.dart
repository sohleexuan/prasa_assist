import 'package:flutter/foundation.dart';

import '../../../core/database/local_sync_state.dart';
import '../data/dto/local_work_order_draft.dart';
import '../data/dto/local_work_order_record.dart';
import '../data/dto/work_order_update_input.dart';
import '../data/work_order_repository.dart';
import '../models/work_order.dart';
import '../models/work_order_read_result.dart';
import '../repositories/work_order_data_exception.dart';
import '../repositories/work_order_hybrid_operations.dart';

class WorkOrdersController extends ChangeNotifier {
  WorkOrdersController(this._repository, {DateTime Function()? now})
    : _hybridOperations = null,
      _localDraftCreatedByLabel = 'Current operations staff',
      _now = now ?? DateTime.now;

  WorkOrdersController.hybrid(
    WorkOrderHybridOperations operations, {
    String localDraftCreatedByLabel = 'Current operations staff',
    DateTime Function()? now,
  }) : _repository = null,
       _hybridOperations = operations,
       _localDraftCreatedByLabel = localDraftCreatedByLabel.trim(),
       _now = now ?? DateTime.now {
    if (_localDraftCreatedByLabel.isEmpty) {
      throw ArgumentError.value(
        localDraftCreatedByLabel,
        'localDraftCreatedByLabel',
        'A local draft display label is required.',
      );
    }
  }

  final WorkOrderRepository? _repository;
  final WorkOrderHybridOperations? _hybridOperations;
  final String _localDraftCreatedByLabel;
  final DateTime Function() _now;
  List<WorkOrder> _workOrders = const [];
  bool _isLoading = false;
  String? _errorMessage;
  int _nextLocalId = 1;
  WorkOrderStatus? _selectedStatus;
  String _searchQuery = '';
  Map<String, LocalWorkOrderRecord> _localRecords = const {};
  WorkOrderReadProvenance? _readProvenance;

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
  bool get isHybrid => _hybridOperations != null;
  WorkOrderReadProvenance? get readProvenance => _readProvenance;

  LocalSyncState? localSyncStateFor(String workOrderId) =>
      _localRecords[workOrderId]?.syncState;

  bool isLocalDraft(String workOrderId) {
    final state = localSyncStateFor(workOrderId);
    return state != null && state != LocalSyncState.cachedRemote;
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    if (_hybridOperations == null) {
      try {
        _workOrders = await _repository!.readAll();
        _localRecords = const {};
        _readProvenance = null;
      } catch (_) {
        _errorMessage = 'Unable to load work orders.';
      } finally {
        _isLoading = false;
        notifyListeners();
      }
      return;
    }

    try {
      await _loadHybrid();
    } catch (_) {
      _errorMessage = 'Unable to load work orders.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadHybrid() async {
    List<LocalWorkOrderRecord> local = const [];
    WorkOrderReadResult<List<WorkOrder>>? confirmed;
    Object? localFailure;
    Object? confirmedFailure;

    try {
      local = await _hybridOperations!.readLocalWorkItems();
    } catch (error) {
      localFailure = error;
    }
    try {
      confirmed = await _hybridOperations!.readAllWithProvenance();
    } catch (error) {
      confirmedFailure = error;
    }

    _localRecords = {for (final record in local) record.localId: record};
    _workOrders = List.unmodifiable([
      ...local.map(_toDomain),
      ...?confirmed?.data,
    ]);
    _readProvenance = confirmed?.provenance;

    if (localFailure != null && confirmedFailure != null) {
      _errorMessage = 'Unable to load local drafts or confirmed work orders.';
    } else if (localFailure != null) {
      _errorMessage =
          'Local drafts are unavailable. Showing confirmed work orders only.';
    } else if (confirmedFailure != null) {
      _errorMessage = 'Confirmed work orders are unavailable. Showing owner-scoped local drafts.';
    }
  }

  Future<void> retryConfirmedRecords() async {
    if (_hybridOperations == null) {
      await load();
      return;
    }
    try {
      final confirmed = await _hybridOperations.readAllWithProvenance();
      _workOrders = List.unmodifiable([
        ..._localRecords.values.map(_toDomain),
        ...confirmed.data,
      ]);
      _readProvenance = confirmed.provenance;
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Confirmed work orders are unavailable. Showing owner-scoped local drafts.';
    }
    notifyListeners();
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
    String? routeId,
    required String vehicleId,
    required String taskType,
    required String description,
    required WorkOrderPriority priority,
    String? createdBy,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? notes,
  }) async {
    if (_hybridOperations != null) {
      final record = await _hybridOperations.createLocalDraft(
        LocalWorkOrderDraft(
          incidentId: incidentId,
          recommendationId: recommendationId,
          routeId: routeId,
          vehicleId: vehicleId,
          taskType: taskType,
          description: description,
          priority: priority,
          scheduledStart: scheduledStart,
          scheduledEnd: scheduledEnd,
          notes: notes,
          createdByLabel: _optional(createdBy) ?? _localDraftCreatedByLabel,
        ),
      );
      await load();
      return _toDomain(record);
    }
    final now = _now();
    final workOrder = WorkOrder(
      workOrderId: 'WO-LOCAL-${now.microsecondsSinceEpoch}-${_nextLocalId++}',
      incidentId: _optional(incidentId),
      recommendationId: _optional(recommendationId),
      routeId: _optional(routeId),
      vehicleId: vehicleId.trim(),
      taskType: taskType.trim(),
      description: description.trim(),
      priority: priority,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      status: WorkOrderStatus.draft,
      notes: _optional(notes),
      createdBy: _optional(createdBy) ?? _localDraftCreatedByLabel,
      createdAt: now,
      updatedAt: now,
    );
    final saved = await _repository!.create(workOrder);
    await load();
    return saved;
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
    if (_hybridOperations != null) {
      final local = _localRecords[current.workOrderId];
      if (local != null) {
        final record = await _hybridOperations.updateLocalDraft(
          local.localId,
          LocalWorkOrderDraft(
            incidentId: local.draft.incidentId,
            recommendationId: local.draft.recommendationId,
            routeId: local.draft.routeId,
            vehicleId: vehicleId,
            taskType: taskType,
            description: description,
            priority: priority,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            notes: notes,
            createdByLabel: local.draft.createdByLabel,
          ),
        );
        await load();
        return _toDomain(record);
      }
      final version = current.remoteVersion;
      if (version == null) {
        throw const WorkOrderValidationException(
          'A confirmed work order requires a remote version before it can be updated.',
        );
      }
      final updated = await _hybridOperations.updateConfirmed(
        current.workOrderId,
        WorkOrderUpdateInput(
          vehicleId: vehicleId,
          taskType: taskType,
          description: description,
          priority: priority,
          scheduledStart: scheduledStart,
          scheduledEnd: scheduledEnd,
          notes: notes,
        ),
        expectedVersion: version,
      );
      await load();
      return updated;
    }
    final updated = WorkOrder(
      workOrderId: current.workOrderId,
      incidentId: current.incidentId,
      recommendationId: current.recommendationId,
      routeId: current.routeId,
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
    await _repository!.update(updated);
    await load();
    return updated;
  }

  Future<WorkOrder> openWorkOrder(String workOrderId) async {
    if (_hybridOperations != null) {
      return _transitionConfirmed(workOrderId, WorkOrderStatus.open);
    }
    final current = await _current(workOrderId);
    _requireTransition(current, WorkOrderStatus.open);
    _validateReady(current);
    return _saveTransition(current, WorkOrderStatus.open);
  }

  Future<WorkOrder> assignWorkOrder(
    String workOrderId, {
    required String assignedTo,
  }) async {
    if (_hybridOperations != null) {
      final current = await _current(workOrderId);
      final version = _confirmedVersion(current);
      final updated = await _hybridOperations.assignConfirmed(
        current.workOrderId,
        assignedTo: assignedTo,
        expectedVersion: version,
      );
      await load();
      return updated;
    }
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
    if (_hybridOperations != null) {
      return _transitionConfirmed(workOrderId, WorkOrderStatus.inProgress);
    }
    final current = await _current(workOrderId);
    _requireTransition(current, WorkOrderStatus.inProgress);
    _validateReady(current);
    _validateAssigned(current);
    return _saveTransition(current, WorkOrderStatus.inProgress);
  }

  Future<WorkOrder> completeWork(String workOrderId) async {
    if (_hybridOperations != null) {
      return _transitionConfirmed(workOrderId, WorkOrderStatus.completed);
    }
    final current = await _current(workOrderId);
    _requireTransition(current, WorkOrderStatus.completed);
    _validateReady(current);
    _validateAssigned(current);
    return _saveTransition(current, WorkOrderStatus.completed);
  }

  Future<WorkOrder> cancelWorkOrder(String workOrderId) async {
    if (_hybridOperations != null) {
      return _transitionConfirmed(workOrderId, WorkOrderStatus.cancelled);
    }
    final current = await _current(workOrderId);
    _requireTransition(current, WorkOrderStatus.cancelled);
    return _saveTransition(current, WorkOrderStatus.cancelled);
  }

  Future<WorkOrder> _current(String workOrderId) async {
    if (_hybridOperations != null) {
      final workOrder = findById(workOrderId);
      if (workOrder == null) {
        throw const WorkOrderNotFoundException('Work order not found.');
      }
      return workOrder;
    }
    final workOrder = await _repository!.read(workOrderId);
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
    if (!workOrder.scheduledEnd!.isAfter(workOrder.scheduledStart!)) {
      throw const WorkOrderValidationException(
        'Scheduled end must be later than scheduled start.',
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
      routeId: current.routeId,
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
      allowLegacyScheduleEquality:
          status == WorkOrderStatus.cancelled &&
          current.hasLegacyScheduleEquality,
    );
    await _repository!.update(updated);
    await load();
    return updated;
  }

  String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<WorkOrder> publishLocalDraft(String workOrderId) async {
    if (_hybridOperations == null) {
      throw const WorkOrderValidationException(
        'Publication is unavailable for this work-order data source.',
      );
    }
    final local = _localRecords[workOrderId];
    if (local == null) {
      throw const WorkOrderValidationException(
        'Only a local draft can be published.',
      );
    }
    late final WorkOrder published;
    try {
      published = await _hybridOperations.publishLocalDraft(local.localId);
    } catch (_) {
      await load();
      rethrow;
    }
    await load();
    if (findById(published.workOrderId) == null) {
      _workOrders = List.unmodifiable([
        published,
        ..._workOrders.where(
          (workOrder) => workOrder.workOrderId != local.localId,
        ),
      ]);
      notifyListeners();
    }
    return published;
  }

  Future<WorkOrder> _transitionConfirmed(
    String workOrderId,
    WorkOrderStatus toStatus,
  ) async {
    final current = await _current(workOrderId);
    _requireTransition(current, toStatus);
    if (toStatus != WorkOrderStatus.cancelled) {
      _validateReady(current);
    }
    if (toStatus == WorkOrderStatus.inProgress ||
        toStatus == WorkOrderStatus.completed) {
      _validateAssigned(current);
    }
    final version = _confirmedVersion(current);
    final updated = await _hybridOperations!.transitionConfirmed(
      current.workOrderId,
      fromStatus: current.status,
      toStatus: toStatus,
      expectedVersion: version,
    );
    await load();
    return updated;
  }

  int _confirmedVersion(WorkOrder workOrder) {
    if (isLocalDraft(workOrder.workOrderId) ||
        workOrder.remoteVersion == null) {
      throw const WorkOrderValidationException(
        'Publish the local draft before making a confirmed work-order change.',
      );
    }
    return workOrder.remoteVersion!;
  }

  String? transitionBlockReason(WorkOrder workOrder, WorkOrderStatus toStatus) {
    try {
      _requireTransition(workOrder, toStatus);
      if (toStatus != WorkOrderStatus.cancelled) {
        _validateReady(workOrder);
      }
      if (toStatus == WorkOrderStatus.inProgress ||
          toStatus == WorkOrderStatus.completed) {
        _validateAssigned(workOrder);
      }
      return null;
    } on WorkOrderValidationException catch (error) {
      return error.message;
    }
  }

  WorkOrder _toDomain(LocalWorkOrderRecord record) => WorkOrder(
    workOrderId: record.localId,
    incidentId: record.draft.incidentId,
    recommendationId: record.draft.recommendationId,
    routeId: record.draft.routeId,
    vehicleId: record.draft.vehicleId,
    taskType: record.draft.taskType,
    description: record.draft.description,
    priority: record.draft.priority,
    status: record.status,
    scheduledStart: record.draft.scheduledStart,
    scheduledEnd: record.draft.scheduledEnd,
    notes: record.draft.notes,
    createdByUserId: record.createdByUserId,
    createdBy: record.draft.createdByLabel,
    createdAt: record.localCreatedAt,
    updatedAt: record.localModifiedAt,
    allowLegacyScheduleEquality: record.draft.hasLegacyScheduleEquality,
  );
}
