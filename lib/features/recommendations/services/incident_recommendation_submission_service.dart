import 'dart:convert';

import '../data/dto/recommendation_record_dto.dart';
import '../data/recommendation_serialization.dart';
import '../domain/recommendation_status.dart';
import '../domain/verified_incident_recommendation_input.dart';
import '../repositories/recommendation_repository.dart';
import 'deterministic_recommendation_rule_engine.dart';
import 'recommendation_generator.dart';

/// Creates deterministic pending-review recommendations from verified facts.
///
/// This service never invokes a provider. AI analysis remains a separate,
/// explanation-only operation after deterministic persistence.
class IncidentRecommendationSubmissionService {
  IncidentRecommendationSubmissionService({
    required this.repository,
    required this.ruleEngine,
    this.generator = const RecommendationGenerator(),
  });

  final RecommendationRepository repository;
  final DeterministicRecommendationRuleEngine ruleEngine;
  final RecommendationGenerator generator;

  /// Submits one verified incident snapshot using [recommendationId] as an
  /// idempotency key. A successful retry with the same ID reuses that record.
  Future<RecommendationRecordDto?> submit({
    required VerifiedIncidentRecommendationInput input,
    required String ownerUserId,
    required String recommendationId,
    required DateTime createdAt,
  }) async {
    final normalizedId = _uuid(recommendationId, 'recommendationId');
    final owner = _uuid(ownerUserId, 'ownerUserId');
    final existingById = await repository.readById(normalizedId);
    if (existingById != null) return existingById;

    final evaluation = ruleEngine.evaluate(input.toRuleInput());
    final generated = generator.generate(
      recommendationId: normalizedId,
      createdAt: createdAt.toUtc(),
      evaluation: evaluation,
    );
    if (generated == null) return null;
    final candidate = RecommendationRecordDto(
      recommendation: generated.copyWithOwner(owner),
    );
    final snapshot = _snapshot(candidate);
    for (final existing in await repository.readAll()) {
      final recommendation = existing.recommendation;
      if (recommendation.status == RecommendationStatus.pendingReview &&
          recommendation.incidentId == candidate.recommendation.incidentId &&
          _snapshot(existing) == snapshot) {
        return existing;
      }
    }
    return repository.createPending(candidate);
  }

  String _snapshot(RecommendationRecordDto record) => jsonEncode({
    'actions': RecommendationSerialization.encodeActions(
      record.recommendation.actions,
    ),
    'evidence': RecommendationSerialization.encodeEvidence(
      record.recommendation.evidence,
    ),
  });
}

String _uuid(String value, String name) {
  final normalized = value.trim();
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(normalized)) {
    throw ArgumentError.value(value, name, 'must be a UUID');
  }
  return normalized;
}
