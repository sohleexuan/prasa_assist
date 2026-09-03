import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/app/module_registry.dart';
import 'package:prasa_assist/app/prasa_assist_app.dart';
import 'package:prasa_assist/core/auth/auth_gateway.dart';
import 'package:prasa_assist/core/database/app_database.dart';
import 'package:prasa_assist/core/dependencies/app_dependencies.dart';
import 'package:prasa_assist/core/dependencies/app_dependencies_scope.dart';
import 'package:prasa_assist/features/deployments/models/deployment_prefill.dart';
import 'package:prasa_assist/features/deployments/repositories/hybrid_deployment_repository.dart';
import 'package:prasa_assist/features/deployments/screens/deployment_form_screen.dart';
import 'package:prasa_assist/features/deployments/service_deployment_page.dart';
import 'package:prasa_assist/features/incidents/incident_module.dart';
import 'package:prasa_assist/features/recommendations/data/dto/recommendation_record_dto.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_analysis.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_status.dart';
import 'package:prasa_assist/features/recommendations/pages/incident_recommendation_confirmation_page.dart';
import 'package:prasa_assist/features/recommendations/pages/recommendation_list_page.dart';
import 'package:prasa_assist/features/recommendations/repositories/recommendation_repository.dart';
import 'package:prasa_assist/features/recommendations/services/recommendation_work_order_prefill_factory.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/pages/work_order_form_page.dart';
import 'package:prasa_assist/features/work_orders/pages/work_order_list_page.dart';

import '../support/fake_auth_gateway.dart';
import '../support/test_dependencies.dart';

