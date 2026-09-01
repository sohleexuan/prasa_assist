class RecommendationAnalysis {
  static const supportedModelIdentifiers = {
    'gemini-2.5-flash',
    'openai/gpt-oss-20b',
  };

  RecommendationAnalysis({
    required String recommendationId,
    required String modelIdentifier,
    required this.schemaVersion,
    required String summary,
    required List<String> rationale,
    required List<String> limitations,
    required List<String> staffReviewChecklist,
    required DateTime generatedAt,
  }) : recommendationId = _required(recommendationId, 'recommendationId'),
       modelIdentifier = _modelIdentifier(modelIdentifier),
       summary = _required(summary, 'summary'),
       rationale = _list(rationale, 'rationale'),
       limitations = _list(limitations, 'limitations'),
       staffReviewChecklist = _list(
         staffReviewChecklist,
         'staffReviewChecklist',
       ),
       generatedAt = generatedAt.toUtc() {
    if (schemaVersion < 1) throw FormatException('Invalid schemaVersion.');
  }

  factory RecommendationAnalysis.fromJson(
    Map<String, Object?> json, {
    required String recommendationId,
    required DateTime generatedAt,
    required String modelIdentifier,
    int schemaVersion = 1,
  }) {
    const keys = {
      'summary',
      'rationale',
      'limitations',
      'staffReviewChecklist',
    };
    if (json.keys.toSet().difference(keys).isNotEmpty ||
        keys.difference(json.keys.toSet()).isNotEmpty) {
      throw const FormatException('Analysis response has an invalid shape.');
    }
    return RecommendationAnalysis(
      recommendationId: recommendationId,
      modelIdentifier: modelIdentifier,
      schemaVersion: schemaVersion,
      summary: _string(json['summary'], 'summary'),
      rationale: _strings(json['rationale'], 'rationale'),
      limitations: _strings(json['limitations'], 'limitations'),
      staffReviewChecklist: _strings(
        json['staffReviewChecklist'],
        'staffReviewChecklist',
      ),
      generatedAt: generatedAt,
    );
  }

  final String recommendationId;
  final String modelIdentifier;
  final int schemaVersion;
  final String summary;
  final List<String> rationale;
  final List<String> limitations;
  final List<String> staffReviewChecklist;
  final DateTime generatedAt;

  static String _string(Object? value, String name) {
    if (value is! String) throw FormatException('$name must be text.');
    return _required(value, name);
  }

  static List<String> _strings(Object? value, String name) {
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('$name must be a text list.');
    }
    return value.cast<String>();
  }

  static String _required(String value, String name) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 1200) {
      throw FormatException('$name is blank or too long.');
    }
    return trimmed;
  }

  static String _modelIdentifier(String value) {
    final normalized = _required(value, 'modelIdentifier');
    if (!supportedModelIdentifiers.contains(normalized)) {
      throw const FormatException('Unsupported modelIdentifier.');
    }
    return normalized;
  }

  static List<String> _list(List<String> value, String name) {
    if (value.isEmpty || value.length > 8) {
      throw FormatException('$name must contain 1 to 8 items.');
    }
    return List.unmodifiable(value.map((item) => _required(item, name)));
  }
}
