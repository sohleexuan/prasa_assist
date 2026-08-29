import '../dto/incident_record_dto.dart';
import '../dto/local_incident_draft.dart';
import '../../models/local_incident_work_item.dart';

/// Owner-scoped boundary for cached confirmed Incident records.
abstract interface class IncidentLocalDataSource {
  Future<List<IncidentRecordDto>> readConfirmedCache();

  /// The oldest retrieval time represented by the current confirmed cache.
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