void main() {
  const moduleNames = [
    'Incident Management',
    'Maintenance Work Orders',
    'Service Deployment',
    'AI Recommendations',
  ];

  testWidgets(
    'home page renders integrated prototype messaging and four modules',
    (tester) async {
      await _pumpAuthenticatedApp(tester);

      expect(find.text('Integrated staff prototype'), findsOneWidget);
      expect(find.text('Integrated'), findsOneWidget);
      expect(
        find.textContaining('Module workflows are connected'),
        findsOneWidget,
      );
      expect(find.textContaining('will be connected'), findsNothing);
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
    },
  );

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

  testWidgets('incident registry never exposes the session email as a label', (
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
    expect(builtPage!.currentStaffId, 'Staff profile unavailable');
    expect(builtPage!.currentUserId, '00000000-0000-4000-8000-000000000010');
    expect(builtPage!.staffDirectoryRepository, isNotNull);
  });

  testWidgets('incident registry keeps the auth UUID internal', (tester) async {
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

    expect(builtPage!.currentStaffId, 'Staff profile unavailable');
    expect(builtPage!.currentUserId, '00000000-0000-4000-8000-000000000011');
  });

  testWidgets('normal Work Order destination uses production hybrid wiring', (
    tester,
  ) async {
    final gateway = FakeAuthGateway(
      initialSession: const AuthSession(
        userId: '44444444-4444-4444-8444-444444444444',
      ),
    );
    addTearDown(gateway.dispose);
    WorkOrderListPage? builtPage;
    final destination = ModuleRegistry.destinations.singleWhere(
      (destination) => destination.id == 'work-orders',
    );

    await tester.pumpWidget(
      AppDependenciesScope(
        dependencies: createTestDependencies(gateway),
        child: Builder(
          builder: (context) {
            builtPage = destination.pageBuilder(context) as WorkOrderListPage;
            return const SizedBox();
          },
        ),
      ),
    );

    final controller = builtPage!.controller;
    expect(controller.isHybrid, isTrue);
  });

  testWidgets(
    'Incident handoff opens confirmation without creating and submits one pending record',
    (tester) async {
      final gateway = FakeAuthGateway(
        initialSession: const AuthSession(
          userId: '55555555-5555-4555-8555-555555555555',
        ),
      );
      final repository = _CapturingRecommendationRepository();
      addTearDown(gateway.dispose);
      final facts = M1IncidentRecommendationFacts.fromIncident(
        IncidentDemoData.busB1023(),
        generatedAt: DateTime.utc(2026, 8, 31, 1),
      );
      IncidentListPage? incidentPage;

      await tester.pumpWidget(
        AppDependenciesScope(
          dependencies: createTestDependencies(gateway),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                incidentPage = ModuleRegistry.buildIncidentPage(
                  context,
                  recommendationRepository: repository,
                ) as IncidentListPage;
                return ElevatedButton(
                  onPressed: () => incidentPage!
                      .onPrepareIncidentRecommendation!
                      .call(facts),
                  child: const Text('Prepare selected incident'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Prepare selected incident'));
      await tester.pumpAndSettle();

      final confirmation = tester
          .widget<IncidentRecommendationConfirmationPage>(
            find.byType(IncidentRecommendationConfirmationPage),
          );
      expect(confirmation.facts, same(facts));
      expect(confirmation.ownerUserId, '55555555-5555-4555-8555-555555555555');
      expect(repository.createPendingCalls, 0);

      await tester.tap(
        find.byKey(const Key('breakdown-confirmation-checkbox')),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('operating-period-confirmation-checkbox')),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submit-incident-recommendation')));
      await tester.pump();
      await tester.pump();

      expect(repository.createPendingCalls, 1);
      final created = repository.created!.recommendation;
      expect(created.status, RecommendationStatus.pendingReview);
      expect(created.ownerUserId, '55555555-5555-4555-8555-555555555555');
      expect(created.incidentId, facts.incidentId);
      expect(created.routeId, facts.routeId);
      expect(created.vehicleId, facts.vehicleId);
      expect(find.byType(RecommendationListPage), findsOneWidget);
    },
  );

  testWidgets('navigates from AI Recommendations to the review workflow', (
    tester,
  ) async {
    await _pumpAuthenticatedApp(tester);
    final moduleEntry = find.text('AI Recommendations');
    await tester.scrollUntilVisible(
      moduleEntry,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(moduleEntry);
    await tester.pumpAndSettle();

    expect(find.byType(RecommendationListPage), findsOneWidget);
  });

  testWidgets(
    'recommendation destination reuses production hybrid Work Order wiring',
    (tester) async {
      final gateway = FakeAuthGateway(
        initialSession: const AuthSession(
          userId: '66666666-6666-4666-8666-666666666666',
        ),
      );
      addTearDown(gateway.dispose);
      RecommendationListPage? builtPage;
      final destination = ModuleRegistry.destinations.singleWhere(
        (destination) => destination.id == 'recommendations',
      );

      await tester.pumpWidget(
        AppDependenciesScope(
          dependencies: createTestDependencies(gateway),
          child: Builder(
            builder: (context) {
              builtPage =
                  destination.pageBuilder(context) as RecommendationListPage;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(builtPage!.workOrdersController, isNull);
      expect(builtPage!.onPrepareWorkOrder, isNotNull);
    },
  );

  testWidgets(
    'accepted maintenance handoff opens an unsaved linked form with production wiring',
    (tester) async {
      final gateway = FakeAuthGateway(
        initialSession: const AuthSession(
          userId: '77777777-7777-4777-8777-777777777777',
          email: 'maintenance.staff@example.com',
        ),
      );
      final database = _RecordingAppDatabase();
      addTearDown(gateway.dispose);
      addTearDown(database.close);
      final base = createTestDependencies(gateway);
      final dependencies = AppDependencies(
        supabaseClient: base.supabaseClient,
        authGateway: gateway,
        appDatabase: database,
      );
      RecommendationListPage? composition;
      final prefill = RecommendationWorkOrderPrefillFactory().create(
        _acceptedMaintenanceRecord(),
      );

      await tester.pumpWidget(
        AppDependenciesScope(
          dependencies: dependencies,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                composition =
                    ModuleRegistry.destinations
                            .singleWhere(
                              (destination) =>
                                  destination.id == 'recommendations',
                            )
                            .pageBuilder(context)
                        as RecommendationListPage;
                return ElevatedButton(
                  onPressed: () => composition!.onPrepareWorkOrder!(prefill),
                  child: const Text('Open work order prefill'),
                );
              },
            ),
          ),
        ),
      );
      expect(composition!.workOrdersController, isNull);
      expect(composition!.onPrepareWorkOrder, isNotNull);
      expect(database.insertCount, 0);
      await tester.tap(find.text('Open work order prefill'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkOrderFormPage), findsOneWidget);
      final form = tester.widget<WorkOrderFormPage>(
        find.byType(WorkOrderFormPage),
      );
      expect(form.controller.isHybrid, isTrue);
      expect(_fieldText(tester, 'vehicleIdField'), 'B1023');
      expect(_fieldText(tester, 'taskTypeField'), 'Vehicle inspection');
      expect(
        _fieldText(tester, 'descriptionField'),
        contains('confirmed breakdown recommendation'),
      );
      expect(form.prefill!.incidentId, 'INC-B1023-300');
      expect(form.prefill!.recommendationId, 'REC-B1023-300');
      expect(form.prefill!.routeId, '300');
      expect(form.prefill!.priority, WorkOrderPriority.high);
      expect(form.prefill!.notes, contains('Inspect or repair B1023'));
      expect(form.prefill!.notes, isNot(contains('replacement')));
      expect(database.insertCount, 0);

      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveWorkOrderButton')));
      await tester.pumpAndSettle();
      expect(database.insertCount, 1);
      expect(
        database.lastInsertValues,
        containsPair('owner_user_id', '77777777-7777-4777-8777-777777777777'),
      );
      expect(
        database.lastInsertValues,
        containsPair('incident_id', 'INC-B1023-300'),
      );
      expect(
        database.lastInsertValues,
        containsPair('recommendation_id', 'REC-B1023-300'),
      );
      expect(database.lastInsertValues, containsPair('route_id', '300'));
      expect(database.lastInsertValues, containsPair('vehicle_id', 'B1023'));
      expect(
        database.lastInsertValues,
        containsPair('task_type', 'Vehicle inspection'),
      );
      expect(database.lastInsertValues, containsPair('priority', 'high'));
      expect(
        database.lastInsertValues,
        containsPair('created_by_label', 'Staff profile unavailable'),
      );
      expect(
        database.lastInsertValues!['notes'],
        contains('Inspect or repair B1023'),
      );
    },
  );

  testWidgets(
    'recommendation callback opens an unsaved deployment create prefill',
    (tester) async {
      final gateway = FakeAuthGateway(
        initialSession: const AuthSession(
          userId: '33333333-3333-4333-8333-333333333333',
          email: 'deployment.staff@example.com',
        ),
      );
      final database = _RecordingAppDatabase();
      addTearDown(gateway.dispose);
      addTearDown(database.close);
      final dependencies = AppDependencies(
        supabaseClient: createTestDependencies(gateway).supabaseClient,
        authGateway: gateway,
        appDatabase: database,
      );
      const prefill = DeploymentPrefill(
        incidentId: 'INC-B1023-300',
        recommendationId: 'REC-B1023-300',
        routeId: '300',
        suggestedVehicleCount: 2,
        suggestedPurpose:
            'Provide 2 replacement buses for Route 300. '
            'Staff must review and save the draft.',
      );
      RecommendationListPage? recommendationPage;
      final destination = ModuleRegistry.destinations.singleWhere(
        (destination) => destination.id == 'recommendations',
      );

      await tester.pumpWidget(
        AppDependenciesScope(
          dependencies: dependencies,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                recommendationPage =
                    destination.pageBuilder(context) as RecommendationListPage;
                return ElevatedButton(
                  onPressed: () async {
                    await recommendationPage!.onPrepareServiceDeployment!(
                      prefill,
                    );
                  },
                  child: const Text('Open deployment prefill'),
                );
              },
            ),
          ),
        ),
      );
      expect(recommendationPage!.onPrepareServiceDeployment, isNotNull);
      await tester.tap(find.text('Open deployment prefill'));
      await tester.pumpAndSettle();

      final deploymentPage = tester.widget<ServiceDeploymentPage>(
        find.byType(ServiceDeploymentPage, skipOffstage: false),
      );
      expect(deploymentPage.repository, isA<HybridDeploymentRepository>());
      expect(deploymentPage.currentUserId, 'Staff profile unavailable');
      expect(deploymentPage.initialCreatePrefill, same(prefill));

      expect(find.byType(DeploymentFormScreen), findsOneWidget);
      expect(_fieldText(tester, 'incident-id-field'), 'INC-B1023-300');
      expect(_fieldText(tester, 'recommendation-id-field'), 'REC-B1023-300');
      expect(_fieldText(tester, 'route-id-field'), '300');
      expect(_fieldText(tester, 'purpose-field'), prefill.suggestedPurpose);
      expect(
        find.text(
          'Recommendation suggests 2 vehicles. '
          'Staff must select the actual vehicles.',
        ),
        findsOneWidget,
      );
      expect(_fieldText(tester, 'vehicle-ids-field'), isEmpty);
      expect(database.insertCount, 0);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'deployment registry injects persistence without exposing auth email',
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
      expect(builtPage!.currentUserId, 'Staff profile unavailable');
    },
  );

  testWidgets(
    'deployment registry does not expose auth UUID when email is unavailable',
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

      expect(builtPage!.currentUserId, 'Staff profile unavailable');
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

String _fieldText(WidgetTester tester, String key) {
  return tester
      .widget<TextFormField>(find.byKey(ValueKey(key)))
      .controller!
      .text;
}

class _RecordingAppDatabase implements AppDatabase {
  int insertCount = 0;
  Map<String, Object?>? lastInsertValues;

  @override
  bool get isOpen => true;

  @override
  bool get isClosed => false;

  @override
  Future<void> ensureOpen() async {}

  @override
  Future<void> close() async {}

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    dynamic conflictAlgorithm,
  }) async {
    insertCount++;
    lastInsertValues = Map<String, Object?>.from(values);
    return 1;
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(AppDatabaseTransaction transaction) action,
  ) {
    return action(_RecordingAppDatabaseTransaction(this));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingAppDatabaseTransaction implements AppDatabaseTransaction {
  _RecordingAppDatabaseTransaction(this.database);

  final _RecordingAppDatabase database;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async => const [];

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    dynamic conflictAlgorithm,
  }) async {
    database.insertCount++;
    database.lastInsertValues = Map<String, Object?>.from(values);
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CapturingRecommendationRepository implements RecommendationRepository {
  int createPendingCalls = 0;
  RecommendationRecordDto? created;

  @override
  Future<RecommendationRecordDto> createPending(
    RecommendationRecordDto record,
  ) async {
    createPendingCalls++;
    created = record;
    return record;
  }

  @override
  Future<List<RecommendationRecordDto>> readAll() async =>
      created == null ? const [] : [created!];

  @override
  Future<RecommendationRecordDto?> readById(String id) async => null;

  @override
  Future<RecommendationRecordDto> decide(
    String id, {
    required String decision,
    String? note,
    required int expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<RecommendationRecordDto> generateAnalysis(String id) =>
      throw UnimplementedError();
}

RecommendationRecordDto _acceptedMaintenanceRecord() {
  final pending = OperationsRecommendation(
    id: 'REC-B1023-300',
    incidentId: 'INC-B1023-300',
    vehicleId: 'B1023',
    routeId: '300',
    actions: [InspectOrRepairVehicleAction(vehicleId: 'B1023')],
    evidence: [
      RecommendationEvidence(
        ruleId: 'confirmed-breakdown',
        description: 'Confirmed B1023 breakdown.',
        dataClassification: EvidenceDataClassification.internalOperationalData,
        contribution: 50,
      ),
    ],
    status: RecommendationStatus.pendingReview,
    score: 50,
    confidenceDetails: RecommendationConfidence(
      factors: [
        RecommendationConfidenceFactor(
          factorId: 'confirmed-breakdown',
          description: 'Staff-confirmed breakdown.',
          weight: 1,
          isSupported: true,
        ),
      ],
      penalties: const [],
    ),
    createdAt: DateTime.utc(2026, 8, 31),
    ownerUserId: '77777777-7777-4777-8777-777777777777',
  );
  return RecommendationRecordDto(
    recommendation: pending.decide(
      status: RecommendationStatus.accepted,
      decisionUserId: '77777777-7777-4777-8777-777777777777',
      decidedAt: DateTime.utc(2026, 8, 31, 1),
      remoteVersion: 2,
    ),
    analysis: RecommendationAnalysis(
      recommendationId: 'REC-B1023-300',
      modelIdentifier: 'openai/gpt-oss-20b',
      schemaVersion: 1,
      summary: 'Inspect B1023 before returning it to service.',
      rationale: const ['Confirmed breakdown evidence.'],
      limitations: const ['Staff inspection is required.'],
      staffReviewChecklist: const ['Review the vehicle condition.'],
      generatedAt: DateTime.utc(2026, 8, 31, 0, 30),
    ),
  );
}
