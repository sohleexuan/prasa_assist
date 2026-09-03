import '../../repositories/deployment_data_exception.dart';

class DeploymentRecordDto {
  DeploymentRecordDto({
    required this.deploymentCode,
    required this.routeId,
    required this.routeName,
    required List<String> vehicleIds,
    required DateTime startTime,
    required DateTime endTime,
    required this.status,
    required this.purpose,
    required this.createdByLabel,
    required DateTime createdAt,
    required DateTime updatedAt,
    required this.version,
    this.storageId,
    this.incidentId,
    this.recommendationId,
  }) : vehicleIds = List<String>.unmodifiable(
         vehicleIds.map((vehicleId) => vehicleId.trim()),
       ),
       startTime = startTime.toUtc(),
       endTime = endTime.toUtc(),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    _validate();
  }

  static const validStatuses = <String>{
    'draft',
    'scheduled',
    'active',
    'completed',
    'cancelled',
  };

  final String? storageId;
  final String deploymentCode;
  final String routeId;
  final String routeName;
  final List<String> vehicleIds;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final String purpose;
  final String createdByLabel;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final String? incidentId;
  final String? recommendationId;

  factory DeploymentRecordDto.fromMap(Map<String, dynamic> map) {
    try {
      return DeploymentRecordDto(
        storageId: _optionalString(map, 'id'),
        deploymentCode: _requiredString(map, 'deployment_code'),
        routeId: _requiredString(map, 'route_id'),
        routeName: _requiredString(map, 'route_name'),
        vehicleIds: _readVehicleIds(map),
        startTime: _requiredDateTime(map, 'start_time'),
        endTime: _requiredDateTime(map, 'end_time'),
        status: _requiredString(map, 'status'),
        purpose: _requiredString(map, 'purpose'),
        createdByLabel: _requiredString(map, 'created_by_label'),
        createdAt: _requiredDateTime(map, 'created_at'),
        updatedAt: _requiredDateTime(map, 'updated_at'),
        version: _requiredInt(map, 'version'),
        incidentId: _optionalString(map, 'incident_id'),
        recommendationId: _optionalString(map, 'recommendation_id'),
      );
    } on DeploymentMappingException {
      rethrow;
    } catch (error) {
      throw DeploymentMappingException(
        'Deployment record contains invalid data.',
        cause: error,
      );
    }
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': storageId,
    'deployment_code': deploymentCode,
    'route_id': routeId,
    'route_name': routeName,
    'vehicle_ids': List<String>.from(vehicleIds),
    'start_time': startTime.toIso8601String(),
    'end_time': endTime.toIso8601String(),
    'status': status,
    'purpose': purpose,
    'created_by_label': createdByLabel,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'version': version,
    'incident_id': incidentId,
    'recommendation_id': recommendationId,
  };

  void _validate() {
    final requiredValues = <String, String>{
      'deployment_code': deploymentCode,
      'route_id': routeId,
      'route_name': routeName,
      'status': status,
      'purpose': purpose,
      'created_by_label': createdByLabel,
    };
    for (final entry in requiredValues.entries) {
      if (entry.value.trim().isEmpty) {
        throw DeploymentMappingException(
          'Deployment record field ${entry.key} is required.',
        );
      }
    }
    if (storageId != null && storageId!.trim().isEmpty) {
      throw const DeploymentMappingException(
        'Deployment record id cannot be blank when provided.',
      );
    }
    if (!validStatuses.contains(status)) {
      throw DeploymentMappingException(
        'Deployment record has unknown status "$status".',
      );
    }
    if (version < 1) {
      throw const DeploymentMappingException(
        'Deployment record version must be at least 1.',
      );
    }
    if (vehicleIds.isEmpty) {
      throw const DeploymentMappingException(
        'Deployment record must contain at least one vehicle ID.',
      );
    }
    if (vehicleIds.any((vehicleId) => vehicleId.isEmpty)) {
      throw const DeploymentMappingException(
        'Deployment record vehicle IDs cannot be empty.',
      );
    }
    final normalizedVehicleIds = vehicleIds
        .map((vehicleId) => vehicleId.toLowerCase())
        .toSet();
    if (normalizedVehicleIds.length != vehicleIds.length) {
      throw const DeploymentMappingException(
        'Deployment record vehicle IDs cannot contain duplicates.',
      );
    }
    if (incidentId != null && incidentId!.trim().isEmpty) {
      throw const DeploymentMappingException(
        'Deployment record incident_id cannot be blank when provided.',
      );
    }
    if (recommendationId != null && recommendationId!.trim().isEmpty) {
      throw const DeploymentMappingException(
        'Deployment record recommendation_id cannot be blank when provided.',
      );
    }
  }

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw DeploymentMappingException(
        'Deployment record field $key is missing or malformed.',
      );
    }
    return value.trim();
  }

  static String? _optionalString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      throw DeploymentMappingException(
        'Deployment record field $key is malformed.',
      );
    }
    return value.trim();
  }

  static int _requiredInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! int) {
      throw DeploymentMappingException(
        'Deployment record field $key is missing or malformed.',
      );
    }
    return value;
  }

  static DateTime _requiredDateTime(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String) {
      try {
        return DateTime.parse(value).toUtc();
      } on FormatException catch (error) {
        throw DeploymentMappingException(
          'Deployment record field $key is not a valid ISO-8601 timestamp.',
          cause: error,
        );
      }
    }
    throw DeploymentMappingException(
      'Deployment record field $key is missing or malformed.',
    );
  }

  static List<String> _readVehicleIds(Map<String, dynamic> map) {
    final nested = map['deployment_vehicles'];
    if (nested != null) {
      if (nested is! List) {
        throw const DeploymentMappingException(
          'Deployment record deployment_vehicles is malformed.',
        );
      }
      final rows = <({String vehicleId, int displayOrder})>[];
      for (final value in nested) {
        if (value is! Map) {
          throw const DeploymentMappingException(
            'Deployment record contains a malformed vehicle row.',
          );
        }
        final vehicleId = value['vehicle_id'];
        final displayOrder = value['display_order'];
        if (vehicleId is! String ||
            vehicleId.trim().isEmpty ||
            displayOrder is! int ||
            displayOrder < 0) {
          throw const DeploymentMappingException(
            'Deployment record contains a malformed vehicle row.',
          );
        }
        rows.add((vehicleId: vehicleId.trim(), displayOrder: displayOrder));
      }
      rows.sort(
        (first, second) => first.displayOrder.compareTo(second.displayOrder),
      );
      return rows.map((row) => row.vehicleId).toList(growable: false);
    }

    final values = map['vehicle_ids'];
    if (values is! List) {
      throw const DeploymentMappingException(
        'Deployment record field vehicle_ids is missing or malformed.',
      );
    }
    return values
        .map((value) {
          if (value is! String) {
            throw const DeploymentMappingException(
              'Deployment record contains a malformed vehicle ID.',
            );
          }
          return value;
        })
        .toList(growable: false);
  }
}
