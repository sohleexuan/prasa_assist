import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/controllers/incident_controller.dart';
import 'package:prasa_assist/features/incidents/data/incident_demo_data.dart';
import 'package:prasa_assist/features/incidents/models/incident.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';
import 'package:prasa_assist/features/incidents/models/incident_query.dart';
import 'package:prasa_assist/features/incidents/pages/incident_detail_page.dart';
import 'package:prasa_assist/features/incidents/repositories/incident_repository.dart';
import 'package:prasa_assist/features/incidents/repositories/incident_repository_capabilities.dart';

void main() {
  testWidgets(
    'persistent detail labels shared data and hides physical delete',
    (tester) async {
      final incident = IncidentDemoData.busB1023();
      final controller = IncidentController(
        repository: _PersistentFakeRepository(incident),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: IncidentDetailPage(
            controller: controller,
            incidentId: incident.incidentId,
            currentStaffId: 'staff@example.com',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shared Incident Data'), findsOneWidget);
      expect(find.text('Persistent / Shared Data'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Audit record retained'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Audit record retained'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('delete-incident-button')),
        findsNothing,
      );
    },
  );
}

class _PersistentFakeRepository
    implements IncidentRepository, IncidentRepositoryCapabilitiesProvider {
  _PersistentFakeRepository(this.incident);

  Incident incident;

  @override
  IncidentRepositoryCapabilities get capabilities =>
      const IncidentRepositoryCapabilities.persistent();

  @override
  Future<Incident> create(Incident incident) async => incident;

  @override
  Future<void> delete(String incidentId) async {
    throw UnsupportedError('Physical delete is unavailable.');
  }

  @override
  Future<List<Incident>> getAll({IncidentQuery? query}) async => [incident];

  @override
  Future<Incident?> getById(String incidentId) async => incident;

  @override
  Future<Incident> transitionStatus(
    String incidentId,
    IncidentStatus targetStatus, {
    required String changedBy,
    String? note,
  }) async => incident;

  @override
  Future<Incident> update(Incident incident) async => incident;
}
