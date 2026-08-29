import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';
import 'package:prasa_assist/features/incidents/models/incident_status_change.dart';

void main() {
  group('IncidentStatusChange', () {
    test('accepts a valid initial Reported entry', () {
      expect(_initialChange().validate(), isEmpty);
    });

    test('accepts an agreed status transition', () {
      final change = IncidentStatusChange(
        fromStatus: IncidentStatus.reported,
        toStatus: IncidentStatus.underReview,
        changedAt: DateTime(2026, 8, 28, 8, 10),
        changedBy: 'Control Centre Staff',
        note: 'Review started.',
      );

      expect(change.validate(), isEmpty);
    });

    test('requires an initial entry to use Reported', () {
      final change = IncidentStatusChange(
        fromStatus: null,
        toStatus: IncidentStatus.active,
        changedAt: DateTime(2026, 8, 28, 8),
        changedBy: 'Operations Staff',
      );

      expect(
        change.validate(),
        contains('The initial status must be Reported.'),
      );
    });

    test('rejects an invalid status transition', () {
      final change = IncidentStatusChange(
        fromStatus: IncidentStatus.reported,
        toStatus: IncidentStatus.resolved,
        changedAt: DateTime(2026, 8, 28, 8, 10),
        changedBy: 'Operations Staff',
      );

      expect(
        change.validate(),
        contains('Reported cannot transition to Resolved.'),
      );
    });

    test('requires an operator and rejects a blank optional note', () {
      final change = IncidentStatusChange(
        fromStatus: IncidentStatus.reported,
        toStatus: IncidentStatus.cancelled,
        changedAt: DateTime(2026, 8, 28, 8, 10),
        changedBy: ' ',
        note: ' ',
      );

      expect(
        change.validate(),
        contains('Status change operator is required.'),
      );
      expect(
        change.validate(),
        contains('Status change note cannot be blank when provided.'),
      );
    });

    test('implements value equality and matching hash codes', () {
      final first = _initialChange();
      final equalChange = _initialChange();
      final differentChange = IncidentStatusChange(
        fromStatus: null,
        toStatus: IncidentStatus.reported,
        changedAt: first.changedAt,
        changedBy: 'Different Staff',
      );

      expect(equalChange, first);
      expect(equalChange.hashCode, first.hashCode);
      expect(differentChange, isNot(first));
    });
  });
}

IncidentStatusChange _initialChange() {
  return IncidentStatusChange(
    fromStatus: null,
    toStatus: IncidentStatus.reported,
    changedAt: DateTime(2026, 8, 28, 8),
    changedBy: 'Operations Staff',
  );
}
