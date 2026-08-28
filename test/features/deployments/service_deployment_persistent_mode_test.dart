import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/models/deployment_status.dart';
import 'package:prasa_assist/features/deployments/models/route_catalog.dart';
import 'package:prasa_assist/features/deployments/models/service_deployment.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_repository_capabilities.dart';
import 'package:prasa_assist/features/deployments/repositories/in_memory_deployment_repository.dart';
import 'package:prasa_assist/features/deployments/repositories/route_catalog_repository.dart';
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

  testWidgets(
    'catalogue failure does not block persistent create, edit, or status flow',
    (tester) async {
      await _pumpPage(tester, repository: _PersistentModeRepository());

      expect(find.text('DEP-PERSIST'), findsOneWidget);
      await _tapByKey(tester, 'new-deployment-button');
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Manual or prefilled route entry remains available',
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('route-id-field')),
        '301',
      );
      await tester.enterText(
        find.byKey(const ValueKey('route-name-field')),
        'Manual persistent route',
      );
      await tester.enterText(
        find.byKey(const ValueKey('vehicle-ids-field')),
        'REPLACEMENT-BUS-03',
      );
      await tester.enterText(
        find.byKey(const ValueKey('purpose-field')),
        'Staff-confirmed persistent deployment',
      );
      await _tapByKey(tester, 'save-draft-button');
      await tester.pumpAndSettle();

      await _openDeploymentById(tester, 'DEP-CATALOG-FAIL');
      await tester.pumpAndSettle();
      await _tapByKey(tester, 'edit-deployment-button');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('route-name-field')),
        'Edited manual persistent route',
      );
      await _tapByKey(tester, 'save-changes-button');
      await tester.pumpAndSettle();

      expect(find.text('Edited manual persistent route'), findsOneWidget);
      await _tapByKey(tester, 'schedule-detail-button');
      expect(find.text('Schedule deployment?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-status-scheduled')));
      await tester.pumpAndSettle();

      expect(find.text('Scheduled'), findsWidgets);
    },
  );
}

Future<void> _openDeployment(WidgetTester tester) async {
  await _openDeploymentById(tester, 'DEP-PERSIST');
}

Future<void> _openDeploymentById(
  WidgetTester tester,
  String deploymentId,
) async {
  final card = find.byKey(ValueKey('deployment-card-$deploymentId'));
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
        routeCatalogRepository: _UnavailableRouteCatalogRepository(),
        currentUserId: 'staff@example.com',
        deploymentIdGenerator: (_) => 'DEP-CATALOG-FAIL',
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _tapByKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pump();
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
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

class _UnavailableRouteCatalogRepository implements RouteCatalogRepository {
  @override
  Future<RouteCatalogSnapshot> loadCatalog() {
    throw StateError('Route catalogue unavailable for test');
  }
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
