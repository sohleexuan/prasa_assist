class RecommendationRulePolicy {
  RecommendationRulePolicy({
    required this.confirmedBreakdownContribution,
    required this.peakBreakdownContribution,
    required this.replacementBusCount,
    required this.breakdownConfidenceWeight,
    required this.operatingPeriodConfidenceWeight,
    required this.demonstrationEvidencePenalty,
  }) {
    _requireContribution(
      confirmedBreakdownContribution,
      'confirmedBreakdownContribution',
    );
    _requireContribution(
      peakBreakdownContribution,
      'peakBreakdownContribution',
    );
    if (replacementBusCount <= 0) {
      throw ArgumentError.value(replacementBusCount, 'replacementBusCount');
    }
    _requireWeight(breakdownConfidenceWeight, 'breakdownConfidenceWeight');
    _requireWeight(
      operatingPeriodConfidenceWeight,
      'operatingPeriodConfidenceWeight',
    );
    final total = breakdownConfidenceWeight + operatingPeriodConfidenceWeight;
    if (!total.isFinite || total <= 0) {
      throw ArgumentError.value(total, 'totalConfidenceWeight');
    }
    if (!demonstrationEvidencePenalty.isFinite ||
        demonstrationEvidencePenalty < 0 ||
        demonstrationEvidencePenalty > 1) {
      throw ArgumentError.value(
        demonstrationEvidencePenalty,
        'demonstrationEvidencePenalty',
      );
    }
  }

  factory RecommendationRulePolicy.ownerApproved() => RecommendationRulePolicy(
    confirmedBreakdownContribution: 50,
    peakBreakdownContribution: 35,
    replacementBusCount: 2,
    breakdownConfidenceWeight: 0.60,
    operatingPeriodConfidenceWeight: 0.40,
    demonstrationEvidencePenalty: 0.15,
  );

  final int confirmedBreakdownContribution;
  final int peakBreakdownContribution;
  final int replacementBusCount;
  final double breakdownConfidenceWeight;
  final double operatingPeriodConfidenceWeight;
  final double demonstrationEvidencePenalty;
}

void _requireContribution(int value, String name) {
  if (value < 0 || value > 100) {
    throw ArgumentError.value(value, name);
  }
}

void _requireWeight(double value, String name) {
  if (!value.isFinite || value < 0 || value > 1) {
    throw ArgumentError.value(value, name);
  }
}
