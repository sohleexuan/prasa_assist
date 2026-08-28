import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/data/incident_demo_data.dart';
import 'package:prasa_assist/features/incidents/integration/incident_operational_snapshot.dart';

void main() {
  group('IncidentOperationalSnapshot', () {
    test('maps the shared Bus B1023 scenario into a versioned contract', () {
      final snapshot = IncidentOperationalSnapshot.fromIncident(
        IncidentDemoData.busB1023(),
      );
      final json = snapshot.toJson();

      expect(json['schema_version'], 1);
      expect(json['incident_id'], 'INC-20260828-001');
      expect(json['incident_type'], 'vehicleBreakdown');
      expect(json['incident_type_label'], 'Vehicle Breakdown');
      expect(json['route_id'], '300');
      expect(json['vehicle_id'], 'B1023');
      expect(json['estimated_delay_minutes'], 75);
      expect(json['impact_level'], 'severe');
      expect(json['data_source'], 'mockDemonstration');
      expect(json['data_source_label'], 'Mock / Demonstration Data');
      expect(json['decision_support_only'], isTrue);
      expect(json['automatic_action_allowed'], isFalse);
    });

    test('uses JSON-safe UTC timestamps and preserves status history', () {
      final json = IncidentOperationalSnapshot.fromIncident(
        IncidentDemoData.busB1023(),
      ).toJson();
      final history = json['status_history']! as List<Map<String, Object?>>;

      expect(jsonEncode(json), isNotEmpty);
      expect(json['reported_at'], '2026-08-27T23:55:00.000Z');
      expect(history, hasLength(1));
      expect(history.single['from_status'], isNull);
      expect(history.single['to_status'], 'reported');
      expect(history.single['changed_by'], 'Demo Operations Staff');
    });

    test(
      'retains null optional service values as explicit contract fields',
      () {
        final incident = IncidentDemoData.busB1023().copyWith(
          routeName: null,
          vehicleId: null,
        );

        final json = IncidentOperationalSnapshot.fromIncident(incident)
            .toJson();

        expect(json, containsPair('route_name', null));
        expect(json, containsPair('vehicle_id', null));
      },
    );

    test('does not expose mutable lists through the snapshot or JSON map', () {
      final snapshot = IncidentOperationalSnapshot.fromIncident(
        IncidentDemoData.busB1023(),
      );
      final json = snapshot.toJson();

      expect(
        () => snapshot.estimationReasons.add('Unsupported mutation'),
        throwsUnsupportedError,
      );
      expect(() => snapshot.statusHistory.clear(), throwsUnsupportedError);
      expect(() => json['incident_id'] = 'changed', throwsUnsupportedError);
      expect(
        () => (json['estimation_reasons']! as List<String>).clear(),
        throwsUnsupportedError,
      );
    });

    test('creates deterministic output from an unchanged Incident', () {
      final incident = IncidentDemoData.busB1023();

      final first = IncidentOperationalSnapshot.fromIncident(incident).toJson();
      final second = IncidentOperationalSnapshot.fromIncident(incident)
          .toJson();

      expect(jsonEncode(first), jsonEncode(second));
    });
  });
}
