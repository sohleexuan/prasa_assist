class RecommendationConfidenceFactor {
  RecommendationConfidenceFactor({
    required String factorId,
    required String description,
    required this.weight,
    required this.isSupported,
  }) : factorId = _requiredConfidenceText(factorId, 'factorId'),
       description = _requiredConfidenceText(description, 'description') {
    _requireUnitValue(weight, 'weight');
  }

  final String factorId;
  final String description;
  final double weight;
  final bool isSupported;
}

class RecommendationConfidencePenalty {
  RecommendationConfidencePenalty({
    required String penaltyId,
    required String description,
    required this.amount,
  }) : penaltyId = _requiredConfidenceText(penaltyId, 'penaltyId'),
       description = _requiredConfidenceText(description, 'description') {
    _requireUnitValue(amount, 'amount');
  }

  final String penaltyId;
  final String description;
  final double amount;
}

class RecommendationConfidence {
  factory RecommendationConfidence({
    required List<RecommendationConfidenceFactor> factors,
    required List<RecommendationConfidencePenalty> penalties,
  }) {
    final factorCopy = List<RecommendationConfidenceFactor>.unmodifiable(
      factors,
    );
    final penaltyCopy = List<RecommendationConfidencePenalty>.unmodifiable(
      penalties,
    );
    _validateFactors(factorCopy);
    _validatePenalties(penaltyCopy);
    final total = factorCopy.fold<double>(0, (sum, item) => sum + item.weight);
    if (!total.isFinite || total <= 0) {
      throw ArgumentError.value(total, 'totalFactorWeight');
    }
    final supported = factorCopy
        .where((item) => item.isSupported)
        .fold<double>(0, (sum, item) => sum + item.weight);
    final base = (supported / total).clamp(0.0, 1.0).toDouble();
    final deductions = penaltyCopy.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    return RecommendationConfidence._(
      factors: factorCopy,
      penalties: penaltyCopy,
      baseConfidence: base,
      finalConfidence: (base - deductions).clamp(0.0, 1.0).toDouble(),
    );
  }

  const RecommendationConfidence._({
    required this.factors,
    required this.penalties,
    required this.baseConfidence,
    required this.finalConfidence,
  });

  final List<RecommendationConfidenceFactor> factors;
  final List<RecommendationConfidencePenalty> penalties;
  final double baseConfidence;
  final double finalConfidence;
}

void _validateFactors(List<RecommendationConfidenceFactor> values) {
  final ids = <String>{};
  for (final item in values) {
    if (!ids.add(item.factorId)) {
      throw ArgumentError.value(item, 'factors');
    }
  }
}

void _validatePenalties(List<RecommendationConfidencePenalty> values) {
  final ids = <String>{};
  for (final item in values) {
    if (!ids.add(item.penaltyId)) {
      throw ArgumentError.value(item, 'penalties');
    }
  }
}

String _requiredConfidenceText(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name);
  }
  return normalized;
}

void _requireUnitValue(double value, String name) {
  if (!value.isFinite || value < 0 || value > 1) {
    throw ArgumentError.value(value, name);
  }
}
