import '../dto/incident_record_dto.dart';
import '../dto/local_incident_draft.dart';
import '../../models/local_incident_work_item.dart';

abstract interface class IncidentLocalDataSource {
  Future<List<IncidentRecordDto>> readConfirmedCache();

  Future<DateTime?> readConfirmedCacheRetrievedAtUtc();

  Future<IncidentRecordDto?> readConfirmedCacheByCode(String incidentCode);

  Future<void> upsertConfirmedCache(
    Iterable<IncidentRecordDto> records, {
    required DateTime retrievedAtUtc,
  });

  Future<LocalIncidentWorkItem> createDraft(LocalIncidentDraft draft);

  Future<List<LocalIncidentWorkItem>> readLocalWorkItems();

  Future<void> discardDraft(String localId);

  Future<LocalIncidentWorkItem?> readLocalWorkItem(String localId);

  Future<void> markPendingPublication(String localId);

  Future<void> markPublicationFailure(String localId);

  Future<void> markPublicationConflict(String localId);

  Future<void> removePublishedDraft(String localId);
}
