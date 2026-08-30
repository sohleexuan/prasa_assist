import '../data/dto/local_work_order_draft.dart';
import '../data/dto/local_work_order_record.dart';
import '../data/dto/work_order_record_dto.dart';
import '../data/dto/work_order_update_input.dart';
import '../data/mappers/work_order_mapper.dart';
import '../data/sources/work_order_local_data_source.dart';
import '../data/sources/work_order_remote_data_source.dart';
import '../data/sources/src/work_order_transport_classifier.dart';
import '../models/work_order.dart';
import '../models/work_order_read_result.dart';
import 'work_order_data_exception.dart';
import 'work_order_hybrid_operations.dart';

/// Coordinates a remote work-order authority with owner-scoped SQLite data.
///
/// Confirmed records come from the remote source. SQLite stores a confirmed
/// cache plus unpublished drafts, and cached reads are used only for verified
/// connectivity failures. Publishing is always an explicit staff action.
class HybridWorkOrderRepository implements WorkOrderHybridOperations {
  factory HybridWorkOrderRepository({
    required WorkOrderRemoteDataSource remoteDataSource,
    required WorkOrderLocalDataSource localDataSource,
    WorkOrderMapper mapper = const WorkOrderMapper(),
    DateTime Function()? clock,
  }) => HybridWorkOrderRepository._(
    remoteDataSource,
    localDataSource,
    mapper,
    clock ?? DateTime.now,
  );

  HybridWorkOrderRepository._(
    this._remoteDataSource,
    this._localDataSource,
    this._mapper,
    this._clock,
  );

  static const cacheRefreshWarning =
      'Confirmed work orders loaded, but the offline cache could not be refreshed.';
  static const offlineUnavailableMessage =
      'Work-order data is unavailable offline and no confirmed cache exists.';
  static const cachedWarning =
      'Showing cached SQLite data because the remote service is unreachable.';
  static const publicationFailureMessage =
      'Publication could not be confirmed. Staff must review before trying again.';
  static const publicationConflictMessage =
      'The work order changed remotely. Staff review is required.';

  final WorkOrderRemoteDataSource _remoteDataSource;
  final WorkOrderLocalDataSource _localDataSource;
  final WorkOrderMapper _mapper;
  final DateTime Function() _clock;
  final Set<String> _publishingLocalIds = <String>{};

  @override
  Future<WorkOrderReadResult<List<WorkOrder>>> readAllWithProvenance() async {
    try {
      final records = await _remoteDataSource.fetchAll();
      final retrievedAt = _now();
      final warning = await _refreshCache(records, retrievedAt);
      return WorkOrderReadResult(
        data: List<WorkOrder>.unmodifiable(records.map(_mapper.toDomain)),
        provenance: WorkOrderReadProvenance(
          source: WorkOrderReadSource.liveSupabase,
          retrievedAtUtc: retrievedAt,
          warningMessage: warning,
        ),
      );
    } catch (error) {
      if (!isVerifiedWorkOrderReadTransportFailure(error)) rethrow;
      return _readAllFromCache(error);
    }
  }

  @override
  Future<WorkOrderReadResult<WorkOrder?>> readWithProvenance(
    String workOrderId,
  ) async {
    final id = _required(workOrderId, 'Work-order ID');
    try {
      final record = await _remoteDataSource.fetchById(id);
      final retrievedAt = _now();
      final warning = record == null
          ? null
          : await _refreshCache(<WorkOrderRecordDto>[record], retrievedAt);
      return WorkOrderReadResult(
        data: record == null ? null : _mapper.toDomain(record),
        provenance: WorkOrderReadProvenance(
          source: WorkOrderReadSource.liveSupabase,
          retrievedAtUtc: retrievedAt,
          warningMessage: warning,
        ),
      );
    } catch (error) {
      if (!isVerifiedWorkOrderReadTransportFailure(error)) rethrow;
      return _readOneFromCache(id, error);
    }
  }

  @override
  Future<List<LocalWorkOrderRecord>> readLocalWorkItems() =>
      _localDataSource.readLocalWorkItems();

  @override
  Future<LocalWorkOrderRecord?> readLocalWorkItem(String localId) =>
      _localDataSource.readLocalWorkItem(localId);

  @override
  Future<LocalWorkOrderRecord> createLocalDraft(LocalWorkOrderDraft draft) =>
      _localDataSource.createDraft(draft);

  @override
  Future<LocalWorkOrderRecord> updateLocalDraft(
    String localId,
    LocalWorkOrderDraft draft,
  ) => _localDataSource.updateDraft(localId, draft);

  @override
  Future<void> discardLocalDraft(String localId) =>
      _localDataSource.discardLocalDraft(localId);

