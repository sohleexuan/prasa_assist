import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/data/incident_demo_data.dart';
import 'package:prasa_assist/features/incidents/integration/m1_incident_recommendation_facts.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';

void main() {
  final generatedAt = DateTime.utc(2026, 8, 30, 9, 15);

  group('M1IncidentRecommendationFacts', () {
    test('produces an immutable, versioned JSON schema', () {
      final facts = M1IncidentRecommendationFacts.fromIncident(
        IncidentDemoData.busB1023(),
        generatedAt: generatedAt,
      );
      final json = facts.toJson();

      expect(json['schema_version'], 1);
      expect(json['incident_id'], 'INC-20260828-001');
      expect(json['incident_time_utc'], '2026-08-27T23:55:00.000Z');
      expect(json['generated_at_utc'], '2026-08-30T09:15:00.000Z');
      expect(jsonEncode(json), isNotEmpty);
      expect(() => json['route_id'] = 'changed', throwsUnsupportedError);
    });

    test('contains only the approved hand-off fields', () {
      final json = M1IncidentRecommendationFacts.fromIncident(
        IncidentDemoData.busB1023(),
        generatedAt: generatedAt,
      ).toJson();

      expect(json.keys.toSet(), {
        'schema_version',
        'incident_id',
        'vehicle_id',
        'route_id',
        'incident_type',
        'severity',
        'status',
        'incident_time_utc',
        'vehicle_condition',
        'disruption_scope',
        'estimated_delay_minutes',
        'impact_level',
        'incident_data_classification',
        'delay_estimate_classification',
        'generated_at_utc',
      });
      expect(json, isNot(contains('title')));
      expect(json, isNot(contains('description')));
      expect(json, isNot(contains('reported_by')));
      expect(json, isNot(contains('location')));
      expect(json, isNot(contains('status_history')));
      expect(json, isNot(contains('automatic_action_allowed')));
    });

    test('does not depend on Module 4 implementation files', () {
      final source = File(
        'lib/features/incidents/integration/m1_incident_recommendation_facts.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('features/recommendations')));
      expect(source, isNot(contains('VerifiedIncidentRecommendationInput')));
    });

    test('keeps a missing vehicle ID null', () {
      final incident = IncidentDemoData.busB1023().copyWith(vehicleId: null);

      final facts = M1IncidentRecommendationFacts.fromIncident(
        incident,
        generatedAt: generatedAt,
      );

      expect(facts.vehicleId, isNull);
      expect(facts.toJson()['vehicle_id'], isNull);
    });

    test(
      'preserves facts classifications and marks delay as demonstration rule',
      () {
        final incident = IncidentDemoData.busB1023().copyWith(
          dataSource: IncidentDataSource.staffEntered,
          status: IncidentStatus.underReview,
        );

        final json = M1IncidentRecommendationFacts.fromIncident(
          incident,
          generatedAt: generatedAt,
        ).toJson();

        expect(json['incident_data_classification'], 'staff_entered');
        expect(json['delay_estimate_classification'], 'demonstration_rule');
        expect(json['incident_type'], 'vehicle_breakdown');
        expect(json['status'], 'under_review');
        expect(json['vehicle_condition'], 'immobilised');
        expect(json['disruption_scope'], 'partial_obstruction');
        expect(json['estimated_delay_minutes'], 75);
        expect(json['impact_level'], 'severe');
      },
    );
  });
}
