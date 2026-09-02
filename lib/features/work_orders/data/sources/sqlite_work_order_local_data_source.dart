import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_database_exception.dart';
import '../../../../core/database/local_sync_state.dart';
import '../../../../core/database/local_user_scope.dart';
import '../../../../core/database/migrations/app_database_migration_v4.dart';
import '../../models/work_order.dart';
import '../../repositories/work_order_data_exception.dart';
import '../dto/local_work_order_draft.dart';
import '../dto/local_work_order_record.dart';
import '../dto/work_order_record_dto.dart';
import '../mappers/work_order_local_mapper.dart';
import 'work_order_local_data_source.dart';

class SqliteWorkOrderLocalDataSource implements WorkOrderLocalDataSource {
  factory SqliteWorkOrderLocalDataSource({
    required AppDatabase database,
    required LocalUserScope userScope,
    required String Function() localIdGenerator,
    WorkOrderLocalMapper mapper = const WorkOrderLocalMapper(),
    DateTime Function()? clock,
  }) => SqliteWorkOrderLocalDataSource._(
    database,
    userScope.ownerUserId,
    localIdGenerator,
    mapper,
    clock ?? DateTime.now,
  );

  SqliteWorkOrderLocalDataSource._(
    this._database,
    this._ownerUserId,
    this._localIdGenerator,
    this._mapper,
    this._clock,
  );

  static const _table = AppDatabaseMigrationV4.workOrderRecordsTable;
  final AppDatabase _database;
  final String _ownerUserId;
  final String Function() _localIdGenerator;
  final WorkOrderLocalMapper _mapper;
  final DateTime Function() _clock;

  @override
  Future<List<LocalWorkOrderRecord>> readConfirmedCacheRecords() => _guard(
    () => _readRecords(
      where: 'owner_user_id = ? AND sync_state = ?',
      whereArgs: [_ownerUserId, LocalSyncState.cachedRemote.storageValue],
      orderBy: 'remote_updated_at_utc DESC',
    ),
  );

  @override
  Future<LocalWorkOrderRecord?> readConfirmedCacheRecordById(
    String workOrderId,
  ) => _guard(() async {
    final id = _requiredId(workOrderId, 'Work-order ID');
    final records = await _readRecords(
      where:
          'owner_user_id = ? AND sync_state = ? '
          'AND work_order_id = ? COLLATE NOCASE',
      whereArgs: [_ownerUserId, LocalSyncState.cachedRemote.storageValue, id],
      limit: 2,
    );
    _expectAtMostOne(records);
    return records.isEmpty ? null : records.single;
  });

  @override
  Future<List<WorkOrderRecordDto>> readConfirmedCache() async =>
      List.unmodifiable(
        (await readConfirmedCacheRecords()).map(
          (record) => record.toConfirmedDto(),
        ),
      );

  @override
  Future<WorkOrderRecordDto?> readConfirmedCacheById(
    String workOrderId,
  ) async =>
      (await readConfirmedCacheRecordById(workOrderId))?.toConfirmedDto();

  @override
  Future<void> upsertConfirmedCache(
    Iterable<WorkOrderRecordDto> records, {
    required DateTime retrievedAtUtc,
  }) => _guard(() async {
    final values = records.toList(growable: false);
    final ids = values.map((item) => item.workOrderId.toLowerCase()).toSet();
    final storageIds = values
        .map((item) => item.storageId.toLowerCase())
        .toSet();
    if (ids.length != values.length || storageIds.length != values.length) {
      throw const WorkOrderDuplicateException(
        'Confirmed cache input contains duplicate work-order identities.',
      );
    }
    await _database.transaction((transaction) async {
      for (final dto in values) {
        final existing = await _findByRemoteIdentity(transaction, dto);
        if (existing != null && !existing.isConfirmedRemote) continue;
        final now = _now();
        final record = _mapper.confirmedFromDto(
          localId: existing?.localId ?? _nextLocalId(),
          ownerUserId: _ownerUserId,
          record: dto,
          retrievedAtUtc: retrievedAtUtc.toUtc(),
          localCreatedAtUtc: existing?.localCreatedAt ?? now,
          localModifiedAtUtc: now,
        );
        if (existing == null) {
          await _insert(transaction, record);
        } else {
          await _update(transaction, record, const {
            LocalSyncState.cachedRemote,
          });
        }
      }
    });
  });

  @override
  Future<List<LocalWorkOrderRecord>> readLocalWorkItems() => _guard(
    () => _readRecords(
      where: 'owner_user_id = ? AND sync_state <> ?',
      whereArgs: [_ownerUserId, LocalSyncState.cachedRemote.storageValue],
      orderBy: 'local_modified_at_utc DESC',
    ),
  );

  @override
  Future<LocalWorkOrderRecord?> readLocalWorkItem(String localId) =>
      _guard(() async {
        final record = await _readOwned(localId);
        return record?.isConfirmedRemote == true ? null : record;
      });

