import '../dto/deployment_record_dto.dart';
import '../dto/local_deployment_draft.dart';
import '../dto/local_deployment_record.dart';

abstract interface class DeploymentLocalDataSource {
  Future<List<LocalDeploymentRecord>> readConfirmedCacheRecords();

  Future<LocalDeploymentRecord?> readConfirmedCacheRecordByCode(
    String deploymentCode,
  );

  Future<List<DeploymentRecordDto>> readConfirmedCache();

  Future<DeploymentRecordDto?> readConfirmedCacheByCode(String deploymentCode);

  Future<void> upsertConfirmedCache(
    Iterable<DeploymentRecordDto> records, {
    required DateTime retrievedAtUtc,
  });

  Future<List<LocalDeploymentRecord>> readLocalWorkItems();

  Future<LocalDeploymentRecord?> readLocalWorkItem(String localId);

  Future<LocalDeploymentRecord> createDraft(LocalDeploymentDraft draft);

  Future<LocalDeploymentRecord> updateDraft(
    String localId,
    LocalDeploymentDraft draft,
  );

  Future<LocalDeploymentRecord> markPendingPublication(String localId);

  Future<LocalDeploymentRecord> applyPublicationSuccess(
    String localId,
    DeploymentRecordDto confirmedRecord, {
    required DateTime retrievedAtUtc,
  });

  Future<LocalDeploymentRecord> markPublicationFailure(String localId);

  Future<LocalDeploymentRecord> markConflict(String localId);

  Future<void> discardLocalDraft(String localId);
}
