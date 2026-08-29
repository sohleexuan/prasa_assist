class RecommendationDataException implements Exception {
  const RecommendationDataException(this.safeMessage, {this.cause});
  final String safeMessage;
  final Object? cause;
}

class RecommendationOfflineException extends RecommendationDataException {
  const RecommendationOfflineException(super.message, {super.cause});
}

class RecommendationConflictException extends RecommendationDataException {
  const RecommendationConflictException(super.message, {super.cause});
}

class RecommendationValidationException extends RecommendationDataException {
  const RecommendationValidationException(super.message, {super.cause});
}
