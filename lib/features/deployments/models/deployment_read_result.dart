enum DeploymentReadSource { liveSupabase, cachedSqlite }

class DeploymentReadProvenance {
  DeploymentReadProvenance({
    required this.source,
    required DateTime retrievedAtUtc,
    this.warningMessage,
  }) : retrievedAtUtc = retrievedAtUtc.toUtc();

  final DeploymentReadSource source;
  final DateTime retrievedAtUtc;
  final String? warningMessage;

  bool get isCached => source == DeploymentReadSource.cachedSqlite;
}

class DeploymentReadResult<T> {
  const DeploymentReadResult({required this.data, required this.provenance});

  final T data;
  final DeploymentReadProvenance provenance;
}
