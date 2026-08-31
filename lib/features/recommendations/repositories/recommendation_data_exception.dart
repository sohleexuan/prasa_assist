class RecommendationDataException implements Exception {
  const RecommendationDataException(this.safeMessage, {this.cause});
  final String safeMessage;
  final Object? cause;
}

class RecommendationOfflineException extends RecommendationDataException {
  const RecommendationOfflineException(super.message, {super.cause});
}

class RecommendationNotFoundException extends RecommendationDataException {
  const RecommendationNotFoundException(super.message, {super.cause});
}

class RecommendationPermissionException extends RecommendationDataException {
  const RecommendationPermissionException(super.message, {super.cause});
}

class RecommendationProviderException extends RecommendationDataException {
  const RecommendationProviderException(super.message, {super.cause});
}

class RecommendationServerException extends RecommendationDataException {
  const RecommendationServerException(super.message, {super.cause});
}

class RecommendationMappingException extends RecommendationDataException {
  const RecommendationMappingException(super.message, {super.cause});
}

class RecommendationConflictException extends RecommendationDataException {
  const RecommendationConflictException(super.message, {super.cause});
}

class RecommendationValidationException extends RecommendationDataException {
  const RecommendationValidationException(super.message, {super.cause});
}
