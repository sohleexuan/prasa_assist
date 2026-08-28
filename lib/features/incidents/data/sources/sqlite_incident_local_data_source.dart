import 'dart:convert';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_database_exception.dart';
import '../../../../core/database/local_sync_state.dart';
import '../../../../core/database/local_user_scope.dart';
import '../../../../core/database/migrations/app_database_migration_v3.dart';
import '../../repositories/incident_data_exception.dart';
import '../../models/local_incident_work_item.dart';
import '../dto/local_incident_draft.dart';
import '../dto/incident_record_dto.dart';
import 'incident_local_data_source.dart';
import '../mappers/incident_mapper.dart';

class SqliteIncidentLocalDataSource implements IncidentLocalDataSource {
  factory SqliteIncidentLocalDataSource({
    required AppDatabase database,
    required LocalUserScope userScope,
    DateTime Function()? clock,
  }) => SqliteIncidentLocalDataSource._(
    database,
    userScope.ownerUserId,
    clock ?? DateTime.now,
  );

  SqliteIncidentLocalDataSource._(
    this._database,
    this._ownerUserId,
    this._clock,
  );

  static const _records = AppDatabaseMigrationV3.incidentRecordsTable;
  static const _history = AppDatabaseMigrationV3.incidentHistoryTable;

  final AppDatabase _database;
  final String _ownerUserId;
  final DateTime Function() _clock;

  @override
  Future<List<IncidentRecordDto>> readConfirmedCache() => _guard(() async {
    final rows = await _database.query(
      _records,
      where: 'owner_user_id = ? AND sync_state = ?',
      whereArgs: [_ownerUserId, LocalSyncState.cachedRemote.storageValue],
      orderBy: 'reported_at_utc DESC',
    );
    final records = <IncidentRecordDto>[];
    for (final row in rows) {
      records.add(await _fromRow(row));
    }
    return List<IncidentRecordDto>.unmodifiable(records);
  });

  @override
  Future<DateTime?> readConfirmedCacheRetrievedAtUtc() => _guard(() async {
    final rows = await _database.rawQuery(
      'SELECT MIN(retrieved_at_utc) AS retrieved_at_utc FROM $_records '
      'WHERE owner_user_id = ? AND sync_state = ?',
      [_ownerUserId, LocalSyncState.cachedRemote.storageValue],
    );
    final value = rows.single['retrieved_at_utc'] as String?;
    return value == null ? null : DateTime.parse(value).toUtc();
  });

  @override
  Future<IncidentRecordDto?> readConfirmedCacheByCode(String incidentCode) =>
      _guard(() async {
        final code = incidentCode.trim();
        if (code.isEmpty) {
          throw const IncidentValidationException('Incident code is required.');
        }
        final rows = await _database.query(
          _records,
          where: 'owner_user_id = ? AND sync_state = ? AND incident_code = ? COLLATE NOCASE',
          whereArgs: [
            _ownerUserId,
            LocalSyncState.cachedRemote.storageValue,
            code,
          ],
          limit: 2,
        );
        if (rows.length > 1) {
          throw const IncidentMappingException(
            'Local incident identity is inconsistent.',
          );
        }
        return rows.isEmpty ? null : _fromRow(rows.single);
      });

