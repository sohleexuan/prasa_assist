enum RecommendationStatus { pendingReview, accepted, rejected, superseded }

extension RecommendationStatusTransitions on RecommendationStatus {
  bool canTransitionTo(RecommendationStatus nextStatus) {
    if (this != RecommendationStatus.pendingReview) {
      return false;
    }

    return nextStatus == RecommendationStatus.accepted ||
        nextStatus == RecommendationStatus.rejected ||
        nextStatus == RecommendationStatus.superseded;
  }
}
