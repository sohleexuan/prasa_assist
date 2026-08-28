import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/data/incident_demo_data.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';
import 'package:prasa_assist/features/incidents/models/incident_query.dart';

void main() {
  group('IncidentQuery', () {
    test('provides user-facing sort labels', () {
      expect(
        IncidentSortOrder.newestReported.displayLabel,
        'Newest Reported First',
      );
      expect(
        IncidentSortOrder.longestEstimatedDelay.displayLabel,
        'Longest Estimated Delay First',
      );
    });

    test('copies filter sets into unmodifiable collections', () {
      final statuses = <IncidentStatus>{IncidentStatus.reported};
      final query = IncidentQuery(statuses: statuses);

      statuses.add(IncidentStatus.active);

      expect(query.statuses, {IncidentStatus.reported});
      expect(
        () => query.statuses.add(IncidentStatus.active),
        throwsUnsupportedError,
      );
    });

    test('matches all documented searchable Incident fields', () {
      final incident = IncidentDemoData.busB1023();
      final searches = [
        'inc-20260828',
        'b1023 breakdown',
        'immobilised during',
        '300',
        'route 300',
        'b1023',
        'demonstration location',
        'demo operations',
      ];

      for (final search in searches) {
        expect(
          IncidentQuery(searchTerm: search).matches(incident),
          isTrue,
          reason: '$search should match the demonstration incident',
        );
      }
    });

    test('search ignores case and surrounding whitespace', () {
      final incident = IncidentDemoData.busB1023();

      expect(
        IncidentQuery(searchTerm: '  bUs B1023  ').matches(incident),
        isTrue,
      );
    });

    test('combines filter dimensions with AND logic', () {
      final incident = IncidentDemoData.busB1023();

      expect(
        IncidentQuery(
          statuses: const {IncidentStatus.reported},
          severities: const {IncidentSeverity.high},
          incidentTypes: const {IncidentType.vehicleBreakdown},
        ).matches(incident),
        isTrue,
      );
      expect(
        IncidentQuery(
          statuses: const {IncidentStatus.reported},
          severities: const {IncidentSeverity.critical},
          incidentTypes: const {IncidentType.vehicleBreakdown},
        ).matches(incident),
        isFalse,
      );
    });
  });
}