  @override
  Future<void> upsertConfirmedCache(
    Iterable<IncidentRecordDto> records, {
    required DateTime retrievedAtUtc,
  }) => _guard(() async {
    final values = records.toList(growable: false);
    if (values.any((record) => record.storageId == null)) {
      throw const IncidentMappingException(
        'Confirmed incident cache data is missing its remote storage ID.',
      );
    }
    final codes = values
        .map((record) => record.incidentCode.toLowerCase())
        .toSet();
    if (codes.length != values.length) {
      throw const IncidentValidationException(
        'Confirmed cache input contains duplicate incident codes.',
      );
    }
    await _database.transaction((transaction) async {
      for (final record in values) {
        final existing = await transaction.query(
          _records,
          where: 'owner_user_id = ? AND incident_code = ? COLLATE NOCASE',
          whereArgs: [_ownerUserId, record.incidentCode],
          limit: 1,
        );
        final localId = existing.isEmpty
            ? 'incident-cache-${record.incidentCode.toLowerCase()}'
            : existing.single['local_id']! as String;
        final now = _now();
        final row = _toRow(
          record,
          localId,
          retrievedAtUtc.toUtc(),
          existing.isEmpty
              ? now
              : DateTime.parse(
                  existing.single['local_created_at_utc']! as String,
                ),
          now,
        );
        if (existing.isEmpty) {
          await transaction.insert(_records, row);
        } else {
          await transaction.update(
            _records,
            row,
            where: 'owner_user_id = ? AND local_id = ?',
            whereArgs: [_ownerUserId, localId],
          );
        }
        await transaction.delete(
          _history,
          where: 'owner_user_id = ? AND local_incident_id = ?',
          whereArgs: [_ownerUserId, localId],
        );
        for (var index = 0; index < record.statusHistory.length; index++) {
          final history = record.statusHistory[index];
          await transaction.insert(_history, {
            'owner_user_id': _ownerUserId,
            'local_incident_id': localId,
            'sequence_no': history.sequenceNumber,
            'from_status': history.fromStatus,
            'to_status': history.toStatus,
            'changed_at_utc': history.changedAt.toUtc().toIso8601String(),
            'changed_by_label': history.changedByLabel,
            'note': history.note,
          });
        }
      }
    });
  });

  @override
  Future<LocalIncidentWorkItem> createDraft(LocalIncidentDraft draft) =>
      _guard(() async {
        final dto = const IncidentMapper().toDto(draft.incident);
        final now = _now();
        final localId = 'incident-draft-${now.microsecondsSinceEpoch}';
        final row = _toRow(dto, localId, now, now, now)
          ..['remote_storage_id'] = null
          ..['incident_code'] = null
          ..['remote_created_at_utc'] = null
          ..['remote_updated_at_utc'] = null
          ..['remote_version'] = null
          ..['retrieved_at_utc'] = null
          ..['sync_state'] = LocalSyncState.localDraft.storageValue;
        await _database.insert(_records, row);
        return LocalIncidentWorkItem(
          localId: localId,
          incident: draft.incident,
          syncState: LocalSyncState.localDraft,
          localModifiedAtUtc: now,
        );
      });

  @override
  Future<List<LocalIncidentWorkItem>> readLocalWorkItems() => _guard(() async {
    final rows = await _database.query(
      _records,
      where: 'owner_user_id = ? AND sync_state <> ?',
      whereArgs: [_ownerUserId, LocalSyncState.cachedRemote.storageValue],
      orderBy: 'local_modified_at_utc DESC',
    );
    return List<LocalIncidentWorkItem>.unmodifiable(
      rows.map((row) => _draftFromRow(row)),
    );
  });

  @override
  Future<void> discardDraft(String localId) => _guard(() async {
    final changed = await _database.delete(
      _records,
      where: 'owner_user_id = ? AND local_id = ? AND sync_state = ?',
      whereArgs: [
        _ownerUserId,
        localId.trim(),
        LocalSyncState.localDraft.storageValue,
      ],
    );
    if (changed != 1) {
      throw const IncidentNotFoundException(
        'The local incident draft was not found.',
      );
    }
  });

  @override
  Future<LocalIncidentWorkItem?> readLocalWorkItem(String localId) =>
      _guard(() async {
        final rows = await _database.query(
          _records,
          where: 'owner_user_id = ? AND local_id = ? AND sync_state <> ?',
          whereArgs: [
            _ownerUserId,
            localId.trim(),
            LocalSyncState.cachedRemote.storageValue,
          ],
          limit: 1,
        );
        return rows.isEmpty ? null : _draftFromRow(rows.single);
      });

