import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';

void main() {
  test('represents the two proposed actions for the B1023 scenario', () {
    final inspectAction = InspectOrRepairVehicleAction(vehicleId: 'B1023');
    final deployAction = DeployReplacementBusesAction(
      routeId: '300',
      busCount: 2,
    );

    expect(inspectAction.vehicleId, 'B1023');
    expect(deployAction.routeId, '300');
    expect(deployAction.busCount, 2);
  });
  test('replacement bus count must be positive', () {
    expect(
      () => DeployReplacementBusesAction(routeId: '300', busCount: 1),
      returnsNormally,
    );
    expect(
      () => DeployReplacementBusesAction(routeId: '300', busCount: 0),
      throwsArgumentError,
    );
    expect(
      () => DeployReplacementBusesAction(routeId: '300', busCount: -1),
      throwsArgumentError,
    );
  });
}
