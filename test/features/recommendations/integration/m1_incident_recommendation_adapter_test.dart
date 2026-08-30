import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/incidents/incident_module.dart'
    hide VehicleCondition;
import 'package:prasa_assist/features/recommendations/controllers/recommendation_controller.dart';
import 'package:prasa_assist/features/recommendations/data/dto/recommendation_record_dto.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_input.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_policy.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_status.dart';
import 'package:prasa_assist/features/recommendations/integration/m1_incident_recommendation_adapter.dart';
import 'package:prasa_assist/features/recommendations/pages/recommendation_list_page.dart';
import 'package:prasa_assist/features/recommendations/repositories/recommendation_repository.dart';
import 'package:prasa_assist/features/recommendations/services/deterministic_recommendation_rule_engine.dart';
import 'package:prasa_assist/features/recommendations/services/explainable_confidence_scorer.dart';
import 'package:prasa_assist/features/recommendations/services/incident_recommendation_submission_service.dart';
import 'package:prasa_assist/features/work_orders/controllers/work_orders_controller.dart';
import 'package:prasa_assist/features/work_orders/data/in_memory_work_order_repository.dart';

void main() {
  final adapter = M1IncidentRecommendationAdapter();
  final generatedAt = DateTime.utc(2026, 8, 30, 9);

  M1IncidentRecommendationFacts facts({
    String? vehicleId,
    String routeId = '300',
    IncidentType incidentType = IncidentType.vehicleBreakdown,
    IncidentDataSource dataSource = IncidentDataSource.mockDemonstration,
  }) => M1IncidentRecommendationFacts.fromIncident(
    IncidentDemoData.busB1023().copyWith(
      vehicleId: vehicleId,
      routeId: routeId,
      incidentType: incidentType,
      dataSource: dataSource,
    ),
    generatedAt: generatedAt,
  );

  IncidentRecommendationStaffConfirmation confirmed({
    OperatingPeriod operatingPeriod = OperatingPeriod.peak,
    bool breakdownConfirmedByStaff = true,
    bool operatingPeriodConfirmedByStaff = true,
  }) => IncidentRecommendationStaffConfirmation(
    breakdownConfirmedByStaff: breakdownConfirmedByStaff,
    operatingPeriod: operatingPeriod,
    operatingPeriodConfirmedByStaff: operatingPeriodConfirmedByStaff,
  );

  test('converts the confirmed B1023 Route 300 mock demonstration', () {
    final source = facts(vehicleId: 'B1023');

    final input = adapter.toVerifiedInput(
      facts: source,
      confirmation: confirmed(
        operatingPeriod: adapter.operatingPeriodPrefill(source)!,
      ),
      evaluatedAt: DateTime.utc(2026, 8, 30, 10),
    );

    expect(input.vehicleId, 'B1023');
    expect(input.routeId, '300');
    expect(input.vehicleCondition, VehicleCondition.breakdownConfirmed);
    expect(input.operatingPeriod, OperatingPeriod.peak);
    expect(input.vehicleConditionDataClassification.name, 'demonstrationData');
    expect(input.operatingPeriodDataClassification.name, 'demonstrationData');
  });

  test('rejects a missing vehicle ID', () {
    expect(
      () => adapter.toVerifiedInput(
        facts: facts(vehicleId: null),
        confirmation: confirmed(),
        evaluatedAt: generatedAt,
      ),
      throwsArgumentError,
    );
  });

  test('rejects a blank vehicle ID', () {
    expect(
      () => adapter.toVerifiedInput(
        facts: facts(vehicleId: '  '),
        confirmation: confirmed(),
        evaluatedAt: generatedAt,
      ),
      throwsArgumentError,
    );
  });

  test('rejects a breakdown that staff have not explicitly confirmed', () {
    expect(
      () => adapter.toVerifiedInput(
        facts: facts(vehicleId: 'B1023'),
        confirmation: confirmed(breakdownConfirmedByStaff: false),
        evaluatedAt: generatedAt,
      ),
      throwsStateError,
    );
  });

  test('rejects a non-breakdown incident even when staff confirms it', () {
    expect(
      () => adapter.toVerifiedInput(
        facts: facts(vehicleId: 'B1023', incidentType: IncidentType.accident),
        confirmation: confirmed(),
        evaluatedAt: generatedAt,
      ),
      throwsStateError,
    );
  });

  test('rejects an operating period staff have not explicitly confirmed', () {
    expect(
      () => adapter.toVerifiedInput(
        facts: facts(vehicleId: 'B1023'),
        confirmation: confirmed(operatingPeriodConfirmedByStaff: false),
        evaluatedAt: generatedAt,
      ),
      throwsStateError,
    );
  });

  test('does not offer the demo peak prefill to non-demo data', () {
    final source = facts(
      vehicleId: 'B1023',
      dataSource: IncidentDataSource.staffEntered,
    );

    expect(adapter.operatingPeriodPrefill(source), isNull);
    final input = adapter.toVerifiedInput(
      facts: source,
      confirmation: confirmed(),
      evaluatedAt: generatedAt,
    );
    expect(
      input.operatingPeriodDataClassification.name,
      'internalOperationalData',
    );
  });

  test(
    'does not offer demonstration classification to other vehicles/routes',
    () {
      for (final source in [
        facts(vehicleId: 'B2048'),
        facts(vehicleId: 'B1023', routeId: '301'),
      ]) {
        expect(adapter.operatingPeriodPrefill(source), isNull);
        final input = adapter.toVerifiedInput(
          facts: source,
          confirmation: confirmed(),
          evaluatedAt: generatedAt,
        );
        expect(
          input.operatingPeriodDataClassification.name,
          'internalOperationalData',
        );
      }
    },
  );

  test('conversion has zero create calls; submission is explicit and pending review', () async {
    final repository = _SpyRepository();
    final source = facts(vehicleId: 'B1023');
    final input = adapter.toVerifiedInput(
      facts: source,
      confirmation: confirmed(),
      evaluatedAt: generatedAt,
    );

    expect(repository.createCalls, 0);

    final created =
        await IncidentRecommendationSubmissionService(
          repository: repository,
          ruleEngine: DeterministicRecommendationRuleEngine(
            policy: RecommendationRulePolicy.ownerApproved(),
            confidenceScorer: const ExplainableConfidenceScorer(),
          ),
        ).submit(
          input: input,
          ownerUserId: '11111111-1111-4111-8111-111111111111',
          recommendationId: '22222222-2222-4222-8222-222222222222',
          createdAt: generatedAt,
        );

    expect(repository.createCalls, 1);
    expect(created?.recommendation.status, RecommendationStatus.pendingReview);
  });

  testWidgets(
    'recommendation page construction and loading do not create records',
    (tester) async {
      final repository = _SpyRepository();
      final controller = RecommendationController(repository);
      final workOrdersController = WorkOrdersController(
        InMemoryWorkOrderRepository(initialWorkOrders: []),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RecommendationListPage(
            controller: controller,
            workOrdersController: workOrdersController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.readAllCalls, 1);
      expect(repository.createCalls, 0);
    },
  );

  test('Module 1 does not import Module 4 recommendations', () {
    final moduleOneFiles = Directory('lib/features/incidents')
        .listSync(recursive: true)
        .whereType<File>();

    for (final file in moduleOneFiles) {
      expect(
        file.readAsStringSync(),
        isNot(contains('features/recommendations')),
        reason: file.path,
      );
    }
  });
}

class _SpyRepository implements RecommendationRepository {
  final records = <String, RecommendationRecordDto>{};
  var createCalls = 0;
  var readAllCalls = 0;

  @override
  Future<RecommendationRecordDto> createPending(
    RecommendationRecordDto record,
  ) async {
    createCalls++;
    records[record.recommendation.id] = record;
    return record;
  }

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

  @override
  Future<List<RecommendationRecordDto>> readAll() async {
    readAllCalls++;
    return records.values.toList(growable: false);
  }

  @override
  Future<RecommendationRecordDto?> readById(String id) async => records[id];
}
