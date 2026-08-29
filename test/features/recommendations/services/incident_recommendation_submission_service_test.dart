import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/data/dto/recommendation_record_dto.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_input.dart';
import 'package:prasa_assist/features/recommendations/repositories/recommendation_repository.dart';
import 'package:prasa_assist/features/recommendations/services/deterministic_recommendation_rule_engine.dart';
import 'package:prasa_assist/features/recommendations/services/explainable_confidence_scorer.dart';
import 'package:prasa_assist/features/recommendations/services/incident_recommendation_submission_service.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_policy.dart';
import 'package:prasa_assist/features/recommendations/domain/verified_incident_recommendation_input.dart';

void main() {
  test(
    'persists the deterministic B1023 peak recommendation without Gemini',
    () async {
      final repository = _Repository();
      final service = _service(repository);
      final result = await service.submit(
        input: _peakBreakdown('INC-B1023-300'),
        ownerUserId: _ownerUserId,
        recommendationId: _recommendationId,
        createdAt: DateTime.utc(2026, 8, 30, 1),
      );

      expect(result?.recommendation.status.name, 'pendingReview');
      expect(result?.recommendation.score, 85);
      expect(result?.recommendation.actions, hasLength(2));
      expect(
        result?.recommendation.actions
            .whereType<DeployReplacementBusesAction>()
            .single
            .busCount,
        2,
      );
      expect(repository.createCalls, 1);
      expect(repository.analysisCalls, 0);
    },
  );

  test('reuses the same caller UUID on retry without another create', () async {
    final repository = _Repository();
    final service = _service(repository);
    final first = await service.submit(
      input: _peakBreakdown('INC-RETRY-1'),
      ownerUserId: _ownerUserId,
      recommendationId: _retryRecommendationId,
      createdAt: DateTime.utc(2026, 8, 30, 2),
    );
    final retry = await service.submit(
      input: _peakBreakdown('INC-RETRY-1'),
      ownerUserId: _ownerUserId,
      recommendationId: _retryRecommendationId,
      createdAt: DateTime.utc(2026, 8, 30, 3),
    );

    expect(retry, same(first));
    expect(repository.createCalls, 1);
  });

  test(
    'returns the matching pending snapshot instead of creating a duplicate',
    () async {
      final repository = _Repository();
      final service = _service(repository);
      final existing = await service.submit(
        input: _peakBreakdown('INC-DEDUPE-1'),
        ownerUserId: _ownerUserId,
        recommendationId: _dedupeRecommendationId,
        createdAt: DateTime.utc(2026, 8, 30, 4),
      );
      final duplicate = await service.submit(
        input: _peakBreakdown('INC-DEDUPE-1'),
        ownerUserId: _ownerUserId,
        recommendationId: _otherRecommendationId,
        createdAt: DateTime.utc(2026, 8, 30, 5),
      );

      expect(duplicate, same(existing));
      expect(repository.createCalls, 1);
    },
  );

  test('does not persist facts that produce no deterministic action', () async {
    final repository = _Repository();
    final service = _service(repository);
    final result = await service.submit(
      input: VerifiedIncidentRecommendationInput(
        incidentId: 'INC-OPER-1',
        vehicleId: 'B1023',
        routeId: '300',
        vehicleCondition: VehicleCondition.operational,
        operatingPeriod: OperatingPeriod.peak,
        vehicleConditionDataClassification:
            EvidenceDataClassification.internalOperationalData,
        operatingPeriodDataClassification:
            EvidenceDataClassification.internalOperationalData,
        evaluatedAt: DateTime.utc(2026, 8, 30, 6),
      ),
      ownerUserId: _ownerUserId,
      recommendationId: '55555555-5555-4555-8555-555555555555',
      createdAt: DateTime.utc(2026, 8, 30, 6),
    );

    expect(result, isNull);
    expect(repository.createCalls, 0);
  });
}

IncidentRecommendationSubmissionService _service(_Repository repository) =>
    IncidentRecommendationSubmissionService(
      repository: repository,
      ruleEngine: DeterministicRecommendationRuleEngine(
        policy: RecommendationRulePolicy.ownerApproved(),
        confidenceScorer: const ExplainableConfidenceScorer(),
      ),
    );

class _Repository implements RecommendationRepository {
  final Map<String, RecommendationRecordDto> records = {};
  int createCalls = 0;
  int analysisCalls = 0;

  @override
  Future<RecommendationRecordDto> createPending(
    RecommendationRecordDto record,
  ) async {
    createCalls++;
    return records.putIfAbsent(record.recommendation.id, () => record);
  }

  @override
  Future<RecommendationRecordDto> decide(
    String id, {
    required String decision,
    String? note,
    required int expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<RecommendationRecordDto> generateAnalysis(String id) async {
    analysisCalls++;
    throw UnimplementedError();
  }

  @override
  Future<List<RecommendationRecordDto>> readAll() async => records.values
      .where((record) => record.recommendation.ownerUserId == _ownerUserId)
      .toList(growable: false);

  @override
  Future<RecommendationRecordDto?> readById(String id) async => records[id];
}

VerifiedIncidentRecommendationInput _peakBreakdown(String incidentId) =>
    VerifiedIncidentRecommendationInput(
      incidentId: incidentId,
      vehicleId: 'B1023',
      routeId: '300',
      vehicleCondition: VehicleCondition.breakdownConfirmed,
      operatingPeriod: OperatingPeriod.peak,
      vehicleConditionDataClassification:
          EvidenceDataClassification.internalOperationalData,
      operatingPeriodDataClassification:
          EvidenceDataClassification.demonstrationData,
      evaluatedAt: DateTime.utc(2026, 8, 30),
    );

const _ownerUserId = '11111111-1111-4111-8111-111111111111';
const _recommendationId = '22222222-2222-4222-8222-222222222222';
const _retryRecommendationId = '33333333-3333-4333-8333-333333333333';
const _dedupeRecommendationId = '44444444-4444-4444-8444-444444444444';
const _otherRecommendationId = '66666666-6666-4666-8666-666666666666';
