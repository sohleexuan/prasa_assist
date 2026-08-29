import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/models/delay_estimate.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';
import 'package:prasa_assist/features/incidents/services/delay_estimator.dart';

void main() {
  const estimator = DelayEstimator();

  group('DelayEstimator rule contributions', () {
    test('applies each incident type weight', () {
      const expectedMinutes = <IncidentType, int>{
        IncidentType.vehicleBreakdown: 10,
        IncidentType.accident: 15,
        IncidentType.serviceDisruption: 8,
        IncidentType.infrastructureIssue: 20,
        IncidentType.safetyIncident: 12,
        IncidentType.other: 5,
      };

      for (final entry in expectedMinutes.entries) {
        final result = estimator.estimate(
          incidentType: entry.key,
          severity: IncidentSeverity.low,
          vehicleCondition: VehicleCondition.operational,
          disruptionScope: DisruptionScope.noObstruction,
          reportedAt: _offPeakWeekday,
        );

        expect(
          result.estimatedDelayMinutes,
          entry.value,
          reason: '${entry.key.displayLabel} should use its documented weight',
        );
        expect(
          result.reasons,
          contains(
            '${entry.key.displayLabel} contributed ${entry.value} minutes.',
          ),
        );
      }
    });

    test('applies each severity weight', () {
      const expectedAdditions = <IncidentSeverity, int>{
        IncidentSeverity.low: 0,
        IncidentSeverity.medium: 5,
        IncidentSeverity.high: 15,
        IncidentSeverity.critical: 30,
      };

      for (final entry in expectedAdditions.entries) {
        final result = estimator.estimate(
          incidentType: IncidentType.other,
          severity: entry.key,
          vehicleCondition: VehicleCondition.operational,
          disruptionScope: DisruptionScope.noObstruction,
          reportedAt: _offPeakWeekday,
        );

        expect(result.estimatedDelayMinutes, 5 + entry.value);
        expect(
          result.reasons,
          contains(
            '${entry.key.displayLabel} severity contributed '
            '${entry.value} minutes.',
          ),
        );
      }
    });

    test('applies each vehicle condition weight', () {
      const expectedAdditions = <VehicleCondition, int>{
        VehicleCondition.operational: 0,
        VehicleCondition.limitedOperation: 10,
        VehicleCondition.immobilised: 25,
        VehicleCondition.unknown: 5,
      };

      for (final entry in expectedAdditions.entries) {
        final result = estimator.estimate(
          incidentType: IncidentType.other,
          severity: IncidentSeverity.low,
          vehicleCondition: entry.key,
          disruptionScope: DisruptionScope.noObstruction,
          reportedAt: _offPeakWeekday,
        );

        expect(result.estimatedDelayMinutes, 5 + entry.value);
        expect(
          result.reasons,
          contains(
            '${entry.key.displayLabel} vehicle condition contributed '
            '${entry.value} minutes.',
          ),
        );
      }
    });

    test('applies each disruption scope weight', () {
      const expectedAdditions = <DisruptionScope, int>{
        DisruptionScope.noObstruction: 0,
        DisruptionScope.partialObstruction: 10,
        DisruptionScope.fullObstruction: 25,
        DisruptionScope.unknown: 5,
      };

      for (final entry in expectedAdditions.entries) {
        final result = estimator.estimate(
          incidentType: IncidentType.other,
          severity: IncidentSeverity.low,
          vehicleCondition: VehicleCondition.operational,
          disruptionScope: entry.key,
          reportedAt: _offPeakWeekday,
        );

        expect(result.estimatedDelayMinutes, 5 + entry.value);
        expect(
          result.reasons,
          contains(
            '${entry.key.displayLabel} contributed ${entry.value} minutes.',
          ),
        );
      }
    });

    test('unknown inputs use explicit missing-data additions', () {
      final result = estimator.estimate(
        incidentType: IncidentType.other,
        severity: IncidentSeverity.low,
        vehicleCondition: VehicleCondition.unknown,
        disruptionScope: DisruptionScope.unknown,
        reportedAt: _offPeakWeekday,
      );

      expect(result.estimatedDelayMinutes, 15);
      expect(
        result.reasons,
        contains('Unknown vehicle condition contributed 5 minutes.'),
      );
      expect(result.reasons, contains('Unknown contributed 5 minutes.'));
    });
  });

  group('DelayEstimator peak-hour rule', () {
    test('includes both weekday peak windows and their boundaries', () {
      for (final time in [
        DateTime(2026, 8, 28, 7),
        DateTime(2026, 8, 28, 9, 30),
        DateTime(2026, 8, 28, 16, 30),
        DateTime(2026, 8, 28, 19, 30),
      ]) {
        expect(
          DelayEstimator.isDemonstrationPeakHour(time),
          isTrue,
          reason: '$time should be within a demonstration peak window',
        );
      }
    });

    test('excludes times immediately outside weekday peak windows', () {
      for (final time in [
        DateTime(2026, 8, 28, 6, 59),
        DateTime(2026, 8, 28, 9, 31),
        DateTime(2026, 8, 28, 16, 29),
        DateTime(2026, 8, 28, 19, 31),
      ]) {
        expect(
          DelayEstimator.isDemonstrationPeakHour(time),
          isFalse,
          reason: '$time should be outside demonstration peak windows',
        );
      }
    });

    test('does not treat weekends as peak hour', () {
      expect(
        DelayEstimator.isDemonstrationPeakHour(DateTime(2026, 8, 29, 8)),
        isFalse,
      );
      expect(
        DelayEstimator.isDemonstrationPeakHour(DateTime(2026, 8, 30, 17)),
        isFalse,
      );
    });

    test('applies the 1.25 multiplier and rounds to whole minutes', () {
      final result = estimator.estimate(
        incidentType: IncidentType.serviceDisruption,
        severity: IncidentSeverity.medium,
        vehicleCondition: VehicleCondition.operational,
        disruptionScope: DisruptionScope.noObstruction,
        reportedAt: DateTime(2026, 8, 28, 8),
      );

      expect(result.estimatedDelayMinutes, 16);
      expect(
        result.reasons,
        contains(
          'The demonstration peak-hour factor increased the subtotal by 25%.',
        ),
      );
    });

    test('explains when the peak-hour factor is not applied', () {
      final result = _minimumEstimate(estimator);

      expect(
        result.reasons,
        contains('No demonstration peak-hour factor was applied.'),
      );
    });
  });

  group('DelayEstimator output boundaries', () {
    test('keeps the minimum result at five minutes', () {
      final result = _minimumEstimate(estimator);

      expect(result.estimatedDelayMinutes, DelayEstimator.minimumDelayMinutes);
      expect(result.impactLevel, OperationalImpactLevel.minor);
    });

    test('caps an estimate above 120 minutes', () {
      final result = estimator.estimate(
        incidentType: IncidentType.infrastructureIssue,
        severity: IncidentSeverity.critical,
        vehicleCondition: VehicleCondition.immobilised,
        disruptionScope: DisruptionScope.fullObstruction,
        reportedAt: DateTime(2026, 8, 28, 8),
      );

      expect(result.estimatedDelayMinutes, DelayEstimator.maximumDelayMinutes);
      expect(result.impactLevel, OperationalImpactLevel.severe);
      expect(
        result.reasons,
        contains('The estimate was capped at the 120-minute maximum.'),
      );
    });

    test('classifies every impact boundary', () {
      const expectations = <int, OperationalImpactLevel>{
        5: OperationalImpactLevel.minor,
        15: OperationalImpactLevel.minor,
        16: OperationalImpactLevel.moderate,
        30: OperationalImpactLevel.moderate,
        31: OperationalImpactLevel.major,
        60: OperationalImpactLevel.major,
        61: OperationalImpactLevel.severe,
        120: OperationalImpactLevel.severe,
      };

      for (final entry in expectations.entries) {
        expect(
          DelayEstimator.classifyImpact(entry.key),
          entry.value,
          reason: '${entry.key} minutes should be ${entry.value.displayLabel}',
        );
      }
    });
  });

  group('DelayEstimator representative scenario', () {
    test('estimates 75 severe minutes for Bus B1023 on Route 300', () {
      final result = estimator.estimate(
        incidentType: IncidentType.vehicleBreakdown,
        severity: IncidentSeverity.high,
        vehicleCondition: VehicleCondition.immobilised,
        disruptionScope: DisruptionScope.partialObstruction,
        reportedAt: DateTime(2026, 8, 28, 8),
      );

      expect(result.estimatedDelayMinutes, 75);
      expect(result.impactLevel, OperationalImpactLevel.severe);
      expect(
        result.reasons,
        contains('Vehicle Breakdown contributed 10 minutes.'),
      );
      expect(result.reasons, contains('High severity contributed 15 minutes.'));
      expect(
        result.reasons,
        contains('Immobilised vehicle condition contributed 25 minutes.'),
      );
      expect(
        result.reasons,
        contains('Partial Obstruction contributed 10 minutes.'),
      );
      expect(
        result.reasons.last,
        'PrasaAssist demonstration rules produced this estimate; staff review '
        'is required.',
      );
    });

    test('returns equal results for identical inputs', () {
      final first = estimator.estimate(
        incidentType: IncidentType.vehicleBreakdown,
        severity: IncidentSeverity.high,
        vehicleCondition: VehicleCondition.immobilised,
        disruptionScope: DisruptionScope.partialObstruction,
        reportedAt: DateTime(2026, 8, 28, 8),
      );
      final second = estimator.estimate(
        incidentType: IncidentType.vehicleBreakdown,
        severity: IncidentSeverity.high,
        vehicleCondition: VehicleCondition.immobilised,
        disruptionScope: DisruptionScope.partialObstruction,
        reportedAt: DateTime(2026, 8, 28, 8),
      );

      expect(second, first);
    });
  });
}

final DateTime _offPeakWeekday = DateTime(2026, 8, 28, 12);

DelayEstimate _minimumEstimate(DelayEstimator estimator) {
  return estimator.estimate(
    incidentType: IncidentType.other,
    severity: IncidentSeverity.low,
    vehicleCondition: VehicleCondition.operational,
    disruptionScope: DisruptionScope.noObstruction,
    reportedAt: _offPeakWeekday,
  );
}
