import '../data/mappers/deployment_mapper.dart';
import '../data/sources/deployment_remote_data_source.dart';
import '../models/deployment_status.dart';
import '../models/service_deployment.dart';
import 'deployment_data_exception.dart';
import 'deployment_repository.dart';
import 'deployment_repository_capabilities.dart';

/// Persistence-ready repository over a provider-neutral remote data source.
///
/// This class does not connect Supabase, SQLite, HTTP or GTFS by itself.
class PersistentDeploymentRepository
    implements DeploymentRepository, DeploymentRepositoryCapabilitiesProvider {
  PersistentDeploymentRepository({
    required DeploymentRemoteDataSource dataSource,
    DeploymentMapper mapper = const DeploymentMapper(),
    DateTime Function()? clock,
  }) : this._(dataSource, mapper, clock ?? DateTime.now);

  PersistentDeploymentRepository._(this._dataSource, this._mapper, this._clock);

  final DeploymentRemoteDataSource _dataSource;
  final DeploymentMapper _mapper;
  final DateTime Function() _clock;

  @override
  DeploymentRepositoryCapabilities get capabilities =>
      const DeploymentRepositoryCapabilities.persistent();

  @override
  Future<List<ServiceDeployment>> getAll() async {
    return _guard(() async {
      final records = await _dataSource.fetchAll();
      return List<ServiceDeployment>.unmodifiable(
        records.map(_mapper.toDomain),
      );
    });
  }

  @override
  Future<ServiceDeployment?> getById(String deploymentId) async {
    return _guard(() async {
      final record = await _dataSource.fetchByCode(deploymentId);
      return record == null ? null : _mapper.toDomain(record);
    });
  }

  @override
  Future<ServiceDeployment> create(ServiceDeployment deployment) async {
    return _guard(() async {
      final record = _mapper.toDto(deployment);
      final inserted = await _dataSource.insert(record);
      return _mapper.toDomain(inserted);
    });
  }

  @override
  Future<ServiceDeployment> update(ServiceDeployment deployment) async {
    return _guard(() async {
      final record = _mapper.toDto(deployment);
      final updated = await _dataSource.update(
        record,
        expectedVersion: deployment.version,
      );
      return _mapper.toDomain(updated);
    });
  }

  @override
  Future<void> delete(String deploymentId) async {
    throw const DeploymentPermissionException(
      'Persistent deployment records cannot be physically deleted.',
    );
  }

  @override
  Future<ServiceDeployment> transitionStatus(
    String deploymentCode,
    DeploymentStatus targetStatus, {
    required String changedByLabel,
    DateTime? changedAt,
  }) async {
    return _guard(() async {
      if (changedByLabel.trim().isEmpty) {
        throw const DeploymentValidationException(
          'A staff label is required to change deployment status.',
        );
      }
      final currentRecord = await _dataSource.fetchByCode(deploymentCode);
      if (currentRecord == null) {
        throw DeploymentNotFoundException(
          'Deployment $deploymentCode does not exist.',
        );
      }
      final current = _mapper.toDomain(currentRecord);
      if (!current.status.canTransitionTo(targetStatus)) {
        throw DeploymentValidationException(
          'Cannot change deployment status from '
          '${current.status.displayLabel} to ${targetStatus.displayLabel}.',
        );
      }
      final transitioned = await _dataSource.transitionStatus(
        deploymentCode,
        fromStatus: _statusValue(current.status),
        toStatus: _statusValue(targetStatus),
        changedByLabel: changedByLabel.trim(),
        changedAt: (changedAt ?? _clock()).toUtc(),
        expectedVersion: current.version,
      );
      return _mapper.toDomain(transitioned);
    });
  }

  String _statusValue(DeploymentStatus status) => switch (status) {
    DeploymentStatus.draft => 'draft',
    DeploymentStatus.scheduled => 'scheduled',
    DeploymentStatus.active => 'active',
    DeploymentStatus.completed => 'completed',
    DeploymentStatus.cancelled => 'cancelled',
  };

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DeploymentDataException {
      rethrow;
    } catch (error) {
      throw DeploymentUnknownDataException(
        'Unable to access deployment data.',
        cause: error,
      );
    }
  }
}
