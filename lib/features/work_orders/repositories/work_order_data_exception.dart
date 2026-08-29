abstract class WorkOrderDataException implements Exception {
  const WorkOrderDataException(this.message, {this.cause});
  final String message;
  final Object? cause;
  @override
  String toString() => message;
}

class WorkOrderNotFoundException extends WorkOrderDataException {
  const WorkOrderNotFoundException(super.message, {super.cause});
}

class WorkOrderDuplicateException extends WorkOrderDataException {
  const WorkOrderDuplicateException(super.message, {super.cause});
}

class WorkOrderValidationException extends WorkOrderDataException {
  const WorkOrderValidationException(super.message, {super.cause});
}

class WorkOrderOfflineException extends WorkOrderDataException {
  const WorkOrderOfflineException(super.message, {super.cause});
}

class WorkOrderConflictException extends WorkOrderDataException {
  const WorkOrderConflictException(super.message, {super.cause});
}

class WorkOrderPermissionException extends WorkOrderDataException {
  const WorkOrderPermissionException(super.message, {super.cause});
}

class WorkOrderMappingException extends WorkOrderDataException {
  const WorkOrderMappingException(super.message, {super.cause});
}

class WorkOrderCorruptionException extends WorkOrderDataException {
  const WorkOrderCorruptionException(super.message, {super.cause});
}

class WorkOrderLocalStorageException extends WorkOrderDataException {
  const WorkOrderLocalStorageException(super.message, {super.cause});
}

class WorkOrderUnknownDataException extends WorkOrderDataException {
  const WorkOrderUnknownDataException(super.message, {super.cause});
}
