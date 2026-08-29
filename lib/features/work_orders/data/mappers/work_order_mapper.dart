import '../../models/work_order.dart';
import '../../repositories/work_order_data_exception.dart';
import '../dto/work_order_record_dto.dart';

class WorkOrderMapper {
  const WorkOrderMapper();

  WorkOrder toDomain(WorkOrderRecordDto record) => WorkOrder(
    workOrderId: record.workOrderId,
    incidentId: record.incidentId,
    recommendationId: record.recommendationId,
    vehicleId: record.vehicleId,
    taskType: record.taskType,
    description: record.description,
    priority: record.priority,
    assignedTo: record.assignedTo,
    scheduledStart: record.scheduledStart,
    scheduledEnd: record.scheduledEnd,
    status: record.status,
    notes: record.notes,
    createdByUserId: record.createdByUserId,
    createdBy: record.createdByLabel,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
    completedAt: record.completedAt,
    cancelledAt: record.cancelledAt,
    remoteVersion: record.remoteVersion,
  );

  WorkOrderRecordDto toDto(WorkOrder workOrder, {required String storageId}) {
    final remoteVersion = workOrder.remoteVersion;
    if (remoteVersion == null || remoteVersion < 1) {
      throw const WorkOrderMappingException(
        'Confirmed work-order data requires a valid remote version.',
      );
    }
    final createdByUserId = workOrder.createdByUserId;
    if (createdByUserId == null) {
      throw const WorkOrderMappingException(
        'Confirmed work-order data requires a creator user ID.',
      );
    }
    return WorkOrderRecordDto(
      storageId: storageId,
      workOrderId: workOrder.workOrderId,
      incidentId: workOrder.incidentId,
      recommendationId: workOrder.recommendationId,
      vehicleId: workOrder.vehicleId,
      taskType: workOrder.taskType,
      description: workOrder.description,
      priority: workOrder.priority,
      assignedTo: workOrder.assignedTo,
      scheduledStart: workOrder.scheduledStart,
      scheduledEnd: workOrder.scheduledEnd,
      status: workOrder.status,
      notes: workOrder.notes,
      createdByUserId: createdByUserId,
      createdByLabel: workOrder.createdBy,
      createdAt: workOrder.createdAt,
      updatedAt: workOrder.updatedAt,
      completedAt: workOrder.completedAt,
      cancelledAt: workOrder.cancelledAt,
      remoteVersion: remoteVersion,
    );
  }
}
