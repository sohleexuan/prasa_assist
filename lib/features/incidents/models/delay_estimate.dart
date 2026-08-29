import 'incident_enums.dart';

class DelayEstimate {
  DelayEstimate({
    required this.estimatedDelayMinutes,
    required this.impactLevel,
    required List<String> reasons,
  }) : reasons = List<String>.unmodifiable(reasons);

  final int estimatedDelayMinutes;
  final OperationalImpactLevel impactLevel;
  final List<String> reasons;

  List<String> validate() {
    final errors = <String>[];

    if (estimatedDelayMinutes < 5 || estimatedDelayMinutes > 120) {
      errors.add('Estimated delay must be between 5 and 120 minutes.');
    }
    if (reasons.isEmpty) {
      errors.add('At least one estimation reason is required.');
    }
    if (reasons.any((reason) => reason.trim().isEmpty)) {
      errors.add('Estimation reasons cannot be blank.');
    }

    return List<String>.unmodifiable(errors);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DelayEstimate &&
            estimatedDelayMinutes == other.estimatedDelayMinutes &&
            impactLevel == other.impactLevel &&
            _listsAreEqual(reasons, other.reasons);
  }

  @override
  int get hashCode =>
      Object.hash(estimatedDelayMinutes, impactLevel, Object.hashAll(reasons));

  static bool _listsAreEqual(List<String> first, List<String> second) {
    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }
    return true;
  }
}
