import 'dart:convert';

import '../../domain/recommendation.dart';
import '../../domain/recommendation_analysis.dart';
import '../../domain/recommendation_status.dart';
import '../recommendation_serialization.dart';

class RecommendationRecordDto {
  const RecommendationRecordDto({required this.recommendation, this.analysis});

  final OperationsRecommendation recommendation;
  final RecommendationAnalysis? analysis;

  factory RecommendationRecordDto.fromMap(Map<String, dynamic> map) {
    final id = _text(map, 'id', fallback: 'recommendation_id');
    final status = switch (_text(map, 'status')) {
      'pending_review' => RecommendationStatus.pendingReview,
      'accepted' => RecommendationStatus.accepted,
      'rejected' => RecommendationStatus.rejected,
      _ => throw const FormatException('Unknown recommendation status.'),
    };
    final analysisValue = map['recommendation_analyses'];
    final analysisMap = analysisValue is List && analysisValue.isNotEmpty
        ? _map(analysisValue.single)
        : analysisValue is Map
        ? _map(analysisValue)
        : null;
    return RecommendationRecordDto(
      recommendation: OperationsRecommendation(
        id: id,
        ownerUserId: _text(map, 'owner_user_id'),
        incidentId: _optional(map, 'incident_id'),
        vehicleId: _text(map, 'vehicle_id'),
        routeId: _optional(map, 'route_id'),
        actions: RecommendationSerialization.decodeActions(
          _json(map['actions_snapshot'] ?? map['actions_json']),
        ),
        evidence: RecommendationSerialization.decodeEvidence(
          _json(map['evidence_snapshot'] ?? map['evidence_json']),
        ),
        score: _integer(map, 'score'),
        confidenceDetails: RecommendationSerialization.decodeConfidence(
          _json(map['confidence_details'] ?? map['confidence_details_json']),
        ),
        status: status,
        decisionUserId: _optional(map, 'decision_user_id'),
        decisionAt: _date(map['decision_at'] ?? map['decision_at_utc']),
        decisionNote: _optional(map, 'decision_note'),
        remoteVersion: _integer(map, 'version', fallback: 'remote_version'),
        createdAt: _date(map['created_at'] ?? map['created_at_utc'])!,
        updatedAt: _date(map['updated_at'] ?? map['updated_at_utc'])!,
      ),
      analysis: analysisMap == null
          ? null
          : RecommendationAnalysis(
              recommendationId: id,
              modelIdentifier: _text(analysisMap, 'model_identifier'),
              schemaVersion: _integer(analysisMap, 'schema_version'),
              summary: _text(analysisMap, 'summary'),
              rationale: _stringList(
                analysisMap['rationale'] ?? analysisMap['rationale_json'],
              ),
              limitations: _stringList(
                analysisMap['limitations'] ?? analysisMap['limitations_json'],
              ),
              staffReviewChecklist: _stringList(
                analysisMap['staff_review_checklist'] ??
                    analysisMap['checklist_json'],
              ),
              generatedAt: _date(
                analysisMap['generated_at'] ?? analysisMap['generated_at_utc'],
              )!,
            ),
    );
  }

  Map<String, Object?> toLocalRow({required DateTime retrievedAt}) => {
    'recommendation_id': recommendation.id,
    'owner_user_id': recommendation.ownerUserId,
    'incident_id': recommendation.incidentId,
    'vehicle_id': recommendation.vehicleId,
    'route_id': recommendation.routeId,
    'actions_json': jsonEncode(
      RecommendationSerialization.encodeActions(recommendation.actions),
    ),
    'evidence_json': jsonEncode(
      RecommendationSerialization.encodeEvidence(recommendation.evidence),
    ),
    'score': recommendation.score,
    'confidence_details_json': jsonEncode(
      RecommendationSerialization.encodeConfidence(
        recommendation.confidenceDetails,
      ),
    ),
    'status': _status(recommendation.status),
    'decision_user_id': recommendation.decisionUserId,
    'decision_at_utc': recommendation.decisionAt?.toIso8601String(),
    'decision_note': recommendation.decisionNote,
    'remote_version': recommendation.remoteVersion,
    'sync_state': 'cached_remote',
    'created_at_utc': recommendation.createdAt.toIso8601String(),
    'updated_at_utc': recommendation.updatedAt.toIso8601String(),
    'retrieved_at_utc': retrievedAt.toUtc().toIso8601String(),
    'safe_error_message': null,
  };

  Map<String, Object?>? toLocalAnalysisRow() => analysis == null
      ? null
      : {
          'recommendation_id': recommendation.id,
          'owner_user_id': recommendation.ownerUserId,
          'model_identifier': analysis!.modelIdentifier,
          'schema_version': analysis!.schemaVersion,
          'summary': analysis!.summary,
          'rationale_json': jsonEncode(analysis!.rationale),
          'limitations_json': jsonEncode(analysis!.limitations),
          'checklist_json': jsonEncode(analysis!.staffReviewChecklist),
          'generated_at_utc': analysis!.generatedAt.toIso8601String(),
        };
}

String _status(RecommendationStatus value) => switch (value) {
  RecommendationStatus.pendingReview => 'pending_review',
  RecommendationStatus.accepted => 'accepted',
  RecommendationStatus.rejected => 'rejected',
  RecommendationStatus.superseded => throw const FormatException(
    'Superseded recommendations are not persisted by this workflow.',
  ),
};

Map<String, dynamic> _map(Object value) =>
    (value as Map).map((key, item) => MapEntry(key.toString(), item));
String _text(Map<String, dynamic> map, String key, {String? fallback}) {
  final value = map[key] ?? (fallback == null ? null : map[fallback]);
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key.');
  }
  return value.trim();
}

String? _optional(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key.');
  }
  return value.trim();
}

int _integer(Map<String, dynamic> map, String key, {String? fallback}) {
  final value = map[key] ?? (fallback == null ? null : map[fallback]);
  if (value is! int) throw FormatException('Invalid $key.');
  return value;
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  if (value is String) return DateTime.parse(value).toUtc();
  throw const FormatException('Invalid timestamp.');
}

String _json(Object? value) => value is String ? value : jsonEncode(value);
List<String> _stringList(Object? value) {
  final decoded = value is String ? jsonDecode(value) : value;
  if (decoded is! List || decoded.any((item) => item is! String)) {
    throw const FormatException('Invalid analysis list.');
  }
  return decoded.cast<String>();
}
