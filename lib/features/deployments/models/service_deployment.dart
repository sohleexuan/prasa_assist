import 'deployment_status.dart';

class ServiceDeployment {
  ServiceDeployment({
    required this.deploymentId,
    required this.routeId,
    required this.routeName,
    required List<String> vehicleIds,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.purpose,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.incidentId,
    this.sourceRecommendationId,
  }) : _vehicleIds = List<String>.unmodifiable(vehicleIds);

  static const Object _notProvided = Object();

  final String deploymentId;
  final String routeId;
  final String routeName;
  final List<String> _vehicleIds;
  final DateTime startTime;
  final DateTime endTime;
  final DeploymentStatus status;
  final String purpose;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final String? incidentId;
  final String? sourceRecommendationId;

  List<String> get vehicleIds => _vehicleIds;

  int get vehicleCount => _vehicleIds.length;

  List<String> validate() {
    final errors = <String>[];
    final normalizedVehicleIds = _vehicleIds
        .map((vehicleId) => vehicleId.trim())
        .toList(growable: false);

    if (deploymentId.trim().isEmpty) {
      errors.add('Deployment ID is required.');
    }
    if (routeId.trim().isEmpty) {
      errors.add('Route ID is required.');
    }
    if (routeName.trim().isEmpty) {
      errors.add('Route name is required.');
    }
    if (_vehicleIds.isEmpty) {
      errors.add('At least one vehicle must be selected.');
    }
    if (normalizedVehicleIds.any((vehicleId) => vehicleId.isEmpty)) {
      errors.add('Vehicle IDs cannot be empty.');
    }
    if (normalizedVehicleIds.map((id) => id.toLowerCase()).toSet().length !=
        normalizedVehicleIds.length) {
      errors.add('Vehicle IDs cannot contain duplicates.');
    }
    if (normalizedVehicleIds.any((id) => id.toLowerCase() == 'b1023')) {
      errors.add('Unavailable Bus B1023 cannot be a replacement vehicle.');
    }
    if (!endTime.isAfter(startTime)) {
      errors.add('End time must be after start time.');
    }
    if (purpose.trim().isEmpty) {
      errors.add('Purpose is required.');
    }
    if (createdBy.trim().isEmpty) {
      errors.add('Created by is required.');
    }
    if (updatedAt.isBefore(createdAt)) {
      errors.add('Updated time cannot be earlier than created time.');
    }
    if (version < 1) {
      errors.add('Version must be at least 1.');
    }
    if (incidentId != null && incidentId!.trim().isEmpty) {
      errors.add('Incident ID cannot be blank when provided.');
    }
    if (sourceRecommendationId != null &&
        sourceRecommendationId!.trim().isEmpty) {
      errors.add('Source recommendation ID cannot be blank when provided.');
    }

    return List<String>.unmodifiable(errors);
  }

  ServiceDeployment copyWith({
    String? deploymentId,
    String? routeId,
    String? routeName,
    List<String>? vehicleIds,
    DateTime? startTime,
    DateTime? endTime,
    DeploymentStatus? status,
    String? purpose,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    Object? incidentId = _notProvided,
    Object? sourceRecommendationId = _notProvided,
  }) {
    return ServiceDeployment(
      deploymentId: deploymentId ?? this.deploymentId,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      vehicleIds: vehicleIds ?? _vehicleIds,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      purpose: purpose ?? this.purpose,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      incidentId: identical(incidentId, _notProvided)
          ? this.incidentId
          : incidentId as String?,
      sourceRecommendationId: identical(sourceRecommendationId, _notProvided)
          ? this.sourceRecommendationId
          : sourceRecommendationId as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ServiceDeployment &&
            deploymentId == other.deploymentId &&
            routeId == other.routeId &&
            routeName == other.routeName &&
            _listsAreEqual(_vehicleIds, other._vehicleIds) &&
            startTime == other.startTime &&
            endTime == other.endTime &&
            status == other.status &&
            purpose == other.purpose &&
            createdBy == other.createdBy &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt &&
            version == other.version &&
            incidentId == other.incidentId &&
            sourceRecommendationId == other.sourceRecommendationId;
  }

  @override
  int get hashCode => Object.hash(
    deploymentId,
    routeId,
    routeName,
    Object.hashAll(_vehicleIds),
    startTime,
    endTime,
    status,
    purpose,
    createdBy,
    createdAt,
    updatedAt,
    version,
    incidentId,
    sourceRecommendationId,
  );

  static bool _listsAreEqual(List<String> first, List<String> second) {
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
