enum IncidentPersistenceMode { prototype, persistent }

class IncidentRepositoryCapabilities {
  const IncidentRepositoryCapabilities({
    required this.mode,
    required this.supportsPhysicalDelete,
    required this.supportsReset,
  });

  const IncidentRepositoryCapabilities.prototype()
    : this(
        mode: IncidentPersistenceMode.prototype,
        supportsPhysicalDelete: true,
        supportsReset: true,
      );

  const IncidentRepositoryCapabilities.persistent()
    : this(
        mode: IncidentPersistenceMode.persistent,
        supportsPhysicalDelete: false,
        supportsReset: false,
      );

  final IncidentPersistenceMode mode;
  final bool supportsPhysicalDelete;
  final bool supportsReset;

  bool get isPersistent => mode == IncidentPersistenceMode.persistent;
}

abstract interface class IncidentRepositoryCapabilitiesProvider {
  IncidentRepositoryCapabilities get capabilities;
}

IncidentRepositoryCapabilities incidentCapabilitiesOf(Object repository) {
  if (repository is IncidentRepositoryCapabilitiesProvider) {
    return repository.capabilities;
  }
  return const IncidentRepositoryCapabilities.prototype();
}
