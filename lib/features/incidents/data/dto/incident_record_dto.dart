import '../../repositories/incident_data_exception.dart';

class IncidentStatusRecordDto {
  const IncidentStatusRecordDto({
    required this.sequenceNumber,
    required this.fromStatus,
    required this.toStatus,
    required this.changedAt,
    required this.changedByLabel,
    this.note,
  });

  final int sequenceNumber;
  final String? fromStatus;
  final String toStatus;
  final DateTime changedAt;
  final String changedByLabel;
  final String? note;

  factory IncidentStatusRecordDto.fromMap(Map<String, dynamic> map) {
    return IncidentStatusRecordDto(
      sequenceNumber: _requiredInt(map, 'sequence_no'),
      fromStatus: _optionalString(map, 'from_status'),
      toStatus: _requiredString(map, 'to_status'),
      changedAt: _requiredDateTime(map, 'changed_at'),
      changedByLabel: _requiredString(map, 'changed_by_label'),
      note: _optionalString(map, 'note'),
    );
  }
}

class IncidentRecordDto {
  IncidentRecordDto({
    required this.incidentCode,
    required this.incidentType,
    required this.title,
    required this.description,
    required this.routeId,
    required this.location,
    required DateTime reportedAt,
    required this.severity,
    required this.status,
    required this.vehicleCondition,
    required this.disruptionScope,
    required this.estimatedDelayMinutes,
    required this.impactLevel,
    required List<String> estimationReasons,
    required this.estimationModelVersion,
    required this.dataSource,
    required this.reportedByLabel,
    required DateTime createdAt,
    required DateTime updatedAt,
    required this.version,
    required List<IncidentStatusRecordDto> statusHistory,
    this.storageId,
    this.routeName,
    this.vehicleId,
  }) : reportedAt = reportedAt.toUtc(),
       estimationReasons = List<String>.unmodifiable(estimationReasons),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc(),
       statusHistory = List<IncidentStatusRecordDto>.unmodifiable(
         statusHistory,
       ) {
    _validate();
  }

  final String? storageId;
  final String incidentCode;
  final String incidentType;
  final String title;
  final String description;
  final String routeId;
  final String? routeName;
  final String? vehicleId;
  final String location;
  final DateTime reportedAt;
  final String severity;
  final String status;
  final String vehicleCondition;
  final String disruptionScope;
  final int estimatedDelayMinutes;
  final String impactLevel;
  final List<String> estimationReasons;
  final int estimationModelVersion;
  final String dataSource;
  final String reportedByLabel;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final List<IncidentStatusRecordDto> statusHistory;

  factory IncidentRecordDto.fromMap(Map<String, dynamic> map) {
    try {
      final historyValue = map['incident_status_history'];
      if (historyValue is! List) {
        throw const IncidentMappingException(
          'Incident status history is missing or malformed.',
        );
      }
      final history =
          historyValue
              .map((value) {
                if (value is! Map) {
                  throw const IncidentMappingException(
                    'Incident status history contains a malformed record.',
                  );
                }
                return IncidentStatusRecordDto.fromMap(
                  value.map(
                    (key, nestedValue) => MapEntry(key.toString(), nestedValue),
                  ),
                );
              })
              .toList(growable: false)
            ..sort(
              (first, second) =>
                  first.sequenceNumber.compareTo(second.sequenceNumber),
            );

      final reasonsValue = map['estimation_reasons'];
      if (reasonsValue is! List ||
          reasonsValue.any((value) => value is! String)) {
        throw const IncidentMappingException(
          'Incident estimation reasons are missing or malformed.',
        );
      }

      return IncidentRecordDto(
        storageId: _optionalString(map, 'id'),
        incidentCode: _requiredString(map, 'incident_code'),
        incidentType: _requiredString(map, 'incident_type'),
        title: _requiredString(map, 'title'),
        description: _requiredString(map, 'description'),
        routeId: _requiredString(map, 'route_id'),
        routeName: _optionalString(map, 'route_name'),
        vehicleId: _optionalString(map, 'vehicle_id'),
        location: _requiredString(map, 'location'),
        reportedAt: _requiredDateTime(map, 'reported_at'),
        severity: _requiredString(map, 'severity'),
        status: _requiredString(map, 'status'),
        vehicleCondition: _requiredString(map, 'vehicle_condition'),
        disruptionScope: _requiredString(map, 'disruption_scope'),
        estimatedDelayMinutes: _requiredInt(map, 'estimated_delay_minutes'),
        impactLevel: _requiredString(map, 'impact_level'),
        estimationReasons: reasonsValue.cast<String>(),
        estimationModelVersion: _requiredInt(map, 'estimation_model_version'),
        dataSource: _requiredString(map, 'data_source'),
        reportedByLabel: _requiredString(map, 'reported_by_label'),
        createdAt: _requiredDateTime(map, 'created_at'),
        updatedAt: _requiredDateTime(map, 'updated_at'),
        version: _requiredInt(map, 'version'),
        statusHistory: history,
      );
    } on IncidentMappingException {
      rethrow;
    } catch (error) {
      throw IncidentMappingException(
        'Incident record contains invalid data.',
        cause: error,
      );
    }
  }

  void _validate() {
    if (version < 1 || estimationModelVersion < 1) {
      throw const IncidentMappingException(
        'Incident persistence versions must be at least 1.',
      );
    }
    if (statusHistory.isEmpty) {
      throw const IncidentMappingException(
        'Incident status history must not be empty.',
      );
    }
    if (estimationReasons.isEmpty ||
        estimationReasons.any((reason) => reason.trim().isEmpty)) {
      throw const IncidentMappingException(
        'Incident estimation reasons must not be empty.',
      );
    }
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw IncidentMappingException(
      'Incident record field $key is missing or malformed.',
    );
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw IncidentMappingException('Incident record field $key is malformed.');
  }
  return value.trim();
}

int _requiredInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! int) {
    throw IncidentMappingException(
      'Incident record field $key is missing or malformed.',
    );
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String) {
    try {
      return DateTime.parse(value).toUtc();
    } on FormatException catch (error) {
      throw IncidentMappingException(
        'Incident record field $key is not a valid timestamp.',
        cause: error,
      );
    }
  }
  throw IncidentMappingException(
    'Incident record field $key is missing or malformed.',
  );
}
