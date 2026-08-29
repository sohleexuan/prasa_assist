import '../../models/incident.dart';
import '../../repositories/incident_data_exception.dart';
import '../../services/incident_validator.dart';

/// Staff-entered values retained locally until the staff member explicitly
/// chooses to submit them to Supabase.
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
