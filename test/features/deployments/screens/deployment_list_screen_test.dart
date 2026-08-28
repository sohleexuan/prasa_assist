import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/deployments/controllers/deployment_controller.dart';
import 'package:prasa_assist/features/deployments/models/deployment_status.dart';
import 'package:prasa_assist/features/deployments/models/service_deployment.dart';
import 'package:prasa_assist/features/deployments/repositories/in_memory_deployment_repository.dart';
import 'package:prasa_assist/features/deployments/screens/deployment_list_screen.dart';
import 'package:prasa_assist/features/deployments/widgets/deployment_card.dart';

void main() {
  testWidgets('shows loading state while the controller is loading', (
    tester,
  ) async {
    final repository = _DelayedRepository();
    await _pumpScreen(tester, repository: repository, finishLoading: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.complete([InMemoryDeploymentRepository.demonstrationDeployment]);
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('DEP-120'), findsOneWidget);
  });

  testWidgets('loads once and displays the DEP-120 demonstration record', (
    tester,
  ) async {
    final repository = _CountingRepository(
      seedData: [InMemoryDeploymentRepository.demonstrationDeployment],
    );

    await _pumpScreen(tester, repository: repository);

    expect(repository.getAllCallCount, 1);
    expect(find.text('Service Deployments'), findsOneWidget);
    expect(find.text('Module 3 Prototype'), findsOneWidget);
    expect(find.text('DEP-120'), findsOneWidget);
  });

  testWidgets('shows total, Scheduled, and Active counts', (tester) async {
    await _pumpScreen(tester, deployments: _filterDeployments());

    expect(_textAtKey(tester, 'deployment-total-count'), '3');
    expect(_textAtKey(tester, 'deployment-scheduled-count'), '1');
    expect(_textAtKey(tester, 'deployment-active-count'), '1');
  });

  testWidgets('sorts displayed deployments by earliest start time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpScreen(tester, deployments: _filterDeployments());

    final cards = tester
        .widgetList<DeploymentCard>(find.byType(DeploymentCard))
        .toList();
    expect(cards.first.deployment.deploymentId, 'DEP-ACTIVE');
    expect(cards[1].deployment.deploymentId, 'DEP-120');
  });

  testWidgets('searches case-insensitively by deployment ID', (tester) async {
    await _pumpScreen(tester, deployments: _filterDeployments());

    await _search(tester, 'dep-active');

    expect(_card('DEP-ACTIVE'), findsOneWidget);
    expect(_card('DEP-120'), findsNothing);
  });

  testWidgets('searches by route ID and route name', (tester) async {
    await _pumpScreen(tester, deployments: _filterDeployments());

    await _search(tester, '301');
    expect(_card('DEP-ACTIVE'), findsOneWidget);
    expect(_card('DEP-120'), findsNothing);

    await _search(tester, 'route 300');
    expect(_card('DEP-120'), findsOneWidget);
    expect(_card('DEP-ACTIVE'), findsNothing);
  });

  testWidgets('searches by vehicle ID', (tester) async {
    await _pumpScreen(tester, deployments: _filterDeployments());

    await _search(tester, 'active-bus');

    expect(_card('DEP-ACTIVE'), findsOneWidget);
    expect(_card('DEP-120'), findsNothing);
  });

  testWidgets('searches by incident ID', (tester) async {
    await _pumpScreen(tester, deployments: _filterDeployments());

    await _search(tester, 'inc-2026-0142');

    expect(_card('DEP-120'), findsOneWidget);
    expect(_card('DEP-ACTIVE'), findsNothing);
  });

  testWidgets('searches by recommendation ID', (tester) async {
    await _pumpScreen(tester, deployments: _filterDeployments());

    await _search(tester, 'rec-0088');

    expect(_card('DEP-120'), findsOneWidget);
    expect(_card('DEP-ACTIVE'), findsNothing);
  });

  testWidgets('filters deployments by status', (tester) async {
    await _pumpScreen(tester, deployments: _filterDeployments());

    await tester.tap(find.byKey(const ValueKey('status-filter-active')));
    await tester.pump();

    expect(_card('DEP-ACTIVE'), findsOneWidget);
    expect(_card('DEP-120'), findsNothing);
    expect(_card('DEP-COMPLETED'), findsNothing);
  });

  testWidgets('combines search and status filtering', (tester) async {
    await _pumpScreen(tester, deployments: _filterDeployments());

    await _search(tester, '301');
    await tester.tap(find.byKey(const ValueKey('status-filter-active')));
    await tester.pump();

    expect(_card('DEP-ACTIVE'), findsOneWidget);
    expect(find.byType(DeploymentCard), findsOneWidget);
  });

  testWidgets('shows a no-results state when filters match nothing', (
    tester,
  ) async {
    await _pumpScreen(tester, deployments: _filterDeployments());

    await _search(tester, 'not-a-real-deployment');

    expect(find.text('No deployments match your filters'), findsOneWidget);
    expect(find.byType(DeploymentCard), findsNothing);
  });

  testWidgets('clears active search and status filters', (tester) async {
    await _pumpScreen(tester, deployments: _filterDeployments());

    await _search(tester, 'not-a-real-deployment');
    final cancelledFilter = find.byKey(
      const ValueKey('status-filter-cancelled'),
    );
    await tester.ensureVisible(cancelledFilter);
    await tester.tap(cancelledFilter);
    await tester.pump();
    expect(find.text('No deployments match your filters'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clear-deployment-filters')));
    await tester.pump();

    final searchField = tester.widget<TextField>(
      find.byKey(const ValueKey('deployment-search-field')),
    );
    final allChip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('status-filter-all')),
    );
    expect(searchField.controller!.text, isEmpty);
    expect(allChip.selected, isTrue);
    expect(find.text('No deployments match your filters'), findsNothing);
    expect(find.byType(DeploymentCard), findsWidgets);
  });

  testWidgets('shows an empty repository state', (tester) async {
    await _pumpScreen(tester, deployments: const []);

    expect(find.text('No service deployments yet'), findsOneWidget);
    expect(find.byType(DeploymentCard), findsNothing);
  });

  testWidgets('shows repository and controller errors', (tester) async {
    await _pumpScreen(tester, repository: _AlwaysFailingRepository());

    expect(find.text('Unable to load deployments'), findsOneWidget);
    expect(find.text('Test repository failure'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Retry reloads repository data', (tester) async {
    final repository = _RetryRepository(
      seedData: [InMemoryDeploymentRepository.demonstrationDeployment],
    );
    await _pumpScreen(tester, repository: repository);
    expect(find.text('Unable to load deployments'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(repository.getAllCallCount, 2);
    expect(find.text('DEP-120'), findsOneWidget);
    expect(find.text('Unable to load deployments'), findsNothing);
  });

  testWidgets('invokes the New Deployment callback', (tester) async {
    var createCount = 0;
    await _pumpScreen(
      tester,
      deployments: [InMemoryDeploymentRepository.demonstrationDeployment],
      onCreateDeployment: () => createCount++,
    );

    await tester.tap(find.byKey(const ValueKey('new-deployment-button')));
    await tester.pump();

    expect(createCount, 1);
  });

  testWidgets('invokes the Open Deployment callback with selected data', (
    tester,
  ) async {
    ServiceDeployment? openedDeployment;
    final demonstration = InMemoryDeploymentRepository.demonstrationDeployment;
    await _pumpScreen(
      tester,
      deployments: [demonstration],
      onOpenDeployment: (deployment) => openedDeployment = deployment,
    );

    await tester.scrollUntilVisible(
      _card('DEP-120'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(_card('DEP-120'));
    await tester.pump();

    expect(openedDeployment, demonstration);
  });

  testWidgets('does not dispose its externally owned controller', (
    tester,
  ) async {
    final repository = InMemoryDeploymentRepository();
    final controller = DeploymentController(repository: repository);
    await _pumpScreen(tester, controller: controller);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    await controller.loadDeployments();
    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNull);
  });

  testWidgets('long content on a narrow screen does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpScreen(
      tester,
      deployments: [
        _deployment(
          deploymentId: 'DEP-WITH-A-VERY-LONG-IDENTIFIER',
          routeId: 'ROUTE-WITH-A-VERY-LONG-IDENTIFIER',
          routeName: 'Long replacement corridor name that needs several lines',
          vehicleIds: const [
            'VEHICLE-WITH-A-LONG-IDENTIFIER-001',
            'VEHICLE-WITH-A-LONG-IDENTIFIER-002',
          ],
          purpose:
              'A long operational purpose that must wrap safely while staff '
              'review deployment details on a narrow mobile device.',
        ),
      ],
    );

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<DeploymentController> _pumpScreen(
  WidgetTester tester, {
  Iterable<ServiceDeployment>? deployments,
  InMemoryDeploymentRepository? repository,
  DeploymentController? controller,
  VoidCallback? onCreateDeployment,
  ValueChanged<ServiceDeployment>? onOpenDeployment,
  bool finishLoading = true,
}) async {
  final effectiveRepository =
      repository ?? InMemoryDeploymentRepository(seedData: deployments ?? []);
  final effectiveController =
      controller ?? DeploymentController(repository: effectiveRepository);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: DeploymentListScreen(
        controller: effectiveController,
        onCreateDeployment: onCreateDeployment,
        onOpenDeployment: onOpenDeployment,
      ),
    ),
  );
  await tester.pump();
  if (finishLoading) {
    await tester.pump();
  }
  return effectiveController;
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(
    find.byKey(const ValueKey('deployment-search-field')),
    query,
  );
  await tester.pump();
}

Finder _card(String deploymentId) {
  return find.byKey(ValueKey('deployment-card-$deploymentId'));
}

String? _textAtKey(WidgetTester tester, String key) {
  return tester.widget<Text>(find.byKey(ValueKey(key))).data;
}

List<ServiceDeployment> _filterDeployments() {
  return [
    InMemoryDeploymentRepository.demonstrationDeployment,
    _deployment(
      deploymentId: 'DEP-ACTIVE',
      routeId: '301',
      routeName: 'Route 301 Crosstown',
      vehicleIds: const ['ACTIVE-BUS'],
      status: DeploymentStatus.active,
      startTime: DateTime(2026, 8, 27, 7),
      endTime: DateTime(2026, 8, 27, 9),
      incidentId: 'INC-ACTIVE',
      sourceRecommendationId: 'REC-ACTIVE',
    ),
    _deployment(
      deploymentId: 'DEP-COMPLETED',
      routeId: '302',
      routeName: 'Route 302',
      vehicleIds: const ['COMPLETED-BUS'],
      status: DeploymentStatus.completed,
      startTime: DateTime(2026, 8, 27, 11),
      endTime: DateTime(2026, 8, 27, 13),
      incidentId: null,
      sourceRecommendationId: null,
    ),
  ];
}

class _DelayedRepository extends InMemoryDeploymentRepository {
  final Completer<List<ServiceDeployment>> _completer =
      Completer<List<ServiceDeployment>>();

  @override
  Future<List<ServiceDeployment>> getAll() => _completer.future;

  void complete(List<ServiceDeployment> deployments) {
    _completer.complete(deployments);
  }
}

class _CountingRepository extends InMemoryDeploymentRepository {
  _CountingRepository({super.seedData});

  int getAllCallCount = 0;

  @override
  Future<List<ServiceDeployment>> getAll() {
    getAllCallCount++;
    return super.getAll();
  }
}

class _AlwaysFailingRepository extends InMemoryDeploymentRepository {
  @override
  Future<List<ServiceDeployment>> getAll() {
    throw StateError('Test repository failure');
  }
}

class _RetryRepository extends InMemoryDeploymentRepository {
  _RetryRepository({super.seedData});

  int getAllCallCount = 0;

  @override
  Future<List<ServiceDeployment>> getAll() {
    getAllCallCount++;
    if (getAllCallCount == 1) {
      throw StateError('Temporary repository failure');
    }
    return super.getAll();
  }
}

ServiceDeployment _deployment({
  required String deploymentId,
  required String routeId,
  required String routeName,
  required List<String> vehicleIds,
  DeploymentStatus status = DeploymentStatus.draft,
  DateTime? startTime,
  DateTime? endTime,
  String purpose = 'Provide replacement service',
  String? incidentId,
  String? sourceRecommendationId,
}) {
  return ServiceDeployment(
    deploymentId: deploymentId,
    routeId: routeId,
    routeName: routeName,
    vehicleIds: vehicleIds,
    startTime: startTime ?? DateTime(2026, 8, 27, 8),
    endTime: endTime ?? DateTime(2026, 8, 27, 10),
    status: status,
    purpose: purpose,
    createdBy: 'Operations Staff',
    createdAt: DateTime(2026, 8, 27, 6),
    updatedAt: DateTime(2026, 8, 27, 6, 30),
    incidentId: incidentId,
    sourceRecommendationId: sourceRecommendationId,
  );
}
