import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/models/delay_estimate.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';

void main() {
  group('DelayEstimate', () {
    test('keeps reasons immutable', () {
      final originalReasons = ['Vehicle breakdown contributed 10 minutes.'];
      final estimate = DelayEstimate(
        estimatedDelayMinutes: 10,
        impactLevel: OperationalImpactLevel.minor,
        reasons: originalReasons,
      );

      originalReasons.add('Unexpected reason');

      expect(estimate.reasons, ['Vehicle breakdown contributed 10 minutes.']);
      expect(
        () => estimate.reasons.add('Another reason'),
        throwsUnsupportedError,
      );
    });

    test('valid estimate returns no validation messages', () {
      expect(_estimate().validate(), isEmpty);
    });

    test('enforces the documented delay bounds', () {
      expect(
        _estimate(minutes: 4).validate(),
        contains('Estimated delay must be between 5 and 120 minutes.'),
      );
      expect(_estimate(minutes: 5).validate(), isEmpty);
      expect(_estimate(minutes: 120).validate(), isEmpty);
      expect(
        _estimate(minutes: 121).validate(),
        contains('Estimated delay must be between 5 and 120 minutes.'),
      );
    });

    test('requires non-blank explanation reasons', () {
      expect(
        _estimate(reasons: const []).validate(),
        contains('At least one estimation reason is required.'),
      );
      expect(
        _estimate(reasons: const ['valid', ' ']).validate(),
        contains('Estimation reasons cannot be blank.'),
      );
    });

    test('implements value equality and matching hash codes', () {
      final first = _estimate();
      final equalEstimate = _estimate();
      final differentEstimate = _estimate(minutes: 30);

      expect(equalEstimate, first);
      expect(equalEstimate.hashCode, first.hashCode);
      expect(differentEstimate, isNot(first));
    });
  });
}

DelayEstimate _estimate({
  int minutes = 15,
  OperationalImpactLevel impactLevel = OperationalImpactLevel.minor,
  List<String> reasons = const ['Explainable project rule.'],
}) {
  return DelayEstimate(
    estimatedDelayMinutes: minutes,
    impactLevel: impactLevel,
    reasons: reasons,
  );
}
