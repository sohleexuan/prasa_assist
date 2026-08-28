enum DeploymentPersistenceMode { prototype, persistent }

class DeploymentRepositoryCapabilities {
  const DeploymentRepositoryCapabilities({
    required this.mode,
    required this.supportsPhysicalDelete,
    required this.supportsReset,
  });

  const DeploymentRepositoryCapabilities.prototype()
    : this(
        mode: DeploymentPersistenceMode.prototype,
        supportsPhysicalDelete: true,
        supportsReset: true,
      );

  const DeploymentRepositoryCapabilities.persistent()
    : this(
        mode: DeploymentPersistenceMode.persistent,
        supportsPhysicalDelete: false,
        supportsReset: false,
      );

  final DeploymentPersistenceMode mode;
  final bool supportsPhysicalDelete;
  final bool supportsReset;

  bool get isPersistent => mode == DeploymentPersistenceMode.persistent;
}

abstract interface class DeploymentRepositoryCapabilitiesProvider {
  DeploymentRepositoryCapabilities get capabilities;
}

DeploymentRepositoryCapabilities deploymentCapabilitiesOf(Object repository) {
  if (repository is DeploymentRepositoryCapabilitiesProvider) {
    return repository.capabilities;
  }
  return const DeploymentRepositoryCapabilities.prototype();
}
