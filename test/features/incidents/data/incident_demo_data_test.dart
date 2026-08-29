import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/data/incident_demo_data.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';
import 'package:prasa_assist/features/incidents/services/incident_validator.dart';

void main() {
  test(
    'provides a valid and clearly labelled Bus B1023 demonstration record',
    () {
      final incident = IncidentDemoData.busB1023();

      expect(incident.incidentId, 'INC-20260828-001');
      expect(incident.routeId, '300');
      expect(incident.vehicleId, 'B1023');
      expect(incident.dataSource, IncidentDataSource.mockDemonstration);
      expect(incident.estimatedDelayMinutes, 75);
      expect(incident.impactLevel, OperationalImpactLevel.severe);
      expect(incident.status, IncidentStatus.reported);
      expect(incident.statusHistory, hasLength(1));
      expect(
        IncidentValidator.validate(incident, now: DateTime(2026, 8, 28, 12)),
        isEmpty,
      );
    },
  );
}
