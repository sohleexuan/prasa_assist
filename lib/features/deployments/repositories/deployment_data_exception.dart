abstract class DeploymentDataException implements Exception {
  const DeploymentDataException(this.message, {this.cause});

  final String message;

  final Object? cause;

  @override
  String toString() => message;
}

class DeploymentNotFoundException extends DeploymentDataException {
  const DeploymentNotFoundException(super.message, {super.cause});
}

class DeploymentDuplicateException extends DeploymentDataException {
  const DeploymentDuplicateException(super.message, {super.cause});
}

class DeploymentValidationException extends DeploymentDataException {
  const DeploymentValidationException(super.message, {super.cause});
}

class DeploymentOfflineException extends DeploymentDataException {
  const DeploymentOfflineException(super.message, {super.cause});
}

class DeploymentConflictException extends DeploymentDataException {
  const DeploymentConflictException(super.message, {super.cause});
}

class DeploymentPermissionException extends DeploymentDataException {
  const DeploymentPermissionException(super.message, {super.cause});
}

class DeploymentMappingException extends DeploymentDataException {
  const DeploymentMappingException(super.message, {super.cause});
}

class DeploymentUnknownDataException extends DeploymentDataException {
  const DeploymentUnknownDataException(super.message, {super.cause});
}

class DeploymentLocalStorageException extends DeploymentDataException {
  const DeploymentLocalStorageException(super.message, {super.cause});
}
