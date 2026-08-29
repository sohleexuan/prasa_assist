enum EvidenceDataClassification {
  liveGovernmentData,
  staticGovernmentData,
  cachedData,
  internalOperationalData,
  demonstrationData,
}

class RecommendationEvidence {
  RecommendationEvidence({
    required this.ruleId,
    required this.description,
    required this.dataClassification,
    required this.contribution,
  });

  final String ruleId;
  final String description;
  final EvidenceDataClassification dataClassification;
  final int contribution;
}
