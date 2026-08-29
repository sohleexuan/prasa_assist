import '../models/delay_estimate.dart';
import '../models/incident_enums.dart';

/// Applies transparent PrasaAssist demonstration rules, not an official
/// Prasarana delay model. All operational results require staff review.
class DelayEstimator {
  const DelayEstimator();

  static const int minimumDelayMinutes = 5;
  static const int maximumDelayMinutes = 120;
  static const double demonstrationPeakHourMultiplier = 1.25;

  DelayEstimate estimate({
    required IncidentType incidentType,
    required IncidentSeverity severity,
    required VehicleCondition vehicleCondition,
    required DisruptionScope disruptionScope,
    required DateTime reportedAt,
  }) {
    final typeMinutes = _incidentTypeMinutes(incidentType);
    final severityMinutes = _severityMinutes(severity);
    final vehicleMinutes = _vehicleConditionMinutes(vehicleCondition);
    final disruptionMinutes = _disruptionScopeMinutes(disruptionScope);
    final subtotal =
        typeMinutes + severityMinutes + vehicleMinutes + disruptionMinutes;
    final isPeakHour = isDemonstrationPeakHour(reportedAt);
    final adjustedDelay = isPeakHour
        ? (subtotal * demonstrationPeakHourMultiplier).round()
        : subtotal;
    final estimatedDelay = adjustedDelay
        .clamp(minimumDelayMinutes, maximumDelayMinutes)
        .toInt();

    final reasons = <String>[
      '${incidentType.displayLabel} contributed $typeMinutes minutes.',
      '${severity.displayLabel} severity contributed $severityMinutes minutes.',
      '${vehicleCondition.displayLabel} vehicle condition contributed '
          '$vehicleMinutes minutes.',
      '${disruptionScope.displayLabel} contributed $disruptionMinutes minutes.',
      if (isPeakHour)
        'The demonstration peak-hour factor increased the subtotal by 25%.'
      else
        'No demonstration peak-hour factor was applied.',
      if (adjustedDelay < minimumDelayMinutes)
        'The estimate was raised to the $minimumDelayMinutes-minute minimum.',
      if (adjustedDelay > maximumDelayMinutes)
        'The estimate was capped at the $maximumDelayMinutes-minute maximum.',
      'PrasaAssist demonstration rules produced this estimate; staff review '
          'is required.',
    ];

    return DelayEstimate(
      estimatedDelayMinutes: estimatedDelay,
      impactLevel: classifyImpact(estimatedDelay),
      reasons: reasons,
    );
  }

  /// Expects [reportedAt] to represent Malaysian local operating time.
  ///
  /// These weekday windows are adjustable project assumptions and must not be
  /// presented as an official Prasarana schedule or policy.
  static bool isDemonstrationPeakHour(DateTime reportedAt) {
    final isWeekday =
        reportedAt.weekday >= DateTime.monday &&
        reportedAt.weekday <= DateTime.friday;
    if (!isWeekday) {
      return false;
    }

    final minutesSinceMidnight = reportedAt.hour * 60 + reportedAt.minute;
    const morningStart = 7 * 60;
    const morningEnd = 9 * 60 + 30;
    const eveningStart = 16 * 60 + 30;
    const eveningEnd = 19 * 60 + 30;

    return (minutesSinceMidnight >= morningStart &&
            minutesSinceMidnight <= morningEnd) ||
        (minutesSinceMidnight >= eveningStart &&
            minutesSinceMidnight <= eveningEnd);
  }

  static OperationalImpactLevel classifyImpact(int delayMinutes) {
    if (delayMinutes <= 15) {
      return OperationalImpactLevel.minor;
    }
    if (delayMinutes <= 30) {
      return OperationalImpactLevel.moderate;
    }
    if (delayMinutes <= 60) {
      return OperationalImpactLevel.major;
    }
    return OperationalImpactLevel.severe;
  }

  static int _incidentTypeMinutes(IncidentType incidentType) {
    return switch (incidentType) {
      IncidentType.vehicleBreakdown => 10,
      IncidentType.accident => 15,
      IncidentType.serviceDisruption => 8,
      IncidentType.infrastructureIssue => 20,
      IncidentType.safetyIncident => 12,
      IncidentType.other => 5,
    };
  }

  static int _severityMinutes(IncidentSeverity severity) {
    return switch (severity) {
      IncidentSeverity.low => 0,
      IncidentSeverity.medium => 5,
      IncidentSeverity.high => 15,
      IncidentSeverity.critical => 30,
    };
  }

  static int _vehicleConditionMinutes(VehicleCondition vehicleCondition) {
    return switch (vehicleCondition) {
      VehicleCondition.operational => 0,
      VehicleCondition.limitedOperation => 10,
      VehicleCondition.immobilised => 25,
      VehicleCondition.unknown => 5,
    };
  }

  static int _disruptionScopeMinutes(DisruptionScope disruptionScope) {
    return switch (disruptionScope) {
      DisruptionScope.noObstruction => 0,
      DisruptionScope.partialObstruction => 10,
      DisruptionScope.fullObstruction => 25,
      DisruptionScope.unknown => 5,
    };
  }
}
