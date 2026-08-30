import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_status.dart';

class OperationsRecommendation {
  OperationsRecommendation({
    required this.id,
    required this.incidentId,
    required this.vehicleId,
    required this.routeId,
    required List<RecommendationAction> actions,
    required List<RecommendationEvidence> evidence,
    required this.status,
    required this.score,
    required this.confidenceDetails,
    required DateTime createdAt,
    String? ownerUserId,
    String? decisionUserId,
    DateTime? decisionAt,
    String? decisionNote,
    this.remoteVersion = 1,
    DateTime? updatedAt,
  }) : actions = List<RecommendationAction>.unmodifiable(actions),
       evidence = List<RecommendationEvidence>.unmodifiable(evidence),
       ownerUserId = _optional(ownerUserId),
       decisionUserId = _optional(decisionUserId),
       decisionAt = decisionAt?.toUtc(),
       decisionNote = _optional(decisionNote),
       createdAt = createdAt.toUtc(),
       updatedAt = (updatedAt ?? createdAt).toUtc() {
    if (actions.isEmpty) {
      throw ArgumentError.value(
        actions,
        'actions',
        'must contain at least one proposed action',
      );
    }
    if (evidence.isEmpty) {
      throw ArgumentError.value(
        evidence,
        'evidence',
        'must contain at least one evidence item',
      );
    }
    if (score < 0 || score > 100) {
      throw ArgumentError.value(score, 'score', 'must be from 0 through 100');
    }
    _validateDecision();
  }

  OperationsRecommendation._decided({
    required OperationsRecommendation source,
    required this.status,
    required this.decisionUserId,
    required DateTime decidedAt,
    required this.decisionNote,
    required this.remoteVersion,
  }) : id = source.id,
       incidentId = source.incidentId,
       vehicleId = source.vehicleId,
       routeId = source.routeId,
       actions = source.actions,
       evidence = source.evidence,
       score = source.score,
       confidenceDetails = source.confidenceDetails,
       ownerUserId = source.ownerUserId,
       createdAt = source.createdAt,
       decisionAt = decidedAt,
       updatedAt = decidedAt;

  final String id;
  final String? incidentId;
  final String vehicleId;
  final String? routeId;
  final List<RecommendationAction> actions;
  final List<RecommendationEvidence> evidence;
  final RecommendationStatus status;
  final int score;
  final RecommendationConfidence confidenceDetails;

  double get confidence => confidenceDetails.finalConfidence;

  OperationsRecommendation copyWithOwner(String ownerUserId) =>
      OperationsRecommendation(
        id: id,
        incidentId: incidentId,
        vehicleId: vehicleId,
        routeId: routeId,
        actions: actions,
        evidence: evidence,
        status: status,
        score: score,
        confidenceDetails: confidenceDetails,
        createdAt: createdAt,
        ownerUserId: ownerUserId,
        decisionUserId: decisionUserId,
        decisionAt: decisionAt,
        decisionNote: decisionNote,
        remoteVersion: remoteVersion,
        updatedAt: updatedAt,
      );

  final DateTime createdAt;
  final String? ownerUserId;
  final String? decisionUserId;
  final DateTime? decisionAt;
  final String? decisionNote;
  final int remoteVersion;
  final DateTime updatedAt;

  OperationsRecommendation decide({
    required RecommendationStatus status,
    required String decisionUserId,
    required DateTime decidedAt,
    String? decisionNote,
    required int remoteVersion,
  }) {
    if (this.status != RecommendationStatus.pendingReview ||
        !{
          RecommendationStatus.accepted,
          RecommendationStatus.rejected,
        }.contains(status)) {
      throw StateError('Only pending recommendations can be decided.');
    }
    if (remoteVersion <= this.remoteVersion) {
      throw ArgumentError.value(remoteVersion, 'remoteVersion');
    }
    final actor = _optional(decisionUserId);
    if (actor == null) {
      throw ArgumentError.value(decisionUserId, 'decisionUserId');
    }
    return OperationsRecommendation._decided(
      source: this,
      status: status,
      decisionUserId: actor,
      decidedAt: decidedAt.toUtc(),
      decisionNote: _optional(decisionNote),
      remoteVersion: remoteVersion,
    );
  }

  void _validateDecision() {
    if (remoteVersion < 1 || updatedAt.isBefore(createdAt)) {
      throw ArgumentError('Invalid recommendation persistence metadata.');
    }
    final pending = status == RecommendationStatus.pendingReview;
    if (pending &&
        (decisionUserId != null ||
            decisionAt != null ||
            decisionNote != null)) {
      throw ArgumentError('Pending recommendations cannot have a decision.');
    }
    if (!pending &&
        status != RecommendationStatus.superseded &&
        (decisionUserId == null || decisionAt == null)) {
      throw ArgumentError('Decided recommendations require actor and time.');
    }
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
