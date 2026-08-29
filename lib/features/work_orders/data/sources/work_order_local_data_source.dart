import '../dto/local_work_order_draft.dart';
import '../dto/local_work_order_record.dart';
import '../dto/work_order_record_dto.dart';

abstract interface class WorkOrderLocalDataSource {
  Future<List<LocalWorkOrderRecord>> readConfirmedCacheRecords();
  Future<LocalWorkOrderRecord?> readConfirmedCacheRecordById(
    String workOrderId,
  );
  Future<List<WorkOrderRecordDto>> readConfirmedCache();
  Future<WorkOrderRecordDto?> readConfirmedCacheById(String workOrderId);
  Future<void> upsertConfirmedCache(
    Iterable<WorkOrderRecordDto> records, {
    required DateTime retrievedAtUtc,
  });
  Future<List<LocalWorkOrderRecord>> readLocalWorkItems();
  Future<LocalWorkOrderRecord?> readLocalWorkItem(String localId);
  Future<LocalWorkOrderRecord> createDraft(LocalWorkOrderDraft draft);
  Future<LocalWorkOrderRecord> updateDraft(
    String localId,
    LocalWorkOrderDraft draft,
  );
  Future<LocalWorkOrderRecord> markPendingPublication(String localId);
  Future<LocalWorkOrderRecord> applyPublicationSuccess(
    String localId,
    WorkOrderRecordDto confirmedRecord, {
    required DateTime retrievedAtUtc,
  });
  Future<LocalWorkOrderRecord> markPublicationFailure(
    String localId,
    String safeMessage,
  );
  Future<LocalWorkOrderRecord> markConflict(String localId, String safeMessage);
  Future<void> discardLocalDraft(String localId);
}
