import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/incident_module.dart';

void main() {
  test(
    'public Module 1 API exposes its entry and integration contracts',
    () async {
      final repository = InMemoryIncidentRepository.withDemonstrationData(
        clock: () => DateTime(2026, 8, 28, 12),
      );
      final incidents = await repository.getAll();
      final snapshot = IncidentOperationalSnapshot.fromIncident(
        incidents.single,
      );
      const entry = IncidentListPage(currentStaffId: 'staff-api-test');

      expect(repository, isA<IncidentRepository>());
      expect(incidents.single, isA<Incident>());
      expect(snapshot.toJson()['schema_version'], 1);
      expect(entry.currentStaffId, 'staff-api-test');
      expect(const DelayEstimator(), isA<DelayEstimator>());
    },
  );
}
