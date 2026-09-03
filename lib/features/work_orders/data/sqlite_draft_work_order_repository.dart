import '../models/work_order.dart';
import '../repositories/work_order_data_exception.dart';
import 'dto/local_work_order_draft.dart';
import 'dto/local_work_order_record.dart';
import 'mappers/work_order_mapper.dart';
import 'sources/work_order_local_data_source.dart';
import 'work_order_repository.dart';

class SqliteDraftWorkOrderRepository implements WorkOrderRepository {
  SqliteDraftWorkOrderRepository(this._localDataSource);

  final WorkOrderLocalDataSource _localDataSource;
  final WorkOrderMapper _mapper = const WorkOrderMapper();

  @override
  Future<WorkOrder> create(WorkOrder workOrder) async {
    if (workOrder.status != WorkOrderStatus.draft) {
      throw const WorkOrderValidationException(
        'Only draft work orders can be stored locally.',
      );
    }
    final record = await _localDataSource.createDraft(_toDraft(workOrder));
    return _toDomain(record);
  }

  @override
  Future<WorkOrder?> read(String workOrderId) async {
    final local = await _localDataSource.readLocalWorkItem(workOrderId);
    if (local != null) return _toDomain(local);
    final confirmed = await _localDataSource.readConfirmedCacheRecordById(
      workOrderId,
    );
    return confirmed == null ? null : _toDomain(confirmed);
  }

  @override
  Future<List<WorkOrder>> readAll() async {
    final local = await _localDataSource.readLocalWorkItems();
    return List.unmodifiable(local.map(_toDomain));
  }

  @override
  Future<WorkOrder> update(WorkOrder workOrder) async {
    if (workOrder.status != WorkOrderStatus.draft) {
      throw const WorkOrderValidationException(
        'Only draft work orders can be updated locally.',
      );
    }
    final record = await _localDataSource.updateDraft(
      workOrder.workOrderId,
      _toDraft(workOrder),
    );
    return _toDomain(record);
  }

  LocalWorkOrderDraft _toDraft(WorkOrder workOrder) => LocalWorkOrderDraft(
    incidentId: workOrder.incidentId,
    recommendationId: workOrder.recommendationId,
    routeId: workOrder.routeId,
    vehicleId: workOrder.vehicleId,
    taskType: workOrder.taskType,
    description: workOrder.description,
    priority: workOrder.priority,
    scheduledStart: workOrder.scheduledStart,
    scheduledEnd: workOrder.scheduledEnd,
    notes: workOrder.notes,
    createdByLabel: workOrder.createdBy,
  );

  WorkOrder _toDomain(LocalWorkOrderRecord record) {
    if (record.isConfirmedRemote) {
      return _mapper.toDomain(record.toConfirmedDto());
    }
    return WorkOrder(
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
}
