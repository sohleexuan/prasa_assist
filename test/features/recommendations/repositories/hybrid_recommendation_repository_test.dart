import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/data/dto/recommendation_record_dto.dart';
import 'package:prasa_assist/features/recommendations/data/sources/recommendation_local_data_source.dart';
import 'package:prasa_assist/features/recommendations/data/sources/recommendation_remote_data_source.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_analysis.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_status.dart';
import 'package:prasa_assist/features/recommendations/repositories/hybrid_recommendation_repository.dart';
import 'package:prasa_assist/features/recommendations/repositories/recommendation_data_exception.dart';

void main() {
  test('analysis failure allows one retry then immutable success', () async {
    final remote = _Remote(_record());
    final repository = HybridRecommendationRepository(
      remote: remote,
      local: _Local(),
      clock: () => DateTime.utc(2026, 8, 29),
    );
    remote.failAnalysis = true;
    await expectLater(
      repository.generateAnalysis('rec-1'),
      throwsA(isA<RecommendationOfflineException>()),
    );
    remote.failAnalysis = false;
    final saved = await repository.generateAnalysis('rec-1');
    expect(saved.analysis?.modelIdentifier, 'gemini-2.5-flash');
    await expectLater(
      repository.generateAnalysis('rec-1'),
      throwsA(isA<RecommendationValidationException>()),
    );
    expect(remote.analysisCalls, 2);
  });

  test(
    'decision forwards displayed version and preserves optional reject note',
    () async {
      final remote = _Remote(_record());
      final repository = HybridRecommendationRepository(
        remote: remote,
        local: _Local(),
      );
      final decided = await repository.decide(
        'rec-1',
        decision: 'rejected',
        expectedVersion: 1,
      );
      expect(remote.lastExpectedVersion, 1);
      expect(decided.recommendation.status, RecommendationStatus.rejected);
      expect(decided.recommendation.decisionNote, isNull);
    },
  );

  test(
    'caches a pending recommendation only after remote create succeeds',
    () async {
      final remote = _Remote(_record())..failCreate = true;
      final local = _Local();
      final repository = HybridRecommendationRepository(
        remote: remote,
        local: local,
        clock: () => DateTime.utc(2026, 8, 29),
      );

      await expectLater(
        repository.createPending(_record()),
        throwsA(isA<RecommendationOfflineException>()),
      );
      expect(local.records, isEmpty);

      remote.failCreate = false;
      final saved = await repository.createPending(_record());
      expect(saved.recommendation.id, 'rec-1');
      expect(local.records.single.recommendation.id, 'rec-1');
      expect(remote.createCalls, 2);
    },
  );
}

class _Remote implements RecommendationRemoteDataSource {
  _Remote(this.record);
  RecommendationRecordDto record;
  bool failAnalysis = false;
  bool failCreate = false;
  int analysisCalls = 0;
  int createCalls = 0;
  int? lastExpectedVersion;
  @override
  Future<List<RecommendationRecordDto>> fetchAll() async => [record];
  @override
  Future<RecommendationRecordDto?> fetchById(String id) async => record;

  @override
  Future<RecommendationRecordDto> createPending(
    RecommendationRecordDto record,
  ) async {
    createCalls++;
    if (failCreate) {
      throw const RecommendationOfflineException('Recommendation unavailable.');
    }
    this.record = record;
    return record;
  }

  @override
  Future<RecommendationRecordDto> generateAnalysis(String id) async {
    analysisCalls++;
    if (failAnalysis) {
      throw const RecommendationOfflineException('Analysis unavailable.');
    }
    record = _record(withAnalysis: true);
    return record;
  }

  @override
  Future<RecommendationRecordDto> decide(
    String id, {
    required String decision,
    String? note,
    required int expectedVersion,
  }) async {
    lastExpectedVersion = expectedVersion;
    final next = decision == 'accepted'
        ? RecommendationStatus.accepted
        : RecommendationStatus.rejected;
    record = RecommendationRecordDto(
      recommendation: record.recommendation.decide(
        status: next,
        decisionUserId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        decidedAt: DateTime.utc(2026, 8, 29, 2),
        decisionNote: note,
        remoteVersion: expectedVersion + 1,
      ),
      analysis: record.analysis,
    );
    return record;
  }
}

class _Local implements RecommendationLocalDataSource {
  List<RecommendationRecordDto> records = [];
  @override
  Future<List<RecommendationRecordDto>> readAll() async => records;
  @override
  Future<RecommendationRecordDto?> readById(String id) async =>
      records.where((item) => item.recommendation.id == id).firstOrNull;
  @override
  Future<void> replaceAll(
    Iterable<RecommendationRecordDto> records, {
    required DateTime retrievedAt,
  }) async {
    for (final record in records) {
      this.records.removeWhere(
        (item) => item.recommendation.id == record.recommendation.id,
      );
      this.records.add(record);
    }
  }
}

RecommendationRecordDto _record({bool withAnalysis = false}) {
  final recommendation = OperationsRecommendation(
    id: 'rec-1',
    ownerUserId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    incidentId: 'INC-1',
    vehicleId: 'B1023',
    routeId: '300',
    actions: [InspectOrRepairVehicleAction(vehicleId: 'B1023')],
    evidence: [
      RecommendationEvidence(
        ruleId: 'breakdown',
        description: 'Confirmed.',
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
    recommendation: recommendation,
    analysis: withAnalysis
        ? RecommendationAnalysis(
            recommendationId: 'rec-1',
            modelIdentifier: 'gemini-2.5-flash',
            schemaVersion: 1,
            summary: 'Review.',
            rationale: ['Confirmed breakdown.'],
            limitations: ['Staff review required.'],
            staffReviewChecklist: ['Review evidence.'],
            generatedAt: DateTime.utc(2026, 8, 29, 1),
          )
        : null,
  );
}
