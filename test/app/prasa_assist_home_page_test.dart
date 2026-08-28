import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/app/module_registry.dart';
import 'package:prasa_assist/app/prasa_assist_app.dart';
import 'package:prasa_assist/core/auth/auth_gateway.dart';
import 'package:prasa_assist/core/dependencies/app_dependencies_scope.dart';
import 'package:prasa_assist/features/deployments/repositories/hybrid_deployment_repository.dart';
import 'package:prasa_assist/features/deployments/service_deployment_page.dart';
import 'package:prasa_assist/features/incidents/incident_module.dart';

import '../support/fake_auth_gateway.dart';
import '../support/test_dependencies.dart';

void main() {
  const moduleNames = [
    'Incident Management',
    'Maintenance Work Orders',
    'Service Deployment',
    'AI Recommendations',
  ];
  const placeholderModuleNames = [
    'Maintenance Work Orders',
    'AI Recommendations',
  ];

  testWidgets('home page renders foundation messaging and four modules', (
    tester,
  ) async {
    await _pumpAuthenticatedApp(tester);

    expect(find.text('Development foundation'), findsOneWidget);
    expect(find.text('AI recommends. Staff decides.'), findsOneWidget);

    for (final moduleName in moduleNames) {
      final moduleEntry = find.text(moduleName);
      await tester.scrollUntilVisible(
        moduleEntry,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(moduleEntry, findsOneWidget);
    }
  });

  testWidgets('navigates from Incident Management to the Module 1 workflow', (
    tester,
  ) async {
    await _pumpAuthenticatedApp(tester);

    final moduleEntry = find.text('Incident Management');
    await tester.scrollUntilVisible(
      moduleEntry,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(moduleEntry);
    await tester.pumpAndSettle();

    expect(find.byType(IncidentListPage), findsOneWidget);
    expect(find.text('Module integration pending'), findsNothing);
  });

  testWidgets('incident registry builder injects the signed-in staff label', (
    tester,
  ) async {
    final gateway = FakeAuthGateway(
      initialSession: const AuthSession(
        userId: '00000000-0000-4000-8000-000000000010',
        email: 'incident.staff@example.com',
      ),
    );
    addTearDown(gateway.dispose);
    IncidentListPage? builtPage;
    final destination = ModuleRegistry.destinations.singleWhere(
      (destination) => destination.id == 'incidents',
    );

    await tester.pumpWidget(
      AppDependenciesScope(
        dependencies: createTestDependencies(gateway),
        child: Builder(
          builder: (context) {
            builtPage = destination.pageBuilder(context) as IncidentListPage;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(builtPage, isNotNull);
    expect(builtPage!.repository, isA<HybridIncidentRepository>());
    expect(builtPage!.currentStaffId, 'incident.staff@example.com');
  });

  testWidgets('incident registry uses the auth UUID without an email', (
    tester,
  ) async {
    final gateway = FakeAuthGateway(
      initialSession: const AuthSession(
        userId: '00000000-0000-4000-8000-000000000011',
      ),
    );
    addTearDown(gateway.dispose);
    IncidentListPage? builtPage;
    final destination = ModuleRegistry.destinations.singleWhere(
      (destination) => destination.id == 'incidents',
    );

    await tester.pumpWidget(
      AppDependenciesScope(
        dependencies: createTestDependencies(gateway),
        child: Builder(
          builder: (context) {
            builtPage = destination.pageBuilder(context) as IncidentListPage;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(builtPage!.currentStaffId, '00000000-0000-4000-8000-000000000011');
  });

  for (final moduleName in placeholderModuleNames) {
    testWidgets('navigates from $moduleName to its placeholder', (
      tester,
    ) async {
      await _pumpAuthenticatedApp(tester);

      final moduleEntry = find.text(moduleName);
      await tester.scrollUntilVisible(
        moduleEntry,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(moduleEntry);
      await tester.pumpAndSettle();

      expect(find.text('Module integration pending'), findsOneWidget);
      expect(find.text('Not integrated'), findsOneWidget);
      expect(
        find.textContaining('$moduleName currently opens'),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'deployment registry builder injects Supabase persistence and auth label',
    (tester) async {
      final gateway = FakeAuthGateway(
        initialSession: const AuthSession(
          userId: '11111111-1111-4111-8111-111111111111',
          email: 'staff@example.com',
        ),
      );
      addTearDown(gateway.dispose);
      final dependencies = createTestDependencies(gateway);
      final destination = ModuleRegistry.destinations.singleWhere(
        (destination) => destination.id == 'deployments',
      );
      ServiceDeploymentPage? builtPage;

      await tester.pumpWidget(
        AppDependenciesScope(
          dependencies: dependencies,
          child: Builder(
            builder: (context) {
              builtPage =
                  destination.pageBuilder(context) as ServiceDeploymentPage;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(builtPage, isNotNull);
      expect(builtPage!.repository, isA<HybridDeploymentRepository>());
      expect(builtPage!.currentUserId, 'staff@example.com');
    },
  );

  testWidgets(
    'deployment registry uses stable auth UUID when no email is available',
    (tester) async {
      final gateway = FakeAuthGateway(
        initialSession: const AuthSession(
          userId: '22222222-2222-4222-8222-222222222222',
        ),
      );
      addTearDown(gateway.dispose);
      ServiceDeploymentPage? builtPage;
      final destination = ModuleRegistry.destinations.singleWhere(
        (destination) => destination.id == 'deployments',
      );

      await tester.pumpWidget(
        AppDependenciesScope(
          dependencies: createTestDependencies(gateway),
          child: Builder(
            builder: (context) {
              builtPage =
                  destination.pageBuilder(context) as ServiceDeploymentPage;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(builtPage!.currentUserId, '22222222-2222-4222-8222-222222222222');
    },
  );

  testWidgets('home page remains overflow-free at a small phone size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAuthenticatedApp(tester);
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('AI Recommendations'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('AI Recommendations'), findsOneWidget);
  });
}

Future<void> _pumpAuthenticatedApp(WidgetTester tester) async {
  final gateway = FakeAuthGateway(
    initialSession: const AuthSession(
      userId: '00000000-0000-4000-8000-000000000012',
    ),
  );
  addTearDown(gateway.dispose);
  await tester.pumpWidget(
    PrasaAssistApp(dependencies: createTestDependencies(gateway)),
  );
  await tester.pump();
}
