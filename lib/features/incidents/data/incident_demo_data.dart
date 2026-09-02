import '../../../core/time/malaysia_time.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../models/incident_status_change.dart';
import '../services/delay_estimator.dart';

abstract final class IncidentDemoData {
  static Incident busB1023({
    DateTime? createdAt,
    DelayEstimator estimator = const DelayEstimator(),
  }) {
    final recordTime = createdAt?.toUtc() ?? DateTime.utc(2026, 8, 28);
    final reportedAt = DateTime.utc(2026, 8, 27, 23, 55);
    final estimate = estimator.estimate(
      incidentType: IncidentType.vehicleBreakdown,
      severity: IncidentSeverity.high,
      vehicleCondition: VehicleCondition.immobilised,
      disruptionScope: DisruptionScope.partialObstruction,
      reportedAt: MalaysiaTime.instantToWallClock(reportedAt),
    );

    return Incident(
      incidentId: 'INC-20260828-001',
      incidentType: IncidentType.vehicleBreakdown,
      title: 'Bus B1023 breakdown',
      description:
          'Bus B1023 became immobilised during the Route 300 peak-hour '
          'demonstration scenario.',
      routeId: '300',
      routeName: 'Route 300',
      vehicleId: 'B1023',
      location: 'Route 300 demonstration location',
      reportedAt: reportedAt,
      severity: IncidentSeverity.high,
      status: IncidentStatus.reported,
      vehicleCondition: VehicleCondition.immobilised,
      disruptionScope: DisruptionScope.partialObstruction,
      delayEstimate: estimate,
      reportedBy: 'Demo Operations Staff',
      dataSource: IncidentDataSource.mockDemonstration,
      createdAt: recordTime,
      updatedAt: recordTime,
      statusHistory: [
        IncidentStatusChange(
          fromStatus: null,
          toStatus: IncidentStatus.reported,
          changedAt: recordTime,
          changedBy: 'Demo Operations Staff',
          note: 'Mock incident for the shared demonstration scenario.',
        ),
      ],
    );
  }
}
