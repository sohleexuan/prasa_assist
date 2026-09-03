import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/recommendations/controllers/recommendation_controller.dart';
import 'package:prasa_assist/features/recommendations/data/dto/recommendation_record_dto.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_status.dart';
import 'package:prasa_assist/features/recommendations/models/recommendation_read_result.dart';
import 'package:prasa_assist/features/recommendations/pages/recommendation_list_page.dart';
import 'package:prasa_assist/features/recommendations/repositories/recommendation_hybrid_operations.dart';
import 'package:prasa_assist/features/recommendations/repositories/recommendation_repository.dart';

void main() {
  testWidgets('list identifies live Supabase recommendation data', (
    tester,
  ) async {
    final controller = RecommendationController(
      _Repository(
        RecommendationReadProvenance(
          source: RecommendationReadSource.liveSupabase,
          retrievedAtUtc: DateTime.utc(2026, 9, 4, 1, 30),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RecommendationListPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Live Supabase recommendation data'),
      findsOneWidget,
    );
    expect(find.textContaining('2026-09-04 09:30 MYT'), findsOneWidget);
  });

  testWidgets('list identifies cached SQLite data as not live', (tester) async {
    final controller = RecommendationController(
      _Repository(
        RecommendationReadProvenance(
          source: RecommendationReadSource.cachedSqlite,
          retrievedAtUtc: DateTime.utc(2026, 9, 3, 23, 45),
          warningMessage: 'Cached recommendation data is not live.',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RecommendationListPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Cached/offline SQLite recommendation data — not live',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('2026-09-04 07:45 MYT'), findsOneWidget);
  });
}

class _Repository
    implements RecommendationRepository, RecommendationHybridOperations {
  _Repository(this.provenance);

  final RecommendationReadProvenance provenance;

  @override
  Future<RecommendationReadResult<List<RecommendationRecordDto>>>
  readAllWithProvenance() async =>
      RecommendationReadResult(data: [_record()], provenance: provenance);

  @override
  Future<List<RecommendationRecordDto>> readAll() async => [_record()];

  @override
  Future<RecommendationRecordDto?> readById(String id) async => _record();

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
  }) => throw UnimplementedError();

  @override
  Future<RecommendationRecordDto> generateAnalysis(String id) async =>
      _record();
}

RecommendationRecordDto _record() => RecommendationRecordDto(
  recommendation: OperationsRecommendation(
    id: 'rec-1',
    ownerUserId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
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
    createdAt: DateTime.utc(2026, 9, 4),
  ),
);
