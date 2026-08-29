enum IncidentReadSource { liveSupabase, cachedSqlite }

class IncidentReadProvenance {
  IncidentReadProvenance({
    required this.source,
    required DateTime retrievedAtUtc,
    this.warningMessage,
  }) : retrievedAtUtc = retrievedAtUtc.toUtc();
  final IncidentReadSource source;
  final DateTime retrievedAtUtc;
  final String? warningMessage;
  bool get isCached => source == IncidentReadSource.cachedSqlite;
}

class IncidentReadResult<T> {
  const IncidentReadResult({required this.data, required this.provenance});
  final T data;
  final IncidentReadProvenance provenance;
}
