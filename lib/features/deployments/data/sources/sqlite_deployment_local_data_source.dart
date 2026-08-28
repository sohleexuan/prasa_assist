import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_database_exception.dart';
import '../../../../core/database/local_sync_state.dart';
import '../../../../core/database/local_user_scope.dart';
import '../../../../core/database/migrations/app_database_migration_v2.dart';
import '../../repositories/deployment_data_exception.dart';
import '../dto/deployment_record_dto.dart';
import '../dto/local_deployment_draft.dart';
import '../dto/local_deployment_record.dart';
import '../mappers/deployment_local_mapper.dart';
import '../mappers/deployment_mapper.dart';
import 'deployment_local_data_source.dart';

class SqliteDeploymentLocalDataSource implements DeploymentLocalDataSource {
  factory SqliteDeploymentLocalDataSource({
    required AppDatabase database,
    required LocalUserScope userScope,
    required String Function() localIdGenerator,
    DeploymentLocalMapper mapper = const DeploymentLocalMapper(),
    DateTime Function()? clock,
  }) {
    return SqliteDeploymentLocalDataSource._(
      database,
      userScope.ownerUserId,
      localIdGenerator,
      mapper,
      clock ?? DateTime.now,
    );
  }

  SqliteDeploymentLocalDataSource._(
    this._database,
    this._ownerUserId,
    this._localIdGenerator,
    this._mapper,
    this._clock,
  );

  static const String publicationFailureMessage =
      'Publication was not confirmed. Review and try again.';
  static const String conflictMessage =
      'This deployment changed remotely. Review it before retrying.';

  static const _records = AppDatabaseMigrationV2.deploymentRecordsTable;
  static const _vehicles = AppDatabaseMigrationV2.deploymentVehiclesTable;

  final AppDatabase _database;
  final String _ownerUserId;
  final String Function() _localIdGenerator;
  final DeploymentLocalMapper _mapper;
  final DateTime Function() _clock;

  @override
  Future<List<LocalDeploymentRecord>> readConfirmedCacheRecords() {
    return _guard(
      () => _readRecords(
        where: 'owner_user_id = ? AND sync_state = ?',
        whereArgs: [_ownerUserId, LocalSyncState.cachedRemote.storageValue],
        orderBy: 'start_time_utc ASC',
      ),
    );
  }

  @override
  Future<LocalDeploymentRecord?> readConfirmedCacheRecordByCode(
    String deploymentCode,
  ) {
    return _guard(() async {
      final normalizedCode = deploymentCode.trim();
      if (normalizedCode.isEmpty) {
        throw const DeploymentValidationException(
          'Deployment code is required.',
        );
      }
      final records = await _readRecords(
        where:
            'owner_user_id = ? AND sync_state = ? '
            'AND deployment_code = ? COLLATE NOCASE',
        whereArgs: [
          _ownerUserId,
          LocalSyncState.cachedRemote.storageValue,
          normalizedCode,
        ],
        limit: 2,
      );
      _expectAtMostOne(records);
      return records.isEmpty ? null : records.single;
    });
  }

  @override
  Future<List<DeploymentRecordDto>> readConfirmedCache() async {
    final records = await readConfirmedCacheRecords();
    return List<DeploymentRecordDto>.unmodifiable(
      records.map((record) => record.toConfirmedDto()),
    );
  }

  @override
  Future<DeploymentRecordDto?> readConfirmedCacheByCode(
    String deploymentCode,
  ) async {
    final record = await readConfirmedCacheRecordByCode(deploymentCode);
    return record?.toConfirmedDto();
  }

  @override
  Future<void> upsertConfirmedCache(
    Iterable<DeploymentRecordDto> records, {
    required DateTime retrievedAtUtc,
  }) {
    return _guard(() async {
      final validated = records
          .map(_validateConfirmedRecord)
          .toList(growable: false);
      final codes = validated
          .map((record) => record.deploymentCode.toLowerCase())
          .toSet();
      if (codes.length != validated.length) {
        throw const DeploymentValidationException(
          'Confirmed cache input contains duplicate deployment codes.',
        );
      }
      final storageIds = validated
          .map((record) => record.storageId?.toLowerCase())
          .whereType<String>()
          .toList(growable: false);
      if (storageIds.toSet().length != storageIds.length) {
        throw const DeploymentValidationException(
          'Confirmed cache input contains duplicate remote storage IDs.',
        );
      }
      final retrievedAt = retrievedAtUtc.toUtc();
      await _database.transaction((transaction) async {
        for (final dto in validated) {
          final existing = await _findByRemoteIdentity(transaction, dto);
          if (existing != null && !existing.isConfirmedRemote) {
            continue;
          }
          final now = _now();
          final localId = existing?.localId ?? _nextLocalId();
          final confirmed = _mapper.confirmedFromDto(
            localId: localId,
            ownerUserId: _ownerUserId,
            record: dto,
            retrievedAtUtc: retrievedAt,
            localCreatedAtUtc: existing?.localCreatedAt ?? now,
            localModifiedAtUtc: now,
          );
          if (existing == null) {
            await _insertRecord(transaction, confirmed);
          } else {
            await _updateRecord(
              transaction,
              confirmed,
              expectedStates: const {LocalSyncState.cachedRemote},
            );
          }
          await _replaceVehicles(transaction, confirmed);
        }
      });
    });
  }

