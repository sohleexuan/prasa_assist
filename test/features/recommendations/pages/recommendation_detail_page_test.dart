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
import 'package:prasa_assist/features/recommendations/repositories/recommendation_repository.dart';
import 'package:prasa_assist/features/work_orders/controllers/work_orders_controller.dart';
import 'package:prasa_assist/features/work_orders/data/in_memory_work_order_repository.dart';

void main() {
  testWidgets(
    'accepted recommendation opens a new prefilled form only on CTA',
    (tester) async {
      final record = _acceptedRecord();
      final controller = RecommendationController(_FixedRepository(record));
      final workOrders = WorkOrdersController(
        InMemoryWorkOrderRepository(initialWorkOrders: []),
      );
      addTearDown(controller.dispose);
      addTearDown(workOrders.dispose);
      await controller.load();
      await workOrders.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RecommendationDetailPage(
            recommendationId: 'rec-1',
            controller: controller,
            workOrdersController: workOrders,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(workOrders.workOrders, isEmpty);
      expect(find.text('AI recommends. Staff decides.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('prepareWorkOrderButton')),
        300,
      );
      await tester.tap(find.byKey(const Key('prepareWorkOrderButton')));
      await tester.pumpAndSettle();

      expect(find.text('Create work order'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'B1023'), findsOneWidget);
      expect(workOrders.workOrders, isEmpty);
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
  Future<RecommendationRecordDto> decide(
    String id, {
    required String decision,
    String? note,
    required int expectedVersion,
  }) async => record;
}

RecommendationRecordDto _acceptedRecord() {
  final pending = OperationsRecommendation(
    id: 'rec-1',
    incidentId: 'INC-1',
    vehicleId: 'B1023',
    routeId: '300',
    actions: [InspectOrRepairVehicleAction(vehicleId: 'B1023')],
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
    recommendation: pending.decide(
      status: RecommendationStatus.accepted,
      decisionUserId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      decidedAt: DateTime.utc(2026, 8, 29, 1),
      remoteVersion: 2,
    ),
    analysis: RecommendationAnalysis(
      recommendationId: 'rec-1',
      modelIdentifier: 'gemini-2.5-flash',
      schemaVersion: 1,
      summary: 'Review B1023.',
      rationale: ['Confirmed breakdown.'],
      limitations: ['Staff review required.'],
      staffReviewChecklist: ['Review evidence.'],
      generatedAt: DateTime.utc(2026, 8, 29, 0, 30),
    ),
  );
}
