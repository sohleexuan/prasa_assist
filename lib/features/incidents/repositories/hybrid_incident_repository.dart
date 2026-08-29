import '../data/dto/incident_record_dto.dart';
import '../data/dto/local_incident_draft.dart';
import '../data/mappers/incident_mapper.dart';
import '../data/sources/incident_local_data_source.dart';
import '../data/sources/incident_remote_data_source.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../models/incident_query.dart';
import '../models/incident_read_result.dart';
import '../models/local_incident_work_item.dart';
import 'incident_data_exception.dart';
import 'incident_hybrid_operations.dart';
import 'incident_repository.dart';
import 'incident_repository_capabilities.dart';

class HybridIncidentRepository
    implements
        IncidentRepository,
        IncidentRepositoryCapabilitiesProvider,
        IncidentHybridOperations {
  factory HybridIncidentRepository({
    required IncidentRemoteDataSource remoteDataSource,
    required IncidentLocalDataSource localDataSource,
    IncidentMapper mapper = const IncidentMapper(),
    DateTime Function()? clock,
  }) => HybridIncidentRepository._(
    remoteDataSource,
    localDataSource,
    mapper,
    clock ?? DateTime.now,
  );

  HybridIncidentRepository._(
    this._remote,
    this._local,
    this._mapper,
    this._clock,
  );
  final IncidentRemoteDataSource _remote;
  final IncidentLocalDataSource _local;
  final IncidentMapper _mapper;
  final DateTime Function() _clock;
  final Set<String> _publishingLocalIds = <String>{};
  @override
  IncidentRepositoryCapabilities get capabilities =>
      const IncidentRepositoryCapabilities.persistent();

  @override
  Future<List<LocalIncidentWorkItem>> getLocalWorkItems() =>
      _local.readLocalWorkItems();

  @override
  Future<LocalIncidentWorkItem> createLocalDraft(LocalIncidentDraft draft) =>
      _local.createDraft(draft);

  @override
  Future<void> discardLocalDraft(String localId) =>
      _local.discardDraft(localId);

  @override
  Future<Incident> publishLocalDraft(String localId) async {
    if (!_publishingLocalIds.add(localId)) {
      throw const IncidentValidationException(
        'This local Incident is already being submitted.',
      );
    }
    try {
      final workItem = await _local.readLocalWorkItem(localId);
      if (workItem == null) {
        throw const IncidentNotFoundException(
          'The local Incident draft was not found.',
        );
      }
      await _local.markPendingPublication(localId);
      try {
        final confirmed = await _remote.insert(
          _mapper.toDto(workItem.incident),
        );
        await _refresh([confirmed]);
        await _local.removePublishedDraft(localId);
        return _mapper.toDomain(confirmed);
      } on IncidentConflictException {
        await _local.markPublicationConflict(localId);
        rethrow;
      } catch (_) {
        await _local.markPublicationFailure(localId);
        rethrow;
      }
    } finally {
      _publishingLocalIds.remove(localId);
    }
  }

  @override
  Future<List<Incident>> getAll({IncidentQuery? query}) async =>
      (await getAllWithProvenance(query: query)).data;
  @override
  Future<Incident?> getById(String incidentId) async =>
      (await getByIdWithProvenance(incidentId)).data;
  @override
  Future<IncidentReadResult<List<Incident>>> getAllWithProvenance({
    IncidentQuery? query,
  }) async {
    try {
      final records = await _remote.fetchAll();
      final data = _filter(records.map(_mapper.toDomain), query);
      final warning = await _refresh(records);
      return IncidentReadResult(
        data: data,
        provenance: IncidentReadProvenance(
          source: IncidentReadSource.liveSupabase,
          retrievedAtUtc: _now(),
          warningMessage: warning,
        ),
      );
    } on IncidentOfflineException catch (error) {
      return _cachedAll(query, error);
    }
  }

  @override
  Future<IncidentReadResult<Incident?>> getByIdWithProvenance(
    String incidentId,
  ) async {
    try {
      final record = await _remote.fetchByCode(incidentId.trim());
      if (record != null) {
        await _refresh([record]);
      }
      return IncidentReadResult(
        data: record == null ? null : _mapper.toDomain(record),
        provenance: IncidentReadProvenance(
          source: IncidentReadSource.liveSupabase,
          retrievedAtUtc: _now(),
        ),
      );
    } on IncidentOfflineException catch (error) {
      final record = await _local.readConfirmedCacheByCode(incidentId);
      if (record == null) {
        throw IncidentOfflineException(
          'Incident data is unavailable offline and no confirmed cache exists.',
          cause: error,
        );
      }
      final retrievedAt = await _local.readConfirmedCacheRetrievedAtUtc();
      return IncidentReadResult(
        data: _mapper.toDomain(record),
        provenance: IncidentReadProvenance(
          source: IncidentReadSource.cachedSqlite,
          retrievedAtUtc: retrievedAt ?? record.updatedAt,
          warningMessage:
              'Showing cached SQLite data because Supabase is unreachable.',
        ),
      );
    }
  }

  @override
  Future<Incident> create(Incident incident) async {
    final result = await _remote.insert(_mapper.toDto(incident));
    await _refresh([result]);
    return _mapper.toDomain(result);
  }

  @override
  Future<Incident> update(Incident incident) async {
    final result = await _remote.update(
      _mapper.toDto(incident),
      expectedVersion: incident.version,
    );
    await _refresh([result]);
    return _mapper.toDomain(result);
  }

  @override
  Future<Incident> transitionStatus(
    String id,
    IncidentStatus target, {
    required String changedBy,
    String? note,
  }) async {
    final current = await _remote.fetchByCode(id);
    if (current == null) {
      throw IncidentNotFoundException('Incident $id does not exist.');
    }
    final result = await _remote.transitionStatus(
      id,
      toStatus: _storage(target),
      note: note,
      expectedVersion: current.version,
    );
    await _refresh([result]);
    return _mapper.toDomain(result);
  }

  @override
  Future<void> delete(String id) => throw const IncidentDeletionException(
    'Persistent incident records cannot be physically deleted. Use Cancelled instead.',
  );
  Future<IncidentReadResult<List<Incident>>> _cachedAll(
    IncidentQuery? query,
    IncidentOfflineException error,
  ) async {
    final records = await _local.readConfirmedCache();
    if (records.isEmpty) {
      throw IncidentOfflineException(
        'Incident data is unavailable offline and no confirmed cache exists.',
        cause: error,
      );
    }
    final retrievedAt = await _local.readConfirmedCacheRetrievedAtUtc();
    return IncidentReadResult(
      data: _filter(records.map(_mapper.toDomain), query),
      provenance: IncidentReadProvenance(
        source: IncidentReadSource.cachedSqlite,
        retrievedAtUtc: retrievedAt ?? _now(),
        warningMessage:
            'Showing cached SQLite data because Supabase is unreachable.',
      ),
    );
  }

  Future<String?> _refresh(Iterable<IncidentRecordDto> records) async {
    try {
      await _local.upsertConfirmedCache(records, retrievedAtUtc: _now());
      return null;
    } catch (_) {
      return 'Live Supabase data loaded, but the offline cache could not be refreshed.';
    }
  }

  List<Incident> _filter(Iterable<Incident> incidents, IncidentQuery? query) {
    final effective = query ?? IncidentQuery();
    final list = incidents.where(effective.matches).toList()
      ..sort(effective.compare);
    return List.unmodifiable(list);
  }

  DateTime _now() => _clock().toUtc();
  String _storage(IncidentStatus status) =>
      status == IncidentStatus.underReview ? 'under_review' : status.name;
}