  @override
  Future<List<LocalDeploymentRecord>> readLocalWorkItems() {
    return _guard(
      () => _readRecords(
        where: 'owner_user_id = ? AND sync_state <> ?',
        whereArgs: [_ownerUserId, LocalSyncState.cachedRemote.storageValue],
        orderBy: 'local_modified_at_utc DESC',
      ),
    );
  }

  @override
  Future<LocalDeploymentRecord?> readLocalWorkItem(String localId) {
    return _guard(() async {
      final record = await _readOwnedByLocalId(localId);
      return record?.isConfirmedRemote == true ? null : record;
    });
  }

  @override
  Future<LocalDeploymentRecord> createDraft(LocalDeploymentDraft draft) {
    return _guard(() async {
      final now = _now();
      final record = LocalDeploymentRecord(
        localId: _nextLocalId(),
        ownerUserId: _ownerUserId,
        draft: draft,
        status: 'draft',
        syncState: LocalSyncState.localDraft,
        localCreatedAt: now,
        localModifiedAt: now,
      );
      await _database.transaction((transaction) async {
        await _insertRecord(transaction, record);
        await _replaceVehicles(transaction, record);
      });
      return record;
    });
  }

  @override
  Future<LocalDeploymentRecord> updateDraft(
    String localId,
    LocalDeploymentDraft draft,
  ) {
    return _guard(() async {
      return _database.transaction((transaction) async {
        final existing = await _requireOwnedRecord(transaction, localId);
        const allowed = {
          LocalSyncState.localDraft,
          LocalSyncState.publicationFailed,
          LocalSyncState.conflict,
        };
        _requireState(existing, allowed, 'update this local deployment');
        final updated = LocalDeploymentRecord(
          localId: existing.localId,
          ownerUserId: _ownerUserId,
          draft: draft,
          status: 'draft',
          syncState: LocalSyncState.localDraft,
          localCreatedAt: existing.localCreatedAt,
          localModifiedAt: _now(),
        );
        await _updateRecord(transaction, updated, expectedStates: allowed);
        await _replaceVehicles(transaction, updated);
        return updated;
      });
    });
  }

  @override
  Future<LocalDeploymentRecord> markPendingPublication(String localId) {
    return _transitionLocalState(
      localId,
      allowedStates: const {
        LocalSyncState.localDraft,
        LocalSyncState.publicationFailed,
      },
      targetState: LocalSyncState.pendingPublication,
    );
  }

  @override
  Future<LocalDeploymentRecord> applyPublicationSuccess(
    String localId,
    DeploymentRecordDto confirmedRecord, {
    required DateTime retrievedAtUtc,
  }) {
    return _guard(() async {
      final validated = _validateConfirmedRecord(confirmedRecord);
      return _database.transaction((transaction) async {
        final existing = await _requireOwnedRecord(transaction, localId);
        _requireState(existing, const {
          LocalSyncState.pendingPublication,
        }, 'apply publication success');
        final duplicateCache = await _findByRemoteIdentity(
          transaction,
          validated,
          excludingLocalId: existing.localId,
          cachedRemoteOnly: true,
        );
        if (duplicateCache != null) {
          final deleted = await transaction.delete(
            _records,
            where: 'owner_user_id = ? AND local_id = ? AND sync_state = ?',
            whereArgs: [
              _ownerUserId,
              duplicateCache.localId,
              LocalSyncState.cachedRemote.storageValue,
            ],
          );
          _expectOneChange(deleted);
        }
        final confirmed = _mapper.confirmedFromDto(
          localId: existing.localId,
          ownerUserId: _ownerUserId,
          record: validated,
          retrievedAtUtc: retrievedAtUtc.toUtc(),
          localCreatedAtUtc: existing.localCreatedAt,
          localModifiedAtUtc: _now(),
        );
        await _updateRecord(
          transaction,
          confirmed,
          expectedStates: const {LocalSyncState.pendingPublication},
        );
        await _replaceVehicles(transaction, confirmed);
        return confirmed;
      });
    });
  }

