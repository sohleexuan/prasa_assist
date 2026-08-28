Never resolveDatabaseFactory() => unsupportedDatabaseFactory();

Never unsupportedDatabaseFactory() {
  throw UnsupportedError('Local SQLite storage is not supported on web.');
}
