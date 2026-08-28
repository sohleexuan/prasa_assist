enum LocalSyncState {
  cachedRemote('cached_remote'),
  localDraft('local_draft'),
  pendingPublication('pending_publication'),
  publicationFailed('publication_failed'),
  conflict('conflict');

  const LocalSyncState(this.storageValue);

  final String storageValue;

  static LocalSyncState fromStorage(String value) {
    for (final state in values) {
      if (state.storageValue == value) {
        return state;
      }
    }
    throw FormatException('Unknown local sync state "$value".');
  }
}