  @override
  Future<LocalDeploymentRecord> markPublicationFailure(String localId) {
    return _transitionLocalState(
      localId,
      allowedStates: const {LocalSyncState.pendingPublication},
      targetState: LocalSyncState.publicationFailed,
      safeErrorMessage: publicationFailureMessage,
    );
  }

  @override
  Future<LocalDeploymentRecord> markConflict(String localId) {
    return _transitionLocalState(
      localId,
      allowedStates: const {LocalSyncState.pendingPublication},
      targetState: LocalSyncState.conflict,
      safeErrorMessage: conflictMessage,
    );
  }

  @override
  Future<void> discardLocalDraft(String localId) {
    return _guard(() async {
      await _database.transaction((transaction) async {
        final existing = await _requireOwnedRecord(transaction, localId);
        _requireState(existing, const {
          LocalSyncState.localDraft,
        }, 'discard this local deployment');
        final deleted = await transaction.delete(
          _records,
          where: 'owner_user_id = ? AND local_id = ? AND sync_state = ?',
          whereArgs: [
            _ownerUserId,
            existing.localId,
            LocalSyncState.localDraft.storageValue,
          ],
        );
        _expectOneChange(deleted);
      });
    });
  }

  Future<LocalDeploymentRecord> _transitionLocalState(
    String localId, {
    required Set<LocalSyncState> allowedStates,
    required LocalSyncState targetState,
    String? safeErrorMessage,
  }) {
    return _guard(() async {
      return _database.transaction((transaction) async {
        final existing = await _requireOwnedRecord(transaction, localId);
        _requireState(existing, allowedStates, 'change publication state');
        final updated = LocalDeploymentRecord(
          localId: existing.localId,
          ownerUserId: _ownerUserId,
          draft: existing.draft,
          status: 'draft',
          syncState: targetState,
          localCreatedAt: existing.localCreatedAt,
          localModifiedAt: _now(),
          safeErrorMessage: safeErrorMessage,
        );
        await _updateRecord(
          transaction,
          updated,
          expectedStates: allowedStates,
        );
        return updated;
      });
    });
  }

  Future<List<LocalDeploymentRecord>> _readRecords({
    required String where,
    required List<Object?> whereArgs,
    String? orderBy,
    int? limit,
  }) {
    return _database.transaction(
      (transaction) => _readTransactionRecords(
        transaction,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
      ),
    );
  }

  Future<LocalDeploymentRecord?> _readOwnedByLocalId(String localId) async {
    final normalized = _requiredLocalId(localId);
    final records = await _readRecords(
      where: 'owner_user_id = ? AND local_id = ?',
      whereArgs: [_ownerUserId, normalized],
      limit: 2,
    );
    _expectAtMostOne(records);
    return records.isEmpty ? null : records.single;
  }

  Future<LocalDeploymentRecord?> _findByRemoteIdentity(
    AppDatabaseTransaction transaction,
    DeploymentRecordDto dto, {
    String? excludingLocalId,
    bool cachedRemoteOnly = false,
  }) async {
    final stateClause = cachedRemoteOnly ? ' AND sync_state = ?' : '';
    LocalDeploymentRecord? storageMatch;
    if (dto.storageId case final storageId?) {
      final byStorageId = await _readTransactionRecords(
        transaction,
        where:
            'owner_user_id = ?$stateClause '
            'AND remote_storage_id = ? COLLATE NOCASE'
            '${excludingLocalId == null ? '' : ' AND local_id <> ?'}',
        whereArgs: [
          _ownerUserId,
          if (cachedRemoteOnly) LocalSyncState.cachedRemote.storageValue,
          storageId,
          ?excludingLocalId,
        ],
        limit: 2,
      );
      _expectAtMostOne(byStorageId);
      if (byStorageId.isNotEmpty) {
        storageMatch = byStorageId.single;
      }
    }
    final byCode = await _readTransactionRecords(
      transaction,
      where:
          'owner_user_id = ?$stateClause '
          'AND deployment_code = ? COLLATE NOCASE'
          '${excludingLocalId == null ? '' : ' AND local_id <> ?'}',
      whereArgs: [
        _ownerUserId,
        if (cachedRemoteOnly) LocalSyncState.cachedRemote.storageValue,
        dto.deploymentCode,
        ?excludingLocalId,
      ],
      limit: 2,
    );
    _expectAtMostOne(byCode);
    final codeMatch = byCode.isEmpty ? null : byCode.single;
    if (storageMatch != null &&
        codeMatch != null &&
        storageMatch.localId != codeMatch.localId) {
      throw const DeploymentLocalStorageException(
        'Local confirmed deployment identity is inconsistent.',
      );
    }
    return storageMatch ?? codeMatch;
  }

