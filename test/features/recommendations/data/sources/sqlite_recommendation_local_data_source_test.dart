import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/local_user_scope.dart';
import 'package:prasa_assist/features/recommendations/data/dto/recommendation_record_dto.dart';
import 'package:prasa_assist/features/recommendations/data/sources/sqlite_recommendation_local_data_source.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_analysis.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_status.dart';

import '../../../../support/sqlite_test_database.dart';

void main() {
  test(
    'round trips UTC/version/analysis and isolates reads by owner',
    () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      const ownerA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      const ownerB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
      final sourceA = SqliteRecommendationLocalDataSource(
        database: database,
        userScope: LocalUserScope(ownerA),
      );
      final sourceB = SqliteRecommendationLocalDataSource(
        database: database,
        userScope: LocalUserScope(ownerB),
      );
      await sourceA.replaceAll([
        _record(ownerA),
      ], retrievedAt: DateTime.utc(2026, 8, 29, 10));

      final cached = (await sourceA.readAll()).single;
      expect(cached.recommendation.remoteVersion, 3);
      expect(cached.recommendation.createdAt.isUtc, isTrue);
      expect(cached.analysis?.generatedAt.isUtc, isTrue);
      expect(cached.analysis?.summary, 'Review the confirmed breakdown.');
      expect(
        await sourceA.readOldestRetrievedAtUtc(),
        DateTime.utc(2026, 8, 29, 10),
      );
      expect(await sourceB.readAll(), isEmpty);
      expect(await sourceB.readOldestRetrievedAtUtc(), isNull);
    },
  );
}

RecommendationRecordDto _record(String owner) => RecommendationRecordDto(
  recommendation: OperationsRecommendation(
    id: 'rec-1',
    ownerUserId: owner,
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
    remoteVersion: 3,
    createdAt: DateTime(2026, 8, 29, 8),
    updatedAt: DateTime(2026, 8, 29, 9),
  ),
  analysis: RecommendationAnalysis(
    recommendationId: 'rec-1',
    modelIdentifier: 'openai/gpt-oss-20b',
    schemaVersion: 1,
    summary: 'Review the confirmed breakdown.',
    rationale: ['Stored evidence supports inspection.'],
    limitations: ['Staff verification is required.'],
    staffReviewChecklist: ['Review vehicle status.'],
    generatedAt: DateTime(2026, 8, 29, 8, 30),
  ),
);
