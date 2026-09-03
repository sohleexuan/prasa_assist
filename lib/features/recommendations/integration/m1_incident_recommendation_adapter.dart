import '../../incidents/incident_module.dart' hide VehicleCondition;
import '../domain/recommendation_evidence.dart';
import '../domain/recommendation_rule_input.dart';
import '../domain/verified_incident_recommendation_input.dart';

class IncidentRecommendationStaffConfirmation {
  const IncidentRecommendationStaffConfirmation({
    required this.breakdownConfirmedByStaff,
    required this.operatingPeriod,
    required this.operatingPeriodConfirmedByStaff,
  });

  final bool breakdownConfirmedByStaff;
  final OperatingPeriod operatingPeriod;
  final bool operatingPeriodConfirmedByStaff;
}

class M1IncidentRecommendationAdapter {
  const M1IncidentRecommendationAdapter();

  OperatingPeriod? operatingPeriodPrefill(
    M1IncidentRecommendationFacts facts,
  ) => _isValidDemonstrationScenario(facts) ? OperatingPeriod.peak : null;

  VerifiedIncidentRecommendationInput toVerifiedInput({
    required M1IncidentRecommendationFacts facts,
    required IncidentRecommendationStaffConfirmation confirmation,
    required DateTime evaluatedAt,
  }) {
    final vehicleId = facts.vehicleId?.trim();
    if (vehicleId == null || vehicleId.isEmpty) {
      throw ArgumentError.value(
        facts.vehicleId,
        'facts.vehicleId',
        'A vehicle-based recommendation requires a vehicle ID.',
      );
    }
    if (facts.incidentType != 'vehicle_breakdown') {
      throw StateError(
        'Only a vehicle breakdown can be converted to this recommendation input.',
      );
    }
    if (!confirmation.breakdownConfirmedByStaff) {
      throw StateError('Staff must explicitly confirm the breakdown.');
    }
    if (!confirmation.operatingPeriodConfirmedByStaff ||
        confirmation.operatingPeriod == OperatingPeriod.unknown) {
      throw StateError('Staff must explicitly confirm the operating period.');
    }

    final isDemonstration = _isValidDemonstrationScenario(facts);
    return VerifiedIncidentRecommendationInput(
      incidentId: facts.incidentId,
      vehicleId: vehicleId,
      routeId: facts.routeId,
      vehicleCondition: VehicleCondition.breakdownConfirmed,
      operatingPeriod: confirmation.operatingPeriod,
      vehicleConditionDataClassification: _incidentClassification(facts),
      operatingPeriodDataClassification: isDemonstration
          ? EvidenceDataClassification.demonstrationData
          : EvidenceDataClassification.internalOperationalData,
      evaluatedAt: evaluatedAt,
    );
  }

  bool _isValidDemonstrationScenario(M1IncidentRecommendationFacts facts) =>
      facts.vehicleId?.trim().toUpperCase() == 'B1023' &&
      facts.routeId.trim() == '300' &&
      facts.incidentType == 'vehicle_breakdown' &&
      facts.incidentDataClassification == 'mock_demonstration' &&
      facts.delayEstimateClassification ==
          M1IncidentRecommendationFacts.demonstrationRule;

  EvidenceDataClassification _incidentClassification(
    M1IncidentRecommendationFacts facts,
  ) => switch (facts.incidentDataClassification) {
    'mock_demonstration' => EvidenceDataClassification.demonstrationData,
    'staff_entered' => EvidenceDataClassification.internalOperationalData,
    'live_government' => EvidenceDataClassification.liveGovernmentData,
    'cached_government' => EvidenceDataClassification.cachedData,
    'static_government' => EvidenceDataClassification.staticGovernmentData,
    _ => throw ArgumentError.value(
      facts.incidentDataClassification,
      'facts.incidentDataClassification',
      'is not supported by the Module 1 v1 contract.',
    ),
  };
}
