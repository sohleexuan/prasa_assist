import '../data/dto/deployment_record_dto.dart';
import '../data/dto/local_deployment_draft.dart';
import '../data/dto/local_deployment_record.dart';
import '../data/mappers/deployment_mapper.dart';
import '../data/sources/deployment_local_data_source.dart';
import '../data/sources/deployment_remote_data_source.dart';
import '../models/deployment_read_result.dart';
import '../models/deployment_status.dart';
import '../models/service_deployment.dart';
import 'deployment_data_exception.dart';
import 'deployment_hybrid_operations.dart';
import 'deployment_repository.dart';
import 'deployment_repository_capabilities.dart';

class HybridDeploymentRepository
    implements
        DeploymentRepository,
        DeploymentRepositoryCapabilitiesProvider,
        DeploymentHybridOperations {
  factory HybridDeploymentRepository({
    required DeploymentRemoteDataSource remoteDataSource,
    required DeploymentDraftRemotePublisher draftPublisher,
    required DeploymentLocalDataSource localDataSource,
    DeploymentMapper mapper = const DeploymentMapper(),
    DateTime Function()? clock,
  }) {
    return HybridDeploymentRepository._(
      remoteDataSource,
      draftPublisher,
      localDataSource,
      mapper,
      clock ?? DateTime.now,
    );
  }

  HybridDeploymentRepository._(
    this._remoteDataSource,
    this._draftPublisher,
    this._localDataSource,
    this._mapper,
    this._clock,
  );

  static const cacheRefreshWarning =
      'Live Supabase data loaded, but the offline cache could not be refreshed.';
  static const offlineUnavailableMessage =
      'Deployment data is unavailable offline and no confirmed cache exists.';

  final DeploymentRemoteDataSource _remoteDataSource;
  final DeploymentDraftRemotePublisher _draftPublisher;
  final DeploymentLocalDataSource _localDataSource;
  final DeploymentMapper _mapper;
  final DateTime Function() _clock;
  final Set<String> _publishingLocalIds = <String>{};

  @override
  DeploymentRepositoryCapabilities get capabilities =>
      const DeploymentRepositoryCapabilities.persistent();

  @override
  Future<List<ServiceDeployment>> getAll() async {
    return (await getAllWithProvenance()).data;
  }

  @override
  Future<DeploymentReadResult<List<ServiceDeployment>>>
  getAllWithProvenance() async {
    try {
      final records = await _remoteDataSource.fetchAll();
      final deployments = List<ServiceDeployment>.unmodifiable(
        records.map(_mapper.toDomain),
      );
      final retrievedAt = _now();
      final warning = await _refreshCache(records, retrievedAt);
      return DeploymentReadResult(
        data: deployments,
        provenance: DeploymentReadProvenance(
          source: DeploymentReadSource.liveSupabase,
          retrievedAtUtc: retrievedAt,
          warningMessage: warning,
        ),
      );
    } on DeploymentOfflineException catch (error) {
      return _readAllFromCache(error);
    }
  }

  @override
  Future<ServiceDeployment?> getById(String deploymentId) async {
    return (await getByIdWithProvenance(deploymentId)).data;
  }

  @override
  Future<DeploymentReadResult<ServiceDeployment?>> getByIdWithProvenance(
    String deploymentId,
  ) async {
    try {
      final record = await _remoteDataSource.fetchByCode(deploymentId);
      final deployment = record == null ? null : _mapper.toDomain(record);
      final retrievedAt = _now();
      final warning = record == null
          ? null
          : await _refreshCache([record], retrievedAt);
      return DeploymentReadResult(
        data: deployment,
        provenance: DeploymentReadProvenance(
          source: DeploymentReadSource.liveSupabase,
          retrievedAtUtc: retrievedAt,
          warningMessage: warning,
        ),
      );
    } on DeploymentOfflineException catch (error) {
      return _readOneFromCache(deploymentId, error);
    }
  }

  @override
  Future<ServiceDeployment> create(ServiceDeployment deployment) async {
    final inserted = await _remoteDataSource.insert(_mapper.toDto(deployment));
    await _refreshCache([inserted], _now());
    return _mapper.toDomain(inserted);
  }

  @override
  Future<ServiceDeployment> update(ServiceDeployment deployment) async {
    final updated = await _remoteDataSource.update(
      _mapper.toDto(deployment),
      expectedVersion: deployment.version,
    );
    await _refreshCache([updated], _now());
    return _mapper.toDomain(updated);
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
    if (changedByLabel.trim().isEmpty) {
      throw const DeploymentValidationException(
        'A staff label is required to change deployment status.',
      );
    }
    final currentRecord = await _remoteDataSource.fetchByCode(deploymentCode);
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
    final transitioned = await _remoteDataSource.transitionStatus(
      deploymentCode,
      fromStatus: _statusValue(current.status),
      toStatus: _statusValue(targetStatus),
      changedByLabel: changedByLabel.trim(),
      changedAt: (changedAt ?? _clock()).toUtc(),
      expectedVersion: current.version,
    );
    await _refreshCache([transitioned], _now());
    return _mapper.toDomain(transitioned);
  }

  @override
  Future<List<LocalDeploymentRecord>> getLocalWorkItems() {
    return _localDataSource.readLocalWorkItems();
  }

  @override
  Future<LocalDeploymentRecord?> getLocalWorkItem(String localId) {
    return _localDataSource.readLocalWorkItem(localId);
  }

  @override
  Future<LocalDeploymentRecord> createLocalDraft(LocalDeploymentDraft draft) {
    return _localDataSource.createDraft(draft);
  }

  @override
  Future<LocalDeploymentRecord> updateLocalDraft(
    String localId,
    LocalDeploymentDraft draft,
  ) {
    return _localDataSource.updateDraft(localId, draft);
  }

  @override
  Future<void> discardLocalDraft(String localId) {
    return _localDataSource.discardLocalDraft(localId);
  }

  @override
  Future<ServiceDeployment> publishLocalDraft(String localId) async {
    if (!_publishingLocalIds.add(localId)) {
      throw const DeploymentValidationException(
        'This local deployment is already being published.',
      );
    }
    try {
      final pending = await _localDataSource.markPendingPublication(localId);
      late final DeploymentRecordDto confirmed;
      try {
        confirmed = await _draftPublisher.publishDraft(pending.draft);
      } on DeploymentConflictException {
        await _localDataSource.markConflict(localId);
        rethrow;
      } catch (_) {
        await _localDataSource.markPublicationFailure(localId);
        rethrow;
      }

      try {
        final localConfirmation = await _localDataSource
            .applyPublicationSuccess(
              localId,
              confirmed,
              retrievedAtUtc: _now(),
            );
        return _mapper.toDomain(localConfirmation.toConfirmedDto());
      } catch (error) {
        await _localDataSource.markConflict(localId);
        throw DeploymentLocalStorageException(
          'The deployment was confirmed remotely, but local confirmation '
          'requires staff review.',
          cause: error,
        );
      }
    } finally {
      _publishingLocalIds.remove(localId);
    }
  }

  Future<DeploymentReadResult<List<ServiceDeployment>>> _readAllFromCache(
    DeploymentOfflineException remoteError,
  ) async {
    try {
      final records = await _localDataSource.readConfirmedCacheRecords();
      if (records.isEmpty) {
        throw DeploymentOfflineException(
          offlineUnavailableMessage,
          cause: remoteError,
        );
      }
      return DeploymentReadResult(
        data: List<ServiceDeployment>.unmodifiable(
          records.map((record) => _mapper.toDomain(record.toConfirmedDto())),
        ),
        provenance: DeploymentReadProvenance(
          source: DeploymentReadSource.cachedSqlite,
          retrievedAtUtc: _oldestRetrieval(records),
          warningMessage:
              'Showing cached SQLite data because Supabase is unreachable.',
        ),
      );
    } on DeploymentOfflineException {
      rethrow;
    } catch (error) {
      throw DeploymentOfflineException(offlineUnavailableMessage, cause: error);
    }
  }

  Future<DeploymentReadResult<ServiceDeployment?>> _readOneFromCache(
    String deploymentId,
    DeploymentOfflineException remoteError,
  ) async {
    try {
      final record = await _localDataSource.readConfirmedCacheRecordByCode(
        deploymentId,
      );
      if (record == null) {
        throw DeploymentOfflineException(
          offlineUnavailableMessage,
          cause: remoteError,
        );
      }
      return DeploymentReadResult(
        data: _mapper.toDomain(record.toConfirmedDto()),
        provenance: DeploymentReadProvenance(
          source: DeploymentReadSource.cachedSqlite,
          retrievedAtUtc: record.retrievedAt!,
          warningMessage:
              'Showing cached SQLite data because Supabase is unreachable.',
        ),
      );
    } on DeploymentOfflineException {
      rethrow;
    } catch (error) {
      throw DeploymentOfflineException(offlineUnavailableMessage, cause: error);
    }
  }

  Future<String?> _refreshCache(
    Iterable<DeploymentRecordDto> records,
    DateTime retrievedAtUtc,
  ) async {
    try {
      await _localDataSource.upsertConfirmedCache(
        records,
        retrievedAtUtc: retrievedAtUtc,
      );
      return null;
    } catch (_) {
      return cacheRefreshWarning;
    }
  }

  DateTime _oldestRetrieval(List<LocalDeploymentRecord> records) {
    return records
        .map((record) => record.retrievedAt!)
        .reduce((first, second) => first.isBefore(second) ? first : second);
  }

  DateTime _now() => _clock().toUtc();

  String _statusValue(DeploymentStatus status) => switch (status) {
    DeploymentStatus.draft => 'draft',
    DeploymentStatus.scheduled => 'scheduled',
    DeploymentStatus.active => 'active',
    DeploymentStatus.completed => 'completed',
    DeploymentStatus.cancelled => 'cancelled',
  };
}
