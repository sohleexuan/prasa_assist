import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/local_sync_state.dart';
import 'package:prasa_assist/features/incidents/data/dto/incident_record_dto.dart';
import 'package:prasa_assist/features/incidents/data/dto/local_incident_draft.dart';
import 'package:prasa_assist/features/incidents/data/mappers/incident_mapper.dart';
import 'package:prasa_assist/features/incidents/data/sources/incident_local_data_source.dart';
import 'package:prasa_assist/features/incidents/data/sources/incident_remote_data_source.dart';
import 'package:prasa_assist/features/incidents/models/local_incident_work_item.dart';
import 'package:prasa_assist/features/incidents/repositories/hybrid_incident_repository.dart';
import 'package:prasa_assist/features/incidents/repositories/incident_data_exception.dart';

void main() {
  test(
    'remote success returns live data and refreshes the owner cache',
    () async {
      final local = _FakeLocal();
      final repository = HybridIncidentRepository(
        remoteDataSource: _FakeRemote(records: [_record()]),
        localDataSource: local,
        clock: () => DateTime.utc(2026, 8, 29, 9),
      );

      final result = await repository.getAllWithProvenance();

      expect(result.provenance.isCached, isFalse);
      expect(result.data.single.incidentId, 'INC-HYBRID-001');
      expect(local.cached, hasLength(1));
      expect(local.lastRetrievedAt, DateTime.utc(2026, 8, 29, 9));
    },
  );

  test(
    'verified offline failure uses confirmed owner cache with provenance',
    () async {
      final local = _FakeLocal(cached: [_record()]);
      final repository = HybridIncidentRepository(
        remoteDataSource: _FakeRemote(
          fetchAllError: const IncidentOfflineException('Offline.'),
        ),
        localDataSource: local,
        clock: () => DateTime.utc(2026, 8, 29, 10),
      );

      final result = await repository.getAllWithProvenance();

      expect(result.provenance.isCached, isTrue);
      expect(result.provenance.retrievedAtUtc, DateTime.utc(2026, 8, 28, 8));
      expect(result.data.single.incidentId, 'INC-HYBRID-001');
    },
  );

  test('offline without cache produces a safe unavailable state', () async {
    final repository = HybridIncidentRepository(
      remoteDataSource: _FakeRemote(
        fetchAllError: const IncidentOfflineException('Offline.'),
      ),
      localDataSource: _FakeLocal(),
    );

    await expectLater(
      repository.getAllWithProvenance(),
      throwsA(isA<IncidentOfflineException>()),
    );
  });

  test(
    'permission and unknown failures never masquerade as offline cache',
    () async {
      for (final error in <IncidentDataException>[
        const IncidentPermissionException('Not permitted.'),
        const IncidentUnknownDataException('Server problem.'),
      ]) {
        final repository = HybridIncidentRepository(
          remoteDataSource: _FakeRemote(fetchAllError: error),
          localDataSource: _FakeLocal(cached: [_record()]),
        );
        await expectLater(
          repository.getAllWithProvenance(),
          throwsA(same(error)),
        );
      }
    },
  );

  test(
    'local submission is explicit and rejects a duplicate concurrent submit',
    () async {
      final gate = Completer<IncidentRecordDto>();
      final local = _FakeLocal(
        workItem: LocalIncidentWorkItem(
          localId: 'draft-1',
          incident: const IncidentMapper().toDomain(_record()),
          syncState: LocalSyncState.localDraft,
          localModifiedAtUtc: DateTime.utc(2026, 8, 28),
        ),
      );
      final repository = HybridIncidentRepository(
        remoteDataSource: _FakeRemote(insertFuture: gate.future),
        localDataSource: local,
      );

      final firstSubmit = repository.publishLocalDraft('draft-1');
      await expectLater(
        repository.publishLocalDraft('draft-1'),
        throwsA(isA<IncidentValidationException>()),
      );
      gate.complete(_record());
      await firstSubmit;

      expect(local.pendingIds, ['draft-1']);
      expect(local.removedIds, ['draft-1']);
    },
  );
}

class _FakeRemote implements IncidentRemoteDataSource {
  _FakeRemote({this.records = const [], this.fetchAllError, this.insertFuture});

