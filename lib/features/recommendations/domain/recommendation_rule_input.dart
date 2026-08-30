import 'recommendation_evidence.dart';

enum VehicleCondition { breakdownConfirmed, operational, unknown }

enum OperatingPeriod { peak, offPeak, unknown }

class RecommendationRuleInput {
  RecommendationRuleInput({
    required String incidentId,
    required String vehicleId,
    required String routeId,
    required this.vehicleCondition,
    required this.operatingPeriod,
    required this.vehicleConditionDataClassification,
    required this.operatingPeriodDataClassification,
    required DateTime evaluatedAt,
  }) : incidentId = _requiredText(incidentId, 'incidentId'),
       vehicleId = _requiredText(vehicleId, 'vehicleId'),
       routeId = _requiredText(routeId, 'routeId'),
       evaluatedAt = evaluatedAt.toUtc();

  final String incidentId;
  final String vehicleId;
  final String routeId;
  final VehicleCondition vehicleCondition;
  final OperatingPeriod operatingPeriod;
  final EvidenceDataClassification vehicleConditionDataClassification;
  final EvidenceDataClassification operatingPeriodDataClassification;
  final DateTime evaluatedAt;
}

String _requiredText(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
  return normalized;
}
