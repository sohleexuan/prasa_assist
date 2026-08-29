import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/controllers/incident_state.dart';
import 'package:prasa_assist/features/incidents/data/incident_demo_data.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';
import 'package:prasa_assist/features/incidents/models/incident_query.dart';

void main() {
  group('IncidentState', () {
    test('starts with an initial empty state and default query', () {
      final state = IncidentState.initial();

      expect(state.status, IncidentStateStatus.initial);
      expect(state.incidents, isEmpty);
      expect(state.selectedIncident, isNull);
      expect(state.errorMessage, isNull);
      expect(state.isLoading, isFalse);
      expect(state.hasActiveQuery, isFalse);
      expect(state.query.sortOrder, IncidentSortOrder.newestReported);
    });

    test('keeps the incident list immutable', () {
      final incident = IncidentDemoData.busB1023();
      final incidents = [incident];
      final state = IncidentState(
        status: IncidentStateStatus.loaded,
        incidents: incidents,
        query: IncidentQuery(),
      );

      incidents.clear();

      expect(state.incidents, [incident]);
      expect(() => state.incidents.add(incident), throwsUnsupportedError);
    });

    test('detects search and filters but not sorting as active queries', () {
      expect(
        IncidentState(
          status: IncidentStateStatus.empty,
          incidents: const [],
          query: IncidentQuery(searchTerm: 'B1023'),
        ).hasActiveQuery,
        isTrue,
      );
      expect(
        IncidentState(
          status: IncidentStateStatus.empty,
          incidents: const [],
          query: IncidentQuery(statuses: const {IncidentStatus.active}),
        ).hasActiveQuery,
        isTrue,
      );
      expect(
        IncidentState(
          status: IncidentStateStatus.empty,
          incidents: const [],
          query: IncidentQuery(sortOrder: IncidentSortOrder.oldestReported),
        ).hasActiveQuery,
        isFalse,
      );
    });

    test('copyWith can explicitly clear selection and error', () {
      final state = IncidentState(
        status: IncidentStateStatus.error,
        incidents: const [],
        query: IncidentQuery(),
        selectedIncident: IncidentDemoData.busB1023(),
        errorMessage: 'Failure',
      );
      final copy = state.copyWith(selectedIncident: null, errorMessage: null);

      expect(copy.selectedIncident, isNull);
      expect(copy.errorMessage, isNull);
      expect(copy.status, IncidentStateStatus.error);
    });
  });
}
