sealed class RecommendationAction {
  const RecommendationAction();
}

class InspectOrRepairVehicleAction extends RecommendationAction {
  InspectOrRepairVehicleAction({required this.vehicleId});

  final String vehicleId;
}

class DeployReplacementBusesAction extends RecommendationAction {
  DeployReplacementBusesAction({
    required this.routeId,
    required this.busCount,
  }) {
    if (busCount <= 0) {
      throw ArgumentError.value(
        busCount,
        'busCount',
        'must be greater than zero',
      );
    }
  }

  final String routeId;
  final int busCount;
}
