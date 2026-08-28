import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../models/incident_query.dart';

abstract class IncidentRepository {
  Future<List<Incident>> getAll({IncidentQuery? query});

  Future<Incident?> getById(String incidentId);

  Future<Incident> create(Incident incident);

  Future<Incident> update(Incident incident);

  Future<Incident> transitionStatus(
    String incidentId,
    IncidentStatus targetStatus, {
    required String changedBy,
    String? note,
  });

  Future<void> delete(String incidentId);
}
