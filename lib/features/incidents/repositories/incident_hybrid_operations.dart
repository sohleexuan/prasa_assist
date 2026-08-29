import '../models/incident.dart';
import '../models/incident_query.dart';
import '../models/incident_read_result.dart';
import '../models/local_incident_work_item.dart';
import '../data/dto/local_incident_draft.dart';

abstract interface class IncidentHybridOperations {
  Future<IncidentReadResult<List<Incident>>> getAllWithProvenance({
    IncidentQuery? query,
  });
  Future<IncidentReadResult<Incident?>> getByIdWithProvenance(
    String incidentId,
  );

  Future<List<LocalIncidentWorkItem>> getLocalWorkItems();

  Future<LocalIncidentWorkItem> createLocalDraft(LocalIncidentDraft draft);

  Future<void> discardLocalDraft(String localId);

  Future<Incident> publishLocalDraft(String localId);
}