  @override
  Future<void> markPendingPublication(String localId) => _changeDraftState(
    localId,
    {LocalSyncState.localDraft, LocalSyncState.publicationFailed},
    LocalSyncState.pendingPublication,
  );

  @override
  Future<void> markPublicationFailure(String localId) => _changeDraftState(
    localId,
    {LocalSyncState.pendingPublication},
    LocalSyncState.publicationFailed,
    safeErrorMessage: 'Submission was not confirmed. Review and try again.',
  );

  @override
  Future<void> markPublicationConflict(String localId) => _changeDraftState(
    localId,
    {LocalSyncState.pendingPublication},
    LocalSyncState.conflict,
    safeErrorMessage:
        'Submission needs staff review before it can be submitted again.',
  );

  @override
  Future<void> removePublishedDraft(String localId) => _guard(() async {
    final changed = await _database.delete(
      _records,
      where: 'owner_user_id = ? AND local_id = ? AND sync_state = ?',
      whereArgs: [
        _ownerUserId,
        localId.trim(),
        LocalSyncState.pendingPublication.storageValue,
      ],
    );
    if (changed != 1) {
      throw const IncidentNotFoundException(
        'The submitted local Incident draft was not found.',
      );
    }
  });

  Future<void> _changeDraftState(
    String localId,
    Set<LocalSyncState> allowed,
    LocalSyncState target, {
    String? safeErrorMessage,
  }) => _guard(() async {
    final placeholders = List.filled(allowed.length, '?').join(', ');
    final changed = await _database.update(
      _records,
      {
        'sync_state': target.storageValue,
        'safe_error_message': safeErrorMessage,
        'local_modified_at_utc': _now().toIso8601String(),
      },
      where:
          'owner_user_id = ? AND local_id = ? AND sync_state IN ($placeholders)',
      whereArgs: [
        _ownerUserId,
        localId.trim(),
        ...allowed.map((state) => state.storageValue),
      ],
    );
    if (changed != 1) {
      throw const IncidentValidationException(
        'This local Incident draft is not ready for that action.',
      );
    }
  });

  Map<String, Object?> _toRow(
    IncidentRecordDto record,
    String localId,
    DateTime retrievedAt,
    DateTime created,
    DateTime modified,
  ) => {
    'local_id': localId,
    'owner_user_id': _ownerUserId,
    'remote_storage_id': record.storageId,
    'incident_code': record.incidentCode,
    'incident_type': record.incidentType,
    'title': record.title,
    'description': record.description,
    'route_id': record.routeId,
    'route_name': record.routeName,
    'vehicle_id': record.vehicleId,
    'location': record.location,
    'reported_at_utc': record.reportedAt.toUtc().toIso8601String(),
    'severity': record.severity,
    'status': record.status,
    'vehicle_condition': record.vehicleCondition,
    'disruption_scope': record.disruptionScope,
    'estimated_delay_minutes': record.estimatedDelayMinutes,
    'impact_level': record.impactLevel,
    'estimation_reasons_json': jsonEncode(record.estimationReasons),
    'estimation_model_version': record.estimationModelVersion,
    'data_source': record.dataSource,
    'reported_by_label': record.reportedByLabel,
    'remote_created_at_utc': record.createdAt.toUtc().toIso8601String(),
    'remote_updated_at_utc': record.updatedAt.toUtc().toIso8601String(),
    'remote_version': record.version,
    'sync_state': LocalSyncState.cachedRemote.storageValue,
    'retrieved_at_utc': retrievedAt.toIso8601String(),
    'local_created_at_utc': created.toUtc().toIso8601String(),
    'local_modified_at_utc': modified.toUtc().toIso8601String(),
    'safe_error_message': null,
  };

