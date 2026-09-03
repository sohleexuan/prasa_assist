import '../../models/incident.dart';
import '../../repositories/incident_data_exception.dart';
import '../../services/incident_validator.dart';

class LocalIncidentDraft {
  LocalIncidentDraft(this.incident) {
    final issues = IncidentValidator.validate(incident);
    if (issues.isNotEmpty) {
      throw IncidentValidationException(
        issues.map((issue) => issue.message).join(' '),
        issues: issues,
      );
    }
  }

  final Incident incident;
}
