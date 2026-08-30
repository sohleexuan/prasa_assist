import 'recommendation_evidence.dart';
import 'recommendation_rule_input.dart';

/// Verified incident facts supplied by the owning incident workflow.
///
/// This Module 4 contract is deliberately independent from Module 1 models.
/// It contains only facts that deterministic recommendation rules may use.
class VerifiedIncidentRecommendationInput {
  VerifiedIncidentRecommendationInput({
    required String incidentId,
    required String vehicleId,
    required String routeId,
    required this.vehicleCondition,
    required this.operatingPeriod,
    required this.vehicleConditionDataClassification,
    required this.operatingPeriodDataClassification,
    required DateTime evaluatedAt,
  }) : incidentId = _required(incidentId, 'incidentId'),
       vehicleId = _required(vehicleId, 'vehicleId'),
       routeId = _required(routeId, 'routeId'),
       evaluatedAt = evaluatedAt.toUtc();

  final String incidentId;
  final String vehicleId;
  final String routeId;
  final VehicleCondition vehicleCondition;
  final OperatingPeriod operatingPeriod;
  final EvidenceDataClassification vehicleConditionDataClassification;
  final EvidenceDataClassification operatingPeriodDataClassification;
  final DateTime evaluatedAt;

  RecommendationRuleInput toRuleInput() => RecommendationRuleInput(
    incidentId: incidentId,
    vehicleId: vehicleId,
    routeId: routeId,
    vehicleCondition: vehicleCondition,
    operatingPeriod: operatingPeriod,
    vehicleConditionDataClassification: vehicleConditionDataClassification,
    operatingPeriodDataClassification: operatingPeriodDataClassification,
    evaluatedAt: evaluatedAt,
  );
}

String _required(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
  return normalized;
}