  Future<LocalDeploymentRecord> _requireOwnedRecord(
    AppDatabaseTransaction transaction,
    String localId,
  ) async {
    final records = await _readTransactionRecords(
      transaction,
      where: 'owner_user_id = ? AND local_id = ?',
      whereArgs: [_ownerUserId, _requiredLocalId(localId)],
      limit: 2,
    );
    _expectAtMostOne(records);
    if (records.isEmpty) {
      throw const DeploymentNotFoundException(
        'The local deployment was not found.',
      );
    }
    return records.single;
  }

  Future<List<LocalDeploymentRecord>> _readTransactionRecords(
    AppDatabaseTransaction transaction, {
    required String where,
    required List<Object?> whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final rows = await transaction.query(
      _records,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
    final records = <LocalDeploymentRecord>[];
    for (final row in rows) {
      final vehicles = await transaction.query(
        _vehicles,
        where: 'owner_user_id = ? AND local_deployment_id = ?',
        whereArgs: [_ownerUserId, row['local_id']],
        orderBy: 'display_order ASC',
      );
      records.add(_mapper.fromRows(row, vehicles));
    }
    return List<LocalDeploymentRecord>.unmodifiable(records);
  }

  Future<void> _insertRecord(
    AppDatabaseTransaction transaction,
    LocalDeploymentRecord record,
  ) async {
    final inserted = await transaction.insert(
      _records,
      _mapper.toParentRow(record),
    );
    if (inserted < 1) {
      throw const DeploymentLocalStorageException(
        'Unable to store local deployment data.',
      );
    }
  }

  Future<void> _updateRecord(
    AppDatabaseTransaction transaction,
    LocalDeploymentRecord record, {
    required Set<LocalSyncState> expectedStates,
  }) async {
    final placeholders = List.filled(expectedStates.length, '?').join(', ');
    final changed = await transaction.update(
      _records,
      _mapper.toParentRow(record),
      where:
          'owner_user_id = ? AND local_id = ? '
          'AND sync_state IN ($placeholders)',
      whereArgs: [
        _ownerUserId,
        record.localId,
        ...expectedStates.map((state) => state.storageValue),
      ],
    );
    _expectOneChange(changed);
  }

  Future<void> _replaceVehicles(
    AppDatabaseTransaction transaction,
    LocalDeploymentRecord record,
  ) async {
    await transaction.delete(
      _vehicles,
      where: 'owner_user_id = ? AND local_deployment_id = ?',
      whereArgs: [_ownerUserId, record.localId],
    );
    for (final row in _mapper.toVehicleRows(record)) {
      final inserted = await transaction.insert(_vehicles, row);
      if (inserted < 1) {
        throw const DeploymentLocalStorageException(
          'Unable to store local deployment vehicles.',
        );
      }
    }
  }

  void _requireState(
    LocalDeploymentRecord record,
    Set<LocalSyncState> allowed,
    String operation,
  ) {
    if (!allowed.contains(record.syncState)) {
      throw DeploymentValidationException(
        'The current local state does not allow staff to $operation.',
      );
    }
  }

  String _nextLocalId() {
    final localId = _localIdGenerator().trim();
    if (localId.isEmpty) {
      throw const DeploymentValidationException(
        'The generated local deployment ID is invalid.',
      );
    }
    return localId;
  }

  String _requiredLocalId(String localId) {
    final normalized = localId.trim();
    if (normalized.isEmpty) {
      throw const DeploymentValidationException(
        'Local deployment ID is required.',
      );
    }
    return normalized;
  }

  DateTime _now() => _clock().toUtc();

  DeploymentRecordDto _validateConfirmedRecord(DeploymentRecordDto record) {
    final validated = DeploymentRecordDto.fromMap(record.toMap());
    const DeploymentMapper().toDomain(validated);
    return validated;
  }

  void _expectAtMostOne(List<Object> records) {
    if (records.length > 1) {
      throw const DeploymentLocalStorageException(
        'Local deployment identity is inconsistent.',
      );
    }
  }

  void _expectOneChange(int changed) {
    if (changed != 1) {
      throw const DeploymentLocalStorageException(
        'Local deployment state changed unexpectedly.',
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DeploymentDataException {
      rethrow;
    } on LocalDatabaseException catch (error) {
      throw DeploymentLocalStorageException(
        'Local deployment data is unavailable.',
        cause: error,
      );
    } catch (error) {
      throw DeploymentLocalStorageException(
        'Local deployment data is unavailable.',
        cause: error,
      );
    }
  }
}
