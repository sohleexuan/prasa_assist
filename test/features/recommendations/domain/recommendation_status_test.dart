import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_status.dart';

void main() {
  test('pending review can transition to accepted', () {
    expect(
      RecommendationStatus.pendingReview.canTransitionTo(
        RecommendationStatus.accepted,
      ),
      isTrue,
    );
  });

  test('pending review can transition to rejected', () {
    expect(
      RecommendationStatus.pendingReview.canTransitionTo(
        RecommendationStatus.rejected,
      ),
      isTrue,
    );
  });

  test('pending review can transition to superseded', () {
    expect(
      RecommendationStatus.pendingReview.canTransitionTo(
        RecommendationStatus.superseded,
      ),
      isTrue,
    );
  });

  test('terminal statuses cannot transition to another status', () {
    const terminalStatuses = [
      RecommendationStatus.accepted,
      RecommendationStatus.rejected,
      RecommendationStatus.superseded,
    ];

    for (final currentStatus in terminalStatuses) {
      for (final nextStatus in RecommendationStatus.values) {
        expect(
          currentStatus.canTransitionTo(nextStatus),
          isFalse,
          reason:
              '${currentStatus.name} must not transition to ${nextStatus.name}',
        );
      }
    }
  });
}
