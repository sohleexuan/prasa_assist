enum WorkOrderReadSource { liveSupabase, cachedSqlite }

class WorkOrderReadProvenance {
  WorkOrderReadProvenance({
    required this.source,
    required DateTime retrievedAtUtc,
    this.warningMessage,
  }) : retrievedAtUtc = retrievedAtUtc.toUtc();

  final WorkOrderReadSource source;
  final DateTime retrievedAtUtc;
  final String? warningMessage;
  bool get isCached => source == WorkOrderReadSource.cachedSqlite;
}

class WorkOrderReadResult<T> {
  const WorkOrderReadResult({required this.data, required this.provenance});
  final T data;
  final WorkOrderReadProvenance provenance;
}