  Future<IncidentRecordDto> _fromRow(Map<String, Object?> row) async {
    final history = await _database.query(
      _history,
      where: 'owner_user_id = ? AND local_incident_id = ?',
      whereArgs: [_ownerUserId, row['local_id']],
      orderBy: 'sequence_no ASC',
    );
    return IncidentRecordDto.fromMap({
      'id': row['remote_storage_id'],
      'incident_code': row['incident_code'],
      'incident_type': row['incident_type'],
      'title': row['title'],
      'description': row['description'],
      'route_id': row['route_id'],
      'route_name': row['route_name'],
      'vehicle_id': row['vehicle_id'],
      'location': row['location'],
      'reported_at': row['reported_at_utc'],
      'severity': row['severity'],
      'status': row['status'],
      'vehicle_condition': row['vehicle_condition'],
      'disruption_scope': row['disruption_scope'],
      'estimated_delay_minutes': row['estimated_delay_minutes'],
      'impact_level': row['impact_level'],
      'estimation_reasons': (jsonDecode(
        row['estimation_reasons_json']! as String,
      ) as List).cast<String>(),
      'estimation_model_version': row['estimation_model_version'],
      'data_source': row['data_source'],
      'reported_by_label': row['reported_by_label'],
      'created_at': row['remote_created_at_utc'],
      'updated_at': row['remote_updated_at_utc'],
      'version': row['remote_version'],
      'incident_status_history': history
          .map(
            (item) => {
              'sequence_no': item['sequence_no'],
              'from_status': item['from_status'],
              'to_status': item['to_status'],
              'changed_at': item['changed_at_utc'],
              'changed_by_label': item['changed_by_label'],
              'note': item['note'],
            },
          )
          .toList(),
    });
  }

  LocalIncidentWorkItem _draftFromRow(Map<String, Object?> row) {
    final dto = IncidentRecordDto.fromMap({
      'incident_code': 'LOCAL-${row['local_id']}',
      'incident_type': row['incident_type'],
      'title': row['title'],
      'description': row['description'],
      'route_id': row['route_id'],
      'route_name': row['route_name'],
      'vehicle_id': row['vehicle_id'],
      'location': row['location'],
      'reported_at': row['reported_at_utc'],
      'severity': row['severity'],
      'status': 'reported',
      'vehicle_condition': row['vehicle_condition'],
      'disruption_scope': row['disruption_scope'],
      'estimated_delay_minutes': row['estimated_delay_minutes'],
      'impact_level': row['impact_level'],
      'estimation_reasons': (jsonDecode(
        row['estimation_reasons_json']! as String,
      ) as List).cast<String>(),
      'estimation_model_version': row['estimation_model_version'],
      'data_source': row['data_source'],
      'reported_by_label': row['reported_by_label'],
      'created_at': row['local_created_at_utc'],
      'updated_at': row['local_modified_at_utc'],
      'version': 1,
      'incident_status_history': [
        {
          'sequence_no': 1,
          'from_status': null,
          'to_status': 'reported',
          'changed_at': row['local_created_at_utc'],
          'changed_by_label': row['reported_by_label'],
          'note': 'Local draft. Not submitted to Supabase.',
        },
      ],
    });
    return LocalIncidentWorkItem(
      localId: row['local_id']! as String,
      incident: const IncidentMapper().toDomain(dto),
      syncState: LocalSyncState.fromStorage(row['sync_state']! as String),
      localModifiedAtUtc: DateTime.parse(
        row['local_modified_at_utc']! as String,
      ),
      safeErrorMessage: row['safe_error_message'] as String?,
    );
  }

  DateTime _now() => _clock().toUtc();
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on IncidentDataException {
      rethrow;
    } on LocalDatabaseException catch (error) {
      throw IncidentUnknownDataException(
        'Local incident data is unavailable.',
        cause: error,
      );
    } catch (error) {
      throw IncidentUnknownDataException(
        'Local incident data is unavailable.',
        cause: error,
      );
    }
  }
}