  final List<IncidentRecordDto> records;
  final IncidentDataException? fetchAllError;
  final Future<IncidentRecordDto>? insertFuture;

  @override
  Future<List<IncidentRecordDto>> fetchAll() async {
    final error = fetchAllError;
    if (error != null) throw error;
    return records;
  }

  @override
  Future<IncidentRecordDto?> fetchByCode(String incidentCode) async => null;

  @override
  Future<IncidentRecordDto> insert(IncidentRecordDto record) async =>
      insertFuture == null ? record : await insertFuture!;

  @override
  Future<IncidentRecordDto> transitionStatus(
    String incidentCode, {
    required String toStatus,
    String? note,
    required int expectedVersion,
  }) async => _record();

  @override
  Future<IncidentRecordDto> update(
    IncidentRecordDto record, {
    required int expectedVersion,
  }) async => record;
}

class _FakeLocal implements IncidentLocalDataSource {
  _FakeLocal({List<IncidentRecordDto>? cached, this.workItem})
    : cached = cached ?? [];

  final List<IncidentRecordDto> cached;
  final LocalIncidentWorkItem? workItem;
  DateTime? lastRetrievedAt;
  final List<String> pendingIds = [];
  final List<String> removedIds = [];

  @override
  Future<void> upsertConfirmedCache(
    Iterable<IncidentRecordDto> records, {
    required DateTime retrievedAtUtc,
  }) async {
    cached
      ..clear()
      ..addAll(records);
    lastRetrievedAt = retrievedAtUtc;
  }

  @override
  Future<List<IncidentRecordDto>> readConfirmedCache() async => cached;

  @override
  Future<DateTime?> readConfirmedCacheRetrievedAtUtc() async =>
      cached.isEmpty ? null : DateTime.utc(2026, 8, 28, 8);

  @override
  Future<IncidentRecordDto?> readConfirmedCacheByCode(
    String incidentCode,
  ) async {
    for (final record in cached) {
      if (record.incidentCode == incidentCode) return record;
    }
    return null;
  }

  @override
  Future<LocalIncidentWorkItem> createDraft(LocalIncidentDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> discardDraft(String localId) async {}

  @override
  Future<void> markPendingPublication(String localId) async {
    pendingIds.add(localId);
  }

  @override
  Future<void> markPublicationConflict(String localId) async {}

  @override
  Future<void> markPublicationFailure(String localId) async {}

  @override
  Future<LocalIncidentWorkItem?> readLocalWorkItem(String localId) async =>
      workItem?.localId == localId ? workItem : null;

  @override
  Future<List<LocalIncidentWorkItem>> readLocalWorkItems() async => const [];

  @override
  Future<void> removePublishedDraft(String localId) async {
    removedIds.add(localId);
  }
}

IncidentRecordDto _record() => IncidentRecordDto.fromMap(<String, dynamic>{
  'id': '22222222-2222-4222-8222-222222222222',
  'incident_code': 'INC-HYBRID-001',
  'incident_type': 'vehicle_breakdown',
  'title': 'Hybrid cache test',
  'description': 'Supabase-first cache verification.',
  'route_id': '300',
  'route_name': 'Route 300',
  'vehicle_id': 'B1023',
  'location': 'Depot',
  'reported_at': '2026-08-28T00:00:00Z',
  'severity': 'high',
  'status': 'reported',
  'vehicle_condition': 'immobilised',
  'disruption_scope': 'partial_obstruction',
  'estimated_delay_minutes': 75,
  'impact_level': 'severe',
  'estimation_reasons': ['Rule-based estimate.'],
  'estimation_model_version': 1,
  'data_source': 'staff_entered',
  'reported_by_label': 'Test staff',
  'created_at': '2026-08-28T00:00:00Z',
  'updated_at': '2026-08-28T00:01:00Z',
  'version': 1,
  'incident_status_history': [
    {
      'sequence_no': 1,
      'from_status': null,
      'to_status': 'reported',
      'changed_at': '2026-08-28T00:00:00Z',
      'changed_by_label': 'Test staff',
      'note': null,
    },
  ],
});
