enum RecommendationReadSource { liveSupabase, cachedSqlite }

class RecommendationReadProvenance {
  RecommendationReadProvenance({
    required this.source,
    required DateTime retrievedAtUtc,
    this.warningMessage,
  }) : retrievedAtUtc = retrievedAtUtc.toUtc();

  final RecommendationReadSource source;
  final DateTime retrievedAtUtc;
  final String? warningMessage;

  bool get isCached => source == RecommendationReadSource.cachedSqlite;
}

class RecommendationReadResult<T> {
  const RecommendationReadResult({
    required this.data,
    required this.provenance,
  });

  final T data;
  final RecommendationReadProvenance provenance;
}
