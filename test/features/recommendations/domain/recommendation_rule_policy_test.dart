import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_policy.dart';

void main() {
  test('exposes the exact owner-approved policy', () {
    final policy = RecommendationRulePolicy.ownerApproved();
    expect(policy.confirmedBreakdownContribution, 50);
    expect(policy.peakBreakdownContribution, 35);
    expect(policy.replacementBusCount, 2);
    expect(policy.breakdownConfidenceWeight, 0.60);
    expect(policy.operatingPeriodConfidenceWeight, 0.40);
    expect(policy.demonstrationEvidencePenalty, 0.15);
  });

  test('rejects invalid contributions, weights, count, and penalty', () {
    RecommendationRulePolicy build({
      int breakdown = 50,
      int peak = 35,
      int buses = 2,
      double breakdownWeight = 0.60,
      double periodWeight = 0.40,
      double penalty = 0.15,
    }) => RecommendationRulePolicy(
      confirmedBreakdownContribution: breakdown,
      peakBreakdownContribution: peak,
      replacementBusCount: buses,
      breakdownConfidenceWeight: breakdownWeight,
      operatingPeriodConfidenceWeight: periodWeight,
      demonstrationEvidencePenalty: penalty,
    );

    expect(() => build(breakdown: -1), throwsArgumentError);
    expect(() => build(peak: 101), throwsArgumentError);
    expect(() => build(buses: 0), throwsArgumentError);
    expect(() => build(breakdownWeight: double.nan), throwsArgumentError);
    expect(() => build(breakdownWeight: double.infinity), throwsArgumentError);
    expect(() => build(periodWeight: -0.1), throwsArgumentError);
    expect(() => build(periodWeight: 1.01), throwsArgumentError);
    expect(
      () => build(breakdownWeight: 0, periodWeight: 0),
      throwsArgumentError,
    );
    expect(() => build(penalty: double.infinity), throwsArgumentError);
    expect(() => build(penalty: 1.01), throwsArgumentError);
  });
}
