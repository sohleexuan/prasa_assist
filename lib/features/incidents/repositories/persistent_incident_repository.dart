import '../data/mappers/incident_mapper.dart';
import '../data/sources/incident_remote_data_source.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../models/incident_query.dart';
import 'incident_data_exception.dart';
import 'incident_repository.dart';
import 'incident_repository_capabilities.dart';

class PersistentIncidentRepository
    implements IncidentRepository, IncidentRepositoryCapabilitiesProvider {
  PersistentIncidentRepository({
    required IncidentRemoteDataSource dataSource,
    IncidentMapper mapper = const IncidentMapper(),
  }) : this._(dataSource, mapper);

  PersistentIncidentRepository._(this._dataSource, this._mapper);

  final IncidentRemoteDataSource _dataSource;
  final IncidentMapper _mapper;

  @override
  IncidentRepositoryCapabilities get capabilities =>
      const IncidentRepositoryCapabilities.persistent();

  @override
  Future<List<Incident>> getAll({IncidentQuery? query}) {
    return _guard(() async {
      final records = await _dataSource.fetchAll();
      final incidents = records.map(_mapper.toDomain).toList();
      final effectiveQuery = query ?? IncidentQuery();
      incidents.removeWhere((incident) => !effectiveQuery.matches(incident));
      incidents.sort(effectiveQuery.compare);
      return List<Incident>.unmodifiable(incidents);
    });
  }

  @override
  Future<Incident?> getById(String incidentId) {
    return _guard(() async {
      final record = await _dataSource.fetchByCode(incidentId.trim());
      return record == null ? null : _mapper.toDomain(record);
    });
  }

  @override
  Future<Incident> create(Incident incident) {
    return _guard(() async {
      if (incident.status != IncidentStatus.reported) {
        throw const IncidentValidationException(
          'A new incident must start as Reported.',
        );
      }
      final inserted = await _dataSource.insert(_mapper.toDto(incident));
      return _mapper.toDomain(inserted);
    });
  }

  @override
  Future<Incident> update(Incident incident) {
    return _guard(() async {
      if (incident.status.isTerminal) {
        throw const IncidentReadOnlyException(
          'Resolved and Cancelled incidents are read-only.',
        );
      }
      final updated = await _dataSource.update(
        _mapper.toDto(incident),
        expectedVersion: incident.version,
      );
      return _mapper.toDomain(updated);
    });
  }

  @override
  Future<Incident> transitionStatus(
    String incidentId,
    IncidentStatus targetStatus, {
    required String changedBy,
    String? note,
  }) {
    return _guard(() async {
      if (changedBy.trim().isEmpty) {
        throw const IncidentValidationException(
          'A staff label is required to change incident status.',
        );
      }
      if (note != null && note.trim().isEmpty) {
        throw const IncidentValidationException(
          'Status change note cannot be blank when provided.',
        );
      }
      final currentRecord = await _dataSource.fetchByCode(incidentId.trim());
      if (currentRecord == null) {
        throw IncidentNotFoundException(
          'Incident ${incidentId.trim()} does not exist.',
        );
      }
      final current = _mapper.toDomain(currentRecord);
      if (!current.status.canTransitionTo(targetStatus)) {
        throw IncidentValidationException(
          'Cannot change incident status from '
          '${current.status.displayLabel} to ${targetStatus.displayLabel}.',
        );
      }
      final transitioned = await _dataSource.transitionStatus(
        incidentId.trim(),
        toStatus: _statusToStorage(targetStatus),
        note: note,
        expectedVersion: current.version,
      );
      return _mapper.toDomain(transitioned);
    });
  }

  @override
  Future<void> delete(String incidentId) async {
    throw const IncidentDeletionException(
      'Persistent incident records cannot be physically deleted. '
      'Use Cancelled when an incident is no longer processed.',
    );
  }

  String _statusToStorage(IncidentStatus status) => switch (status) {
    IncidentStatus.reported => 'reported',
    IncidentStatus.underReview => 'under_review',
    IncidentStatus.active => 'active',
    IncidentStatus.resolved => 'resolved',
    IncidentStatus.cancelled => 'cancelled',
  };

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on IncidentDataException {
      rethrow;
    } catch (error) {
      throw IncidentUnknownDataException(
        'Unable to access incident data.',
        cause: error,
      );
    }
  }
}
