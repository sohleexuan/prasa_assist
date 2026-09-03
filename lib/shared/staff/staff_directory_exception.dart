class StaffDirectoryException implements Exception {
  const StaffDirectoryException(this.safeMessage, {this.cause});

  final String safeMessage;
  final Object? cause;

  @override
  String toString() => safeMessage;
}

class StaffDirectoryOfflineException extends StaffDirectoryException {
  const StaffDirectoryOfflineException(super.safeMessage, {super.cause});
}

class StaffDirectoryPermissionException extends StaffDirectoryException {
  const StaffDirectoryPermissionException(super.safeMessage, {super.cause});
}

class StaffDirectoryMappingException extends StaffDirectoryException {
  const StaffDirectoryMappingException(super.safeMessage, {super.cause});
}
