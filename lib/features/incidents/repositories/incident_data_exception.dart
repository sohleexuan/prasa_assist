import '../services/incident_validator.dart';

abstract class IncidentDataException implements Exception {
  const IncidentDataException(this.message, {this.cause});

  final String message;

  final Object? cause;

  @override
  String toString() => message;
}

class IncidentNotFoundException extends IncidentDataException {
  const IncidentNotFoundException(super.message, {super.cause});
}

class IncidentDuplicateException extends IncidentDataException {
  const IncidentDuplicateException(super.message, {super.cause});
}

class IncidentValidationException extends IncidentDataException {
  const IncidentValidationException(
    super.message, {
    this.issues = const [],
    super.cause,
  });

  final List<IncidentValidationIssue> issues;
}

class IncidentReadOnlyException extends IncidentDataException {
  const IncidentReadOnlyException(super.message, {super.cause});
}

class IncidentDeletionException extends IncidentDataException {
  const IncidentDeletionException(super.message, {super.cause});
}

class IncidentOfflineException extends IncidentDataException {
  const IncidentOfflineException(super.message, {super.cause});
}

class IncidentConflictException extends IncidentDataException {
  const IncidentConflictException(super.message, {super.cause});
}

class IncidentPermissionException extends IncidentDataException {
  const IncidentPermissionException(super.message, {super.cause});
}

class IncidentPersistenceSetupException extends IncidentDataException {
  const IncidentPersistenceSetupException(super.message, {super.cause});
}

class IncidentMappingException extends IncidentDataException {
  const IncidentMappingException(super.message, {super.cause});
}

class IncidentUnknownDataException extends IncidentDataException {
  const IncidentUnknownDataException(super.message, {super.cause});
}
