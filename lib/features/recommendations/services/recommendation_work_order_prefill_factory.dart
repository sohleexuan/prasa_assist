import '../../work_orders/models/work_order.dart';
import '../../work_orders/models/work_order_prefill.dart';
import '../data/dto/recommendation_record_dto.dart';
import '../domain/recommendation_action.dart';
import '../domain/recommendation_status.dart';

class RecommendationWorkOrderPrefillFactory {
  const RecommendationWorkOrderPrefillFactory();

  WorkOrderPrefill create(RecommendationRecordDto record) {
    final recommendation = record.recommendation;
    if (recommendation.status != RecommendationStatus.accepted ||
        recommendation.actions
            .whereType<InspectOrRepairVehicleAction>()
            .isEmpty) {
      throw StateError(
        'Only an accepted inspection recommendation can be handed off.',
      );
    }
    final action = recommendation.actions
        .whereType<InspectOrRepairVehicleAction>()
        .first;
    return WorkOrderPrefill(
      incidentId: recommendation.incidentId,
      recommendationId: recommendation.id,
      routeId: recommendation.routeId,
      vehicleId: action.vehicleId,
      taskType: 'Vehicle inspection',
      description:
          'Inspect ${action.vehicleId} following the confirmed '
          'breakdown recommendation.',
      priority: WorkOrderPriority.high,
      notes:
          'Inspect or repair ${action.vehicleId} as directed by the accepted '
          'recommendation. Staff must verify the vehicle condition.',
    );
  }
}
