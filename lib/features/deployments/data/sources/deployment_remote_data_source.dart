import '../dto/deployment_record_dto.dart';

/// Persistence-provider boundary for deployment records.
///
/// Implementations may throw the typed failures declared in
/// `deployment_data_exception.dart`. No remote provider is connected yet.
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
