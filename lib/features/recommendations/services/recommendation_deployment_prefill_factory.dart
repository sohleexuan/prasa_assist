import '../../deployments/models/deployment_prefill.dart';
import '../data/dto/recommendation_record_dto.dart';
import '../domain/recommendation_action.dart';
import '../domain/recommendation_status.dart';

class RecommendationDeploymentPrefillFactory {
  const RecommendationDeploymentPrefillFactory();

  DeploymentPrefill create(RecommendationRecordDto record) {
    final recommendation = record.recommendation;
    final replacementActions = recommendation.actions
        .whereType<DeployReplacementBusesAction>();
    if (recommendation.status != RecommendationStatus.accepted ||
        replacementActions.isEmpty) {
      throw StateError(
        'Only an accepted replacement-bus recommendation can be handed off.',
      );
    }
    final action = replacementActions.first;
    return DeploymentPrefill(
      incidentId: recommendation.incidentId,
      recommendationId: recommendation.id,
      routeId: action.routeId,
      suggestedVehicleCount: action.busCount,
      suggestedPurpose:
          'Provide ${action.busCount} replacement buses for Route '
          '${action.routeId}. Staff must review and save the draft.',
    );
  }
}
