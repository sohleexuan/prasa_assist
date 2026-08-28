// Public integration surface for Module 1 — Incident Reporting and Delay
// Estimation.
//
// Shared application code should prefer this file over importing Module 1
// implementation details. Adding Module 1 to the shared registry still
// requires team approval.
export 'data/incident_demo_data.dart';
export 'data/sources/supabase_incident_remote_data_source.dart';
export 'integration/incident_operational_snapshot.dart';
export 'models/delay_estimate.dart';
export 'models/incident.dart';
export 'models/incident_enums.dart';
export 'models/incident_query.dart';
export 'models/incident_status_change.dart';
export 'pages/incident_list_page.dart';
export 'repositories/in_memory_incident_repository.dart';
export 'repositories/incident_data_exception.dart';
export 'repositories/incident_repository.dart';
export 'repositories/incident_repository_capabilities.dart';
export 'repositories/persistent_incident_repository.dart';
export 'services/delay_estimator.dart';