  @override
  Future<LocalWorkOrderRecord> createDraft(LocalWorkOrderDraft draft) =>
      _guard(() async {
        final now = _now();
        final record = LocalWorkOrderRecord(
          localId: _nextLocalId(),
          ownerUserId: _ownerUserId,
          createdByUserId: _ownerUserId,
          draft: draft,
          status: WorkOrderStatus.draft,
          syncState: LocalSyncState.localDraft,
          localCreatedAt: now,
          localModifiedAt: now,
        );
        await _database.insert(_table, _mapper.toRow(record));
        return record;
      });

  @override
  Future<LocalWorkOrderRecord> updateDraft(
    String localId,
    LocalWorkOrderDraft draft,
  ) => _guard(
    () => _database.transaction((transaction) async {
      final existing = await _requireOwned(transaction, localId);
      const allowed = {
        LocalSyncState.localDraft,
        LocalSyncState.publicationFailed,
        LocalSyncState.conflict,
      };
      _requireState(existing, allowed);
      _requireImmutableLinkage(existing.draft, draft);
      final updated = LocalWorkOrderRecord(
        localId: existing.localId,
        ownerUserId: _ownerUserId,
        createdByUserId: _ownerUserId,
        draft: draft,
        status: WorkOrderStatus.draft,
        syncState: LocalSyncState.localDraft,
        localCreatedAt: existing.localCreatedAt,
        localModifiedAt: _now(),
      );
      await _update(transaction, updated, allowed);
      return updated;
    }),
  );

  @override
  Future<LocalWorkOrderRecord> markPendingPublication(String localId) =>
      _transition(
        localId,
        allowed: const {
          LocalSyncState.localDraft,
          LocalSyncState.publicationFailed,
        },
        target: LocalSyncState.pendingPublication,
      );

  @override
  Future<LocalWorkOrderRecord> markPublicationFailure(
    String localId,
    String safeMessage,
  ) => _transition(
    localId,
    allowed: const {LocalSyncState.pendingPublication},
    target: LocalSyncState.publicationFailed,
    safeMessage: _requiredId(safeMessage, 'Safe error message'),
  );

  @override
  Future<LocalWorkOrderRecord> markConflict(
    String localId,
    String safeMessage,
  ) => _transition(
    localId,
    allowed: const {LocalSyncState.pendingPublication},
    target: LocalSyncState.conflict,
    safeMessage: _requiredId(safeMessage, 'Safe error message'),
  );

  @override
  Future<LocalWorkOrderRecord> applyPublicationSuccess(
    String localId,
    WorkOrderRecordDto confirmedRecord, {
    required DateTime retrievedAtUtc,
  }) => _guard(
    () => _database.transaction((transaction) async {
      final pending = await _requireOwned(transaction, localId);
      _requireState(pending, const {LocalSyncState.pendingPublication});
      final duplicate = await _findByRemoteIdentity(
        transaction,
        confirmedRecord,
        excludingLocalId: pending.localId,
        cachedOnly: true,
      );
      if (duplicate != null) {
        final deleted = await transaction.delete(
          _table,
          where: 'owner_user_id = ? AND local_id = ? AND sync_state = ?',
          whereArgs: [
            _ownerUserId,
            duplicate.localId,
            LocalSyncState.cachedRemote.storageValue,
          ],
        );
        _expectOne(deleted);
      }
      final confirmed = _mapper.confirmedFromDto(
        localId: pending.localId,
        ownerUserId: _ownerUserId,
        record: confirmedRecord,
        retrievedAtUtc: retrievedAtUtc.toUtc(),
        localCreatedAtUtc: pending.localCreatedAt,
        localModifiedAtUtc: _now(),
      );
      await _update(transaction, confirmed, const {
        LocalSyncState.pendingPublication,
      });
      return confirmed;
    }),
  );

  @override
  Future<void> discardLocalDraft(String localId) => _guard(() async {
    final changed = await _database.delete(
      _table,
      where: 'owner_user_id = ? AND local_id = ? AND sync_state = ?',
      whereArgs: [
        _ownerUserId,
        _requiredId(localId, 'Local work-order ID'),
        LocalSyncState.localDraft.storageValue,
      ],
    );
    if (changed != 1) {
      throw const WorkOrderNotFoundException(
        'The local work-order draft was not found.',
      );
    }
  });

  Future<LocalWorkOrderRecord> _transition(
    String localId, {
    required Set<LocalSyncState> allowed,
    required LocalSyncState target,
    String? safeMessage,
  }) => _guard(
    () => _database.transaction((transaction) async {
      final existing = await _requireOwned(transaction, localId);
      _requireState(existing, allowed);
      final updated = LocalWorkOrderRecord(
        localId: existing.localId,
        ownerUserId: _ownerUserId,
        createdByUserId: _ownerUserId,
        draft: existing.draft,
        status: WorkOrderStatus.draft,
        syncState: target,
        localCreatedAt: existing.localCreatedAt,
        localModifiedAt: _now(),
        safeErrorMessage: safeMessage,
      );
      await _update(transaction, updated, allowed);
      return updated;
    }),
  );

