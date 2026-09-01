import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/recommendations/controllers/recommendation_controller.dart';
import 'package:prasa_assist/features/recommendations/data/dto/recommendation_record_dto.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_analysis.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_status.dart';
import 'package:prasa_assist/features/recommendations/pages/recommendation_detail_page.dart';
import 'package:prasa_assist/features/recommendations/pages/recommendation_list_page.dart';
import 'package:prasa_assist/features/recommendations/repositories/recommendation_data_exception.dart';
import 'package:prasa_assist/features/recommendations/repositories/recommendation_repository.dart';
import 'package:prasa_assist/features/recommendations/widgets/recommendation_analysis_panel.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/models/work_order_prefill.dart';

void main() {
  testWidgets('analysis panel uses provider-neutral staff-decision wording', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RecommendationAnalysisPanel(
            analysis: null,
            loading: false,
            errorMessage: null,
            onRetry: null,
          ),
        ),
      ),
    );

    expect(
      find.text('AI explains stored deterministic facts only. Staff must decide.'),
      findsOneWidget,
    );
    expect(find.textContaining('Gemini'), findsNothing);
  });

  test('repeated analysis retry keeps only one request in flight', () async {
    final repository = _DelayedAnalysisRepository(
      _acceptedRecord(withAnalysis: false),
    );
    final controller = RecommendationController(repository);
    addTearDown(controller.dispose);
    await controller.load();

    final first = controller.generateAnalysis('rec-1');
    final repeated = controller.generateAnalysis('rec-1');

    expect(repository.analysisCalls, 1);
    repository.analysisCompleter.complete(_acceptedRecord());
    await Future.wait([first, repeated]);
    expect(controller.find('rec-1')?.analysis, isNotNull);
  });

  testWidgets(
    'analysis server failure stays in the panel without connection wording',
    (tester) async {
      const message =
          'The analysis service could not read or save recommendation data.';
      final controller = RecommendationController(
        _FailingAnalysisRepository(
          _acceptedRecord(withAnalysis: false),
          const RecommendationServerException(message),
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RecommendationDetailPage(
            recommendationId: 'rec-1',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final panel = find.byType(RecommendationAnalysisPanel);
      expect(
        find.descendant(of: panel, matching: find.text(message)),
        findsOneWidget,
      );
      expect(find.textContaining('Check the connection'), findsNothing);
      expect(find.text('Analysis unavailable'), findsOneWidget);
    },
  );

  testWidgets(
    'accepted maintenance recommendation sends existing prefill only on CTA',
    (tester) async {
      final record = _acceptedRecord();
      final controller = RecommendationController(_FixedRepository(record));
      addTearDown(controller.dispose);
      await controller.load();
      var callbackCalls = 0;
      WorkOrderPrefill? received;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RecommendationDetailPage(
            recommendationId: 'rec-1',
            controller: controller,
            onPrepareWorkOrder: (prefill) {
              callbackCalls++;
              received = prefill;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(callbackCalls, 0);
      expect(find.text('AI recommends. Staff decides.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('prepareWorkOrderButton')),
        300,
      );
      await tester.tap(find.byKey(const Key('prepareWorkOrderButton')));
      await tester.pump();

      expect(callbackCalls, 1);
      expect(received!.incidentId, 'INC-1');
      expect(received!.recommendationId, 'rec-1');
      expect(received!.vehicleId, 'B1023');
      expect(received!.taskType, 'Vehicle inspection');
      expect(
        received!.description,
        'Inspect B1023 following the confirmed breakdown recommendation.',
      );
      expect(received!.priority, WorkOrderPriority.high);
      expect(
        received!.notes,
        'AI-generated summary (review before saving): Review B1023.',
      );
      expect(find.byType(RecommendationDetailPage), findsOneWidget);
    },
  );

  testWidgets(
    'accepted replacement-bus recommendation sends deployment prefill only on CTA',
    (tester) async {
      final record = _acceptedRecord(
        actions: [
          InspectOrRepairVehicleAction(vehicleId: 'B1023'),
          DeployReplacementBusesAction(routeId: '300', busCount: 2),
        ],
      );
      final controller = RecommendationController(_FixedRepository(record));
      addTearDown(controller.dispose);
      await controller.load();

      var callbackCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RecommendationDetailPage(
            recommendationId: 'rec-1',
            controller: controller,
            onPrepareServiceDeployment: (prefill) {
              callbackCalls++;
              expect(prefill.incidentId, 'INC-1');
              expect(prefill.recommendationId, 'rec-1');
              expect(prefill.routeId, '300');
              expect(prefill.suggestedVehicleCount, 2);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('prepareServiceDeploymentButton')),
        300,
      );
      expect(
        find.byKey(const Key('prepareServiceDeploymentButton')),
        findsOneWidget,
      );
      expect(callbackCalls, 0);

      await tester.tap(find.byKey(const Key('prepareServiceDeploymentButton')));
      await tester.pump();

      expect(callbackCalls, 1);
    },
  );

  testWidgets('Work Order CTA keeps accepted maintenance visibility rules', (
    tester,
  ) async {
    final cases = <(RecommendationRecordDto, bool)>[
      (_pendingRecord(), false),
      (_rejectedRecord(), false),
      (
        _acceptedRecord(
          actions: [DeployReplacementBusesAction(routeId: '300', busCount: 2)],
        ),
        false,
      ),
      (_acceptedRecord(), true),
    ];

    for (final (record, visible) in cases) {
      final controller = RecommendationController(_FixedRepository(record));
      addTearDown(controller.dispose);
      await controller.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RecommendationDetailPage(
            recommendationId: 'rec-1',
            controller: controller,
            onPrepareWorkOrder: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (visible) {
        await tester.scrollUntilVisible(
          find.byKey(const Key('prepareWorkOrderButton')),
          300,
        );
      }
      expect(
        find.byKey(const Key('prepareWorkOrderButton')),
        visible ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('missing Work Order callback leaves a safe disabled CTA', (
    tester,
  ) async {
    final controller = RecommendationController(
      _FixedRepository(_acceptedRecord()),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RecommendationDetailPage(
          recommendationId: 'rec-1',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('prepareWorkOrderButton')),
      300,
    );

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('prepareWorkOrderButton')),
    );
    expect(button.onPressed, isNull);
    await tester.tap(find.byKey(const Key('prepareWorkOrderButton')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(RecommendationDetailPage), findsOneWidget);
  });

  testWidgets('list passes Work Order callback to detail', (tester) async {
    final controller = RecommendationController(
      _FixedRepository(_acceptedRecord()),
    );
    WorkOrderPrefill? received;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RecommendationListPage(
          controller: controller,
          onPrepareWorkOrder: (prefill) => received = prefill,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('B1023'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('prepareWorkOrderButton')),
      300,
    );
    await tester.tap(find.byKey(const Key('prepareWorkOrderButton')));
    await tester.pump();

    expect(received!.incidentId, 'INC-1');
    expect(received!.recommendationId, 'rec-1');
    expect(received!.vehicleId, 'B1023');

    await tester.pumpWidget(const SizedBox());
  });

  test('Module 4 has no Work Order navigation or persistence dependencies', () {
    final productionFiles = Directory('lib/features/recommendations')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in productionFiles) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('WorkOrderFormPage')), reason: file.path);
      expect(
        source,
        isNot(contains('SqliteDraftWorkOrderRepository')),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('/work_orders/controllers/')),
        reason: file.path,
      );
      expect(source, isNot(contains('/work_orders/data/')), reason: file.path);
    }
  });

  testWidgets(
    'hides service deployment CTA unless accepted with replacements',
    (tester) async {
      for (final record in [
        _pendingRecord(
          actions: [DeployReplacementBusesAction(routeId: '300', busCount: 2)],
        ),
        _rejectedRecord(
          actions: [DeployReplacementBusesAction(routeId: '300', busCount: 2)],
        ),
        _acceptedRecord(
          actions: [InspectOrRepairVehicleAction(vehicleId: 'B1023')],
        ),
      ]) {
        final controller = RecommendationController(_FixedRepository(record));
        addTearDown(controller.dispose);
        await controller.load();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: RecommendationDetailPage(
              recommendationId: 'rec-1',
              controller: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('prepareServiceDeploymentButton')),
          findsNothing,
        );
      }
    },
  );
}

class _FixedRepository implements RecommendationRepository {
  _FixedRepository(this.record);
  RecommendationRecordDto record;
  @override
  Future<List<RecommendationRecordDto>> readAll() async => [record];
  @override
  Future<RecommendationRecordDto?> readById(String id) async => record;
  @override
  Future<RecommendationRecordDto> generateAnalysis(String id) async => record;
  @override
  Future<RecommendationRecordDto> createPending(
    RecommendationRecordDto record,
  ) => throw UnimplementedError();

  @override
  Future<RecommendationRecordDto> decide(
    String id, {
    required String decision,
    String? note,
    required int expectedVersion,
  }) async => record;
}

RecommendationRecordDto _acceptedRecord({
  List<RecommendationAction>? actions,
  bool withAnalysis = true,
}) => RecommendationRecordDto(
  recommendation: _pendingRecord(actions: actions).recommendation.decide(
    status: RecommendationStatus.accepted,
    decisionUserId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    decidedAt: DateTime.utc(2026, 8, 29, 1),
    remoteVersion: 2,
  ),
  analysis: withAnalysis ? _analysis() : null,
);

class _FailingAnalysisRepository extends _FixedRepository {
  _FailingAnalysisRepository(super.record, this.failure);

  final RecommendationDataException failure;

  @override
  Future<RecommendationRecordDto> generateAnalysis(String id) =>
      Future.error(failure);
}

class _DelayedAnalysisRepository extends _FixedRepository {
  _DelayedAnalysisRepository(super.record);

  final analysisCompleter = Completer<RecommendationRecordDto>();
  var analysisCalls = 0;

  @override
  Future<RecommendationRecordDto> generateAnalysis(String id) {
    analysisCalls++;
    return analysisCompleter.future;
  }
}

RecommendationRecordDto _rejectedRecord({
  List<RecommendationAction>? actions,
}) => RecommendationRecordDto(
  recommendation: _pendingRecord(actions: actions).recommendation.decide(
    status: RecommendationStatus.rejected,
    decisionUserId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    decidedAt: DateTime.utc(2026, 8, 29, 1),
    remoteVersion: 2,
  ),
  analysis: _analysis(),
);

RecommendationRecordDto _pendingRecord({List<RecommendationAction>? actions}) {
  final pending = OperationsRecommendation(
    id: 'rec-1',
    incidentId: 'INC-1',
    vehicleId: 'B1023',
    routeId: '300',
    actions: actions ?? [InspectOrRepairVehicleAction(vehicleId: 'B1023')],
    evidence: [
      RecommendationEvidence(
        ruleId: 'breakdown',
        description: 'Confirmed breakdown.',
        dataClassification: EvidenceDataClassification.internalOperationalData,
        contribution: 50,
      ),
    ],
    status: RecommendationStatus.pendingReview,
    score: 50,
    confidenceDetails: RecommendationConfidence(
      factors: [
        RecommendationConfidenceFactor(
          factorId: 'breakdown',
          description: 'Confirmed.',
          weight: 1,
          isSupported: true,
        ),
      ],
      penalties: const [],
    ),
    createdAt: DateTime.utc(2026, 8, 29),
  );
  return RecommendationRecordDto(
    recommendation: pending,
    analysis: _analysis(),
  );
}

RecommendationAnalysis _analysis() => RecommendationAnalysis(
  recommendationId: 'rec-1',
  modelIdentifier: 'gemini-2.5-flash',
  schemaVersion: 1,
  summary: 'Review B1023.',
  rationale: ['Confirmed breakdown.'],
  limitations: ['Staff review required.'],
  staffReviewChecklist: ['Review evidence.'],
  generatedAt: DateTime.utc(2026, 8, 29, 0, 30),
);
