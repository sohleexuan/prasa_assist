import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/deployments/models/deployment_status.dart';
import 'package:prasa_assist/features/deployments/models/service_deployment.dart';
import 'package:prasa_assist/features/deployments/widgets/deployment_card.dart';

void main() {
  testWidgets('shows all required deployment information', (tester) async {
    await _pumpCard(tester, _deployment());

    expect(find.text('DEP-120'), findsOneWidget);
    expect(find.text('Route 300'), findsOneWidget);
    expect(find.text('Route ID 300'), findsOneWidget);
    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.text('2 vehicles'), findsOneWidget);
    expect(find.text('ABC 1230, DEF 4567'), findsOneWidget);
    expect(find.text('2026-08-27 08:00 to 2026-08-27 10:00'), findsOneWidget);
    expect(
      find.text('Replace unavailable Bus B1023 during peak hour'),
      findsOneWidget,
    );
    expect(find.text('Incident INC-2026-0142'), findsOneWidget);
    expect(find.text('Recommendation REC-0088'), findsOneWidget);
    expect(find.textContaining('occupancy', findRichText: true), findsNothing);
    expect(
      find.textContaining('current load', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('uses singular wording for one vehicle', (tester) async {
    await _pumpCard(tester, _deployment(vehicleIds: const ['ABC 1230']));

    expect(find.text('1 vehicle'), findsOneWidget);
    expect(find.text('1 vehicles'), findsNothing);
  });

  testWidgets('omits optional integration IDs when absent', (tester) async {
    await _pumpCard(
      tester,
      _deployment(incidentId: null, sourceRecommendationId: null),
    );

    expect(find.textContaining('Incident '), findsNothing);
    expect(find.textContaining('Recommendation '), findsNothing);
  });

  testWidgets('invokes callback when the whole card is tapped', (tester) async {
    var tapCount = 0;
    await _pumpCard(tester, _deployment(), onTap: () => tapCount++);

    await tester.tap(find.byType(DeploymentCard));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets('wraps long content on a narrow screen without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpCard(
      tester,
      _deployment(
        routeName:
            'Route 300 replacement corridor with an intentionally long name',
        vehicleIds: const [
          'ABC 1230-LONG-IDENTIFIER',
          'DEF 4567-LONG-IDENTIFIER',
          'GHI 8901-LONG-IDENTIFIER',
        ],
        purpose:
            'Provide replacement service for an extended peak-hour disruption '
            'while operations staff assess vehicle availability and confirm '
            'the deployment plan.',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(DeploymentCard), findsOneWidget);
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  ServiceDeployment deployment, {
  VoidCallback? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: DeploymentCard(deployment: deployment, onTap: onTap),
        ),
      ),
    ),
  );
}

ServiceDeployment _deployment({
  String routeName = 'Route 300',
  List<String> vehicleIds = const ['ABC 1230', 'DEF 4567'],
  String purpose = 'Replace unavailable Bus B1023 during peak hour',
  String? incidentId = 'INC-2026-0142',
  String? sourceRecommendationId = 'REC-0088',
}) {
  return ServiceDeployment(
    deploymentId: 'DEP-120',
    routeId: '300',
    routeName: routeName,
    vehicleIds: vehicleIds,
    startTime: DateTime(2026, 8, 27, 8),
    endTime: DateTime(2026, 8, 27, 10),
    status: DeploymentStatus.scheduled,
    purpose: purpose,
    createdBy: 'Demo Operations Staff',
    createdAt: DateTime(2026, 8, 27, 7, 30),
    updatedAt: DateTime(2026, 8, 27, 7, 45),
    incidentId: incidentId,
    sourceRecommendationId: sourceRecommendationId,
  );
}