  Future<List<LocalWorkOrderRecord>> _readRecords({
    required String where,
    required List<Object?> whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final rows = await _database.query(
      _table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
    return List.unmodifiable(rows.map(_mapper.fromRow));
  }

  Future<LocalWorkOrderRecord?> _readOwned(String localId) async {
    final records = await _readRecords(
      where: 'owner_user_id = ? AND local_id = ?',
      whereArgs: [_ownerUserId, _requiredId(localId, 'Local work-order ID')],
      limit: 2,
    );
    _expectAtMostOne(records);
    return records.isEmpty ? null : records.single;
  }

  Future<LocalWorkOrderRecord> _requireOwned(
    AppDatabaseTransaction transaction,
    String localId,
  ) async {
    final rows = await transaction.query(
      _table,
      where: 'owner_user_id = ? AND local_id = ?',
      whereArgs: [_ownerUserId, _requiredId(localId, 'Local work-order ID')],
      limit: 2,
    );
    if (rows.length > 1) {
      throw const WorkOrderCorruptionException(
        'Local work-order identity is inconsistent.',
      );
    }
    if (rows.isEmpty) {
      throw const WorkOrderNotFoundException(
        'The local work order was not found.',
      );
    }
    return _mapper.fromRow(rows.single);
  }

  Future<LocalWorkOrderRecord?> _findByRemoteIdentity(
    AppDatabaseTransaction transaction,
    WorkOrderRecordDto dto, {
    String? excludingLocalId,
    bool cachedOnly = false,
  }) async {
    final state = cachedOnly ? ' AND sync_state = ?' : '';
    final excluded = excludingLocalId == null ? '' : ' AND local_id <> ?';
    Future<List<LocalWorkOrderRecord>> find(String column, String value) async {
      final rows = await transaction.query(
        _table,
        where:
            'owner_user_id = ?$state AND $column = ? COLLATE NOCASE$excluded',
        whereArgs: [
          _ownerUserId,
          if (cachedOnly) LocalSyncState.cachedRemote.storageValue,
          value,
          ?excludingLocalId,
        ],
        limit: 2,
      );
      return rows.map(_mapper.fromRow).toList(growable: false);
    }

    final byStorage = await find('remote_storage_id', dto.storageId);
    final byCode = await find('work_order_id', dto.workOrderId);
    _expectAtMostOne(byStorage);
    _expectAtMostOne(byCode);
    final storageMatch = byStorage.isEmpty ? null : byStorage.single;
    final codeMatch = byCode.isEmpty ? null : byCode.single;
    if (storageMatch != null &&
        codeMatch != null &&
        storageMatch.localId != codeMatch.localId) {
      throw const WorkOrderCorruptionException(
        'Local confirmed work-order identity is inconsistent.',
      );
    }
    return storageMatch ?? codeMatch;
  }

  Future<void> _insert(
    AppDatabaseTransaction transaction,
    LocalWorkOrderRecord record,
  ) async {
    final inserted = await transaction.insert(_table, _mapper.toRow(record));
    if (inserted < 1) {
      throw const WorkOrderLocalStorageException(
        'Unable to store local work-order data.',
      );
    }
  }

  Future<void> _update(
    AppDatabaseTransaction transaction,
    LocalWorkOrderRecord record,
    Set<LocalSyncState> expected,
  ) async {
    final placeholders = List.filled(expected.length, '?').join(', ');
    final changed = await transaction.update(
      _table,
      _mapper.toRow(record),
      where:
          'owner_user_id = ? AND local_id = ? '
          'AND sync_state IN ($placeholders)',
      whereArgs: [
        _ownerUserId,
        record.localId,
        ...expected.map((item) => item.storageValue),
      ],
    );
    _expectOne(changed);
  }

  void _requireState(LocalWorkOrderRecord record, Set<LocalSyncState> allowed) {
    if (!allowed.contains(record.syncState)) {
      throw const WorkOrderValidationException(
        'The current local state does not allow that action.',
      );
    }
  }

  void _requireImmutableLinkage(
    LocalWorkOrderDraft existing,
    LocalWorkOrderDraft updated,
  ) {
    if (existing.incidentId != updated.incidentId ||
        existing.recommendationId != updated.recommendationId ||
        existing.routeId != updated.routeId) {
      throw const WorkOrderValidationException(
        'Linked records cannot be changed after draft creation.',
      );
    }
  }

  void _expectAtMostOne(List<Object> records) {
    if (records.length > 1) {
      throw const WorkOrderCorruptionException(
        'Local work-order identity is inconsistent.',
      );
    }
  }

  void _expectOne(int changed) {
    if (changed != 1) {
      throw const WorkOrderLocalStorageException(
        'Local work-order state changed unexpectedly.',
      );
    }
  }

  String _nextLocalId() =>
      _requiredId(_localIdGenerator(), 'Generated local work-order ID');
  String _requiredId(String value, String label) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw WorkOrderValidationException('$label is required.');
    }
    return trimmed;
  }

  DateTime _now() => _clock().toUtc();

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on WorkOrderDataException {
      rethrow;
    } on LocalDatabaseException catch (error) {
      throw WorkOrderLocalStorageException(
        'Local work-order data is unavailable.',
        cause: error,
      );
    } catch (error) {
      throw WorkOrderLocalStorageException(
        'Local work-order data is unavailable.',
        cause: error,
      );
    }
  }
}
