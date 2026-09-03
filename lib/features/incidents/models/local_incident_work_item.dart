import '../../../core/database/local_sync_state.dart';
import 'incident.dart';

class LocalIncidentWorkItem {
  const LocalIncidentWorkItem({
    required this.localId,
    required this.incident,
    required this.syncState,
    required this.localModifiedAtUtc,
    this.safeErrorMessage,
  });

  final String localId;
  final Incident incident;
  final LocalSyncState syncState;
  final DateTime localModifiedAtUtc;
  final String? safeErrorMessage;
}
