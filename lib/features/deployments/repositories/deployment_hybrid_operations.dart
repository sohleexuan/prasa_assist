import '../data/dto/local_deployment_draft.dart';
import '../data/dto/local_deployment_record.dart';
import '../models/deployment_read_result.dart';
import '../models/service_deployment.dart';

/// Optional Module 3 operations available from hybrid persistence.
///
/// Keeping this separate preserves the existing [DeploymentRepository]
/// contract for prototype and remote-only implementations.
abstract interface class DeploymentHybridOperations {
  Future<DeploymentReadResult<List<ServiceDeployment>>> getAllWithProvenance();

  Future<DeploymentReadResult<ServiceDeployment?>> getByIdWithProvenance(
    String deploymentId,
  );

  Future<List<LocalDeploymentRecord>> getLocalWorkItems();

  Future<LocalDeploymentRecord?> getLocalWorkItem(String localId);

  Future<LocalDeploymentRecord> createLocalDraft(LocalDeploymentDraft draft);

  Future<LocalDeploymentRecord> updateLocalDraft(
    String localId,
    LocalDeploymentDraft draft,
  );

  Future<void> discardLocalDraft(String localId);

  Future<ServiceDeployment> publishLocalDraft(String localId);
}
