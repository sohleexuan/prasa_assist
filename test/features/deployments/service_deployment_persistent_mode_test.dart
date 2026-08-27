import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/models/deployment_status.dart';
import 'package:prasa_assist/features/deployments/models/service_deployment.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_repository_capabilities.dart';
import 'package:prasa_assist/features/deployments/repositories/in_memory_deployment_repository.dart';
import 'package:prasa_assist/features/deployments/service_deployment_page.dart';

void main() {
  testWidgets('persistent mode labels shared data and hides physical delete', (
    tester,
  ) async {
    await _pumpPage(tester, repository: _PersistentModeRepository());

    expect(find.text('Module 3 Shared Data'), findsOneWidget);
    expect(
      find.textContaining('Changes persist across sessions'),
      findsOneWidget,
    );
    expect(find.textContaining('Changes reset when'), findsNothing);

    await _openDeployment(tester);
    await tester.pumpAndSettle();

    expect(find.text('Authenticated shared deployment data'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('delete-deployment-button')),
      findsNothing,
    );
    expect(find.textContaining('Reset'), findsNothing);
  });

  testWidgets('prototype mode retains reset messaging and physical delete', (
    tester,
  ) async {
    await _pumpPage(tester, repository: _PrototypeModeRepository());

    expect(find.text('Module 3 Prototype'), findsOneWidget);
    expect(find.textContaining('Changes reset when'), findsOneWidget);

    await _openDeployment(tester);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('delete-deployment-button')),
      findsOneWidget,
    );
  });
}

Future<void> _openDeployment(WidgetTester tester) async {
  final card = find.byKey(const ValueKey('deployment-card-DEP-PERSIST'));
  await tester.scrollUntilVisible(
    card,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.tap(card);
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required InMemoryDeploymentRepository repository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ServiceDeploymentPage(
        repository: repository,
        currentUserId: 'staff@example.com',
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _PersistentModeRepository extends InMemoryDeploymentRepository {
  _PersistentModeRepository() : super(seedData: [_draftDeployment()]);

  @override
  DeploymentRepositoryCapabilities get capabilities =>
      const DeploymentRepositoryCapabilities.persistent();
}

class _PrototypeModeRepository extends InMemoryDeploymentRepository {
  _PrototypeModeRepository() : super(seedData: [_draftDeployment()]);
}

ServiceDeployment _draftDeployment() => ServiceDeployment(
  deploymentId: 'DEP-PERSIST',
  routeId: '300',
  routeName: 'Route 300',
  vehicleIds: const ['REPLACEMENT-BUS-01', 'REPLACEMENT-BUS-02'],
  startTime: DateTime.utc(2026, 8, 28, 8),
  endTime: DateTime.utc(2026, 8, 28, 10),
  status: DeploymentStatus.draft,
  purpose: 'Replace unavailable Bus B1023',
  createdBy: '00000000-0000-0000-0000-000000000001',
  createdAt: DateTime.utc(2026, 8, 28, 7, 45),
  updatedAt: DateTime.utc(2026, 8, 28, 7, 45),
);
