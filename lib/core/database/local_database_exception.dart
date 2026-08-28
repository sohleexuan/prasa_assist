class LocalDatabaseException implements Exception {
  const LocalDatabaseException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

class LocalDatabaseOpenException extends LocalDatabaseException {
  const LocalDatabaseOpenException(super.message, {super.cause});
}

class LocalDatabaseUnsupportedException extends LocalDatabaseException {
  const LocalDatabaseUnsupportedException(super.message, {super.cause});
}

class LocalDatabaseClosedException extends LocalDatabaseException {
  const LocalDatabaseClosedException(super.message);
}

class LocalDatabaseOperationException extends LocalDatabaseException {
  const LocalDatabaseOperationException(super.message, {super.cause});
}
