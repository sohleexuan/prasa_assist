import '../../models/deployment_status.dart';
import '../../models/service_deployment.dart';
import '../../repositories/deployment_data_exception.dart';

/// Staff-editable deployment values before Supabase confirms publication.
class LocalDeploymentDraft {
  LocalDeploymentDraft({
    required String routeId,
    required String routeName,
    required List<String> vehicleIds,
    required DateTime startTime,
    required DateTime endTime,
    required String purpose,
    String? incidentId,
    String? recommendationId,
  }) : routeId = routeId.trim(),
       routeName = routeName.trim(),
       vehicleIds = List<String>.unmodifiable(
         vehicleIds.map((vehicleId) => vehicleId.trim()),
       ),
       startTime = startTime.toUtc(),
       endTime = endTime.toUtc(),
       purpose = purpose.trim(),
       incidentId = incidentId?.trim(),
       recommendationId = recommendationId?.trim() {
    _validateWithDomainRules();
  }

  final String routeId;
  final String routeName;
  final List<String> vehicleIds;
  final DateTime startTime;
  final DateTime endTime;
  final String purpose;
  final String? incidentId;
  final String? recommendationId;

  void _validateWithDomainRules() {
    final validationProbe = ServiceDeployment(
      deploymentId: 'LOCAL-DRAFT',
      routeId: routeId,
      routeName: routeName,
      vehicleIds: vehicleIds,
      startTime: startTime,
      endTime: endTime,
      status: DeploymentStatus.draft,
      purpose: purpose,
      createdBy: 'LOCAL-OWNER',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      incidentId: incidentId,
      sourceRecommendationId: recommendationId,
    );
    final errors = validationProbe.validate();
    if (errors.isNotEmpty) {
      throw DeploymentValidationException(errors.join(' '));
    }
  }

  @override
  bool operator ==(Object other) {
    return other is LocalDeploymentDraft &&
        routeId == other.routeId &&
        routeName == other.routeName &&
        _listsEqual(vehicleIds, other.vehicleIds) &&
        startTime == other.startTime &&
        endTime == other.endTime &&
        purpose == other.purpose &&
        incidentId == other.incidentId &&
        recommendationId == other.recommendationId;
  }

  @override
  int get hashCode => Object.hash(
    routeId,
    routeName,
    Object.hashAll(vehicleIds),
    startTime,
    endTime,
    purpose,
    incidentId,
    recommendationId,
  );

  static bool _listsEqual(List<String> first, List<String> second) {
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }
    return true;
  }
}
