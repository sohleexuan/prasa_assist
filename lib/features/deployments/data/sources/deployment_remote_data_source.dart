import '../dto/deployment_record_dto.dart';
import '../dto/local_deployment_draft.dart';

abstract class DeploymentRemoteDataSource {
  Future<List<DeploymentRecordDto>> fetchAll();

  Future<DeploymentRecordDto?> fetchByCode(String deploymentCode);

  Future<DeploymentRecordDto> insert(DeploymentRecordDto record);

  Future<DeploymentRecordDto> update(
    DeploymentRecordDto record, {
    required int expectedVersion,
  });

  Future<DeploymentRecordDto> transitionStatus(
    String deploymentCode, {
    required String fromStatus,
    required String toStatus,
    required String changedByLabel,
    required DateTime changedAt,
    required int expectedVersion,
  });

  Future<void> delete(String deploymentCode, {required int expectedVersion});
}

abstract interface class DeploymentDraftRemotePublisher {
  Future<DeploymentRecordDto> publishDraft(LocalDeploymentDraft draft);
}