  @override
  Future<WorkOrder> publishLocalDraft(String localId) async {
    final id = _required(localId, 'Local work-order ID');
    if (!_publishingLocalIds.add(id)) {
      throw const WorkOrderValidationException(
        'This local work order is already being published.',
      );
    }
    try {
      final pending = await _localDataSource.markPendingPublication(id);
      late final WorkOrderRecordDto confirmed;
      try {
        confirmed = await _remoteDataSource.create(pending.draft);
      } on WorkOrderConflictException {
        await _localDataSource.markConflict(id, publicationConflictMessage);
        rethrow;
      } catch (_) {
        await _localDataSource.markPublicationFailure(
          id,
          publicationFailureMessage,
        );
        rethrow;
      }

      try {
        final local = await _localDataSource.applyPublicationSuccess(
          id,
          confirmed,
          retrievedAtUtc: _now(),
        );
        return _mapper.toDomain(local.toConfirmedDto());
      } catch (error) {
        await _localDataSource.markConflict(id, publicationConflictMessage);
        throw WorkOrderLocalStorageException(
          'The work order was confirmed remotely, but local confirmation requires staff review.',
          cause: error,
        );
      }
    } finally {
      _publishingLocalIds.remove(id);
    }
  }

  @override
  Future<WorkOrder> updateConfirmed(
    String workOrderId,
    WorkOrderUpdateInput input, {
    required int expectedVersion,
  }) async {
    final updated = await _remoteDataSource.update(
      _required(workOrderId, 'Work-order ID'),
      input,
      expectedVersion: _version(expectedVersion),
    );
    await _refreshCache(<WorkOrderRecordDto>[updated], _now());
    return _mapper.toDomain(updated);
  }

  @override
  Future<WorkOrder> assignConfirmed(
    String workOrderId, {
    required String assignedTo,
    required int expectedVersion,
  }) async {
    final updated = await _remoteDataSource.assign(
      _required(workOrderId, 'Work-order ID'),
      assignedTo: _required(assignedTo, 'Responsible staff'),
      expectedVersion: _version(expectedVersion),
    );
    await _refreshCache(<WorkOrderRecordDto>[updated], _now());
    return _mapper.toDomain(updated);
  }

  @override
  Future<WorkOrder> transitionConfirmed(
    String workOrderId, {
    required WorkOrderStatus fromStatus,
    required WorkOrderStatus toStatus,
    required int expectedVersion,
  }) async {
    if (!fromStatus.canTransitionTo(toStatus)) {
      throw WorkOrderValidationException(
        'Cannot change work-order status from ${fromStatus.label} to ${toStatus.label}.',
      );
    }
    final updated = await _remoteDataSource.transitionStatus(
      _required(workOrderId, 'Work-order ID'),
      fromStatus: fromStatus,
      toStatus: toStatus,
      expectedVersion: _version(expectedVersion),
    );
    await _refreshCache(<WorkOrderRecordDto>[updated], _now());
    return _mapper.toDomain(updated);
  }

  Future<WorkOrderReadResult<List<WorkOrder>>> _readAllFromCache(
    Object remoteError,
  ) async {
    try {
      final records = await _localDataSource.readConfirmedCacheRecords();
      if (records.isEmpty) {
        throw WorkOrderOfflineException(
          offlineUnavailableMessage,
          cause: remoteError,
        );
      }
      return WorkOrderReadResult(
        data: List<WorkOrder>.unmodifiable(
          records.map((record) => _mapper.toDomain(record.toConfirmedDto())),
        ),
        provenance: WorkOrderReadProvenance(
          source: WorkOrderReadSource.cachedSqlite,
          retrievedAtUtc: _oldestRetrieval(records),
          warningMessage: cachedWarning,
        ),
      );
    } on WorkOrderOfflineException {
      rethrow;
    } catch (error) {
      throw WorkOrderOfflineException(offlineUnavailableMessage, cause: error);
    }
  }

  Future<WorkOrderReadResult<WorkOrder?>> _readOneFromCache(
    String workOrderId,
    Object remoteError,
  ) async {
    try {
      final record = await _localDataSource.readConfirmedCacheRecordById(
        workOrderId,
      );
      if (record == null) {
        throw WorkOrderOfflineException(
          offlineUnavailableMessage,
          cause: remoteError,
        );
      }
      return WorkOrderReadResult(
        data: _mapper.toDomain(record.toConfirmedDto()),
        provenance: WorkOrderReadProvenance(
          source: WorkOrderReadSource.cachedSqlite,
          retrievedAtUtc: record.retrievedAt!,
          warningMessage: cachedWarning,
        ),
      );
    } on WorkOrderOfflineException {
      rethrow;
    } catch (error) {
      throw WorkOrderOfflineException(offlineUnavailableMessage, cause: error);
    }
  }

  Future<String?> _refreshCache(
    Iterable<WorkOrderRecordDto> records,
    DateTime retrievedAt,
  ) async {
    try {
      await _localDataSource.upsertConfirmedCache(
        records,
        retrievedAtUtc: retrievedAt,
      );
      return null;
    } catch (_) {
      return cacheRefreshWarning;
    }
  }

  DateTime _oldestRetrieval(List<LocalWorkOrderRecord> records) => records
      .map((record) => record.retrievedAt!)
      .reduce((first, second) => first.isBefore(second) ? first : second);

  int _version(int value) {
    if (value < 1) {
      throw const WorkOrderValidationException(
        'Expected remote version must be at least 1.',
      );
    }
    return value;
  }

  String _required(String value, String label) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw WorkOrderValidationException('$label is required.');
    }
    return normalized;
  }

  DateTime _now() => _clock().toUtc();
}
