import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/app_database.dart';
import 'package:prasa_assist/core/database/local_sync_state.dart';
import 'package:prasa_assist/core/database/local_user_scope.dart';
import 'package:prasa_assist/features/deployments/data/dto/deployment_record_dto.dart';
import 'package:prasa_assist/features/deployments/data/dto/local_deployment_draft.dart';
import 'package:prasa_assist/features/deployments/data/sources/deployment_remote_data_source.dart';
import 'package:prasa_assist/features/deployments/data/sources/sqlite_deployment_local_data_source.dart';
import 'package:prasa_assist/features/deployments/models/deployment_read_result.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_data_exception.dart';
import 'package:prasa_assist/features/deployments/repositories/hybrid_deployment_repository.dart';

import '../../../support/sqlite_test_database.dart';

void main() {
  group('HybridDeploymentRepository remote and cache policy', () {
    test('remote success is authoritative and refreshes SQLite', () async {
      final fixture = _fixture();
      addTearDown(fixture.close);
      fixture.remote.records = [_record()];

      final result = await fixture.repository.getAllWithProvenance();

      expect(result.data.single.deploymentId, 'DEP-120');
      expect(result.provenance.source, DeploymentReadSource.liveSupabase);
      expect(result.provenance.warningMessage, isNull);
      expect(
        (await fixture.local.readConfirmedCache()).single.toMap(),
        _record().toMap(),
      );
    });

    test(
      'verified offline failure uses only the current owner cache',
      () async {
        final fixture = _fixture();
        addTearDown(fixture.close);
        await fixture.local.upsertConfirmedCache([
          _record(),
        ], retrievedAtUtc: _retrievedAt);
        fixture.remote.fetchError = const DeploymentOfflineException(
          'Safe transport failure.',
        );

        final result = await fixture.repository.getAllWithProvenance();

        expect(result.data.single.deploymentId, 'DEP-120');
        expect(result.provenance.source, DeploymentReadSource.cachedSqlite);
        expect(result.provenance.retrievedAtUtc, _retrievedAt);

        final otherLocal = _localSource(fixture.database, _ownerB, 'other');
        final otherRepository = HybridDeploymentRepository(
          remoteDataSource: fixture.remote,
          draftPublisher: fixture.remote,
          localDataSource: otherLocal,
          clock: () => _now,
        );
        await expectLater(
          otherRepository.getAllWithProvenance(),
          throwsA(isA<DeploymentOfflineException>()),
        );
        expect(await otherLocal.readConfirmedCache(), isEmpty);
      },
    );

    test('offline detail read uses cached record and freshness', () async {
      final fixture = _fixture();
      addTearDown(fixture.close);
      await fixture.local.upsertConfirmedCache([
        _record(),
      ], retrievedAtUtc: _retrievedAt);
      fixture.remote.fetchError = const DeploymentOfflineException(
        'Safe transport failure.',
      );

      final result = await fixture.repository.getByIdWithProvenance('DEP-120');

      expect(result.data?.deploymentId, 'DEP-120');
      expect(result.provenance.source, DeploymentReadSource.cachedSqlite);
      expect(result.provenance.retrievedAtUtc, _retrievedAt);
    });

    test('offline without cache reports a safe unavailable failure', () async {
      final fixture = _fixture();
      addTearDown(fixture.close);
      fixture.remote.fetchError = const DeploymentOfflineException(
        'Unsafe transport detail.',
      );

      await expectLater(
        fixture.repository.getAllWithProvenance(),
        throwsA(
          isA<DeploymentOfflineException>().having(
            (error) => error.message,
            'safe message',
            HybridDeploymentRepository.offlineUnavailableMessage,
          ),
        ),
      );
    });

    test('non-network failures never fall back to populated cache', () async {
      for (final failure in <DeploymentDataException>[
        const DeploymentPermissionException('Permission denied.'),
        const DeploymentValidationException('Rejected.'),
        const DeploymentConflictException('Conflict.'),
        const DeploymentUnknownDataException('Unknown failure.'),
      ]) {
        final fixture = _fixture();
        addTearDown(fixture.close);
        await fixture.local.upsertConfirmedCache([
          _record(),
        ], retrievedAtUtc: _retrievedAt);
        fixture.remote.fetchError = failure;

        await expectLater(
          fixture.repository.getAllWithProvenance(),
          throwsA(same(failure)),
        );
      }
    });

    test('cache write failure retains live data with a warning', () async {
      final fixture = _fixture();
      fixture.remote.records = [_record()];
      await fixture.database.close();

      final result = await fixture.repository.getAllWithProvenance();

      expect(result.data.single.deploymentId, 'DEP-120');
      expect(result.provenance.source, DeploymentReadSource.liveSupabase);
      expect(
        result.provenance.warningMessage,
        HybridDeploymentRepository.cacheRefreshWarning,
      );
    });
  });

  group('HybridDeploymentRepository drafts and publication', () {
    test(
      'create, edit and discard remain local with no auto publication',
      () async {
        final fixture = _fixture();
        addTearDown(fixture.close);

        final created = await fixture.repository.createLocalDraft(_draft());
        final updated = await fixture.repository.updateLocalDraft(
          created.localId,
          _draft(routeName: 'Reviewed Route 300'),
        );

        expect(fixture.remote.publishCount, 0);
        expect(updated.syncState, LocalSyncState.localDraft);
        expect(updated.draft.routeName, 'Reviewed Route 300');
        await fixture.repository.discardLocalDraft(created.localId);
        expect(await fixture.repository.getLocalWorkItems(), isEmpty);
        expect(fixture.remote.publishCount, 0);
      },
    );

    test(
      'explicit publication uses exact draft and confirms local cache',
      () async {
        final fixture = _fixture();
        addTearDown(fixture.close);
        fixture.remote.publishedRecord = _record(
          version: 7,
          vehicleIds: const [
            'REPLACEMENT-BUS-09',
            'REPLACEMENT-BUS-07',
            'REPLACEMENT-BUS-08',
          ],
        );
        final created = await fixture.repository.createLocalDraft(
          _draft(
            vehicleIds: const [
              'REPLACEMENT-BUS-09',
              'REPLACEMENT-BUS-07',
              'REPLACEMENT-BUS-08',
            ],
          ),
        );

        final published = await fixture.repository.publishLocalDraft(
          created.localId,
        );

        expect(fixture.remote.publishCount, 1);
        expect(fixture.remote.publishedDraft, created.draft);
        expect(published.version, 7);
        expect(published.vehicleIds, fixture.remote.publishedRecord.vehicleIds);
        expect(await fixture.repository.getLocalWorkItems(), isEmpty);
        final confirmed = await fixture.local.readConfirmedCacheRecords();
        expect(confirmed.single.localId, created.localId);
        expect(
          confirmed.single.toConfirmedDto().toMap(),
          fixture.remote.publishedRecord.toMap(),
        );
      },
    );

    test('concurrent publication of one local ID is rejected', () async {
      final fixture = _fixture();
      addTearDown(fixture.close);
      final created = await fixture.repository.createLocalDraft(_draft());
      final completer = Completer<DeploymentRecordDto>();
      final started = Completer<void>();
      fixture.remote.publishCompleter = completer;
      fixture.remote.publishStarted = started;

      final first = fixture.repository.publishLocalDraft(created.localId);
      await started.future;
      await expectLater(
        fixture.repository.publishLocalDraft(created.localId),
        throwsA(isA<DeploymentValidationException>()),
      );
      expect(fixture.remote.publishCount, 1);

      completer.complete(_record());
      await first;
    });

    test('transport failure stays recoverable and retry can succeed', () async {
      final fixture = _fixture();
      addTearDown(fixture.close);
      final created = await fixture.repository.createLocalDraft(_draft());
      fixture.remote.publishError = const DeploymentOfflineException(
        'Safe offline message.',
      );

      await expectLater(
        fixture.repository.publishLocalDraft(created.localId),
        throwsA(isA<DeploymentOfflineException>()),
      );
      expect(
        (await fixture.repository.getLocalWorkItem(created.localId))?.syncState,
        LocalSyncState.publicationFailed,
      );

      fixture.remote.publishError = null;
      final published = await fixture.repository.publishLocalDraft(
        created.localId,
      );
      expect(published.deploymentId, 'DEP-120');
      expect(fixture.remote.publishCount, 2);
      expect(
        await fixture.repository.getLocalWorkItem(created.localId),
        isNull,
      );
    });

    test('optimistic conflict preserves work for staff review', () async {
      final fixture = _fixture();
      addTearDown(fixture.close);
      final created = await fixture.repository.createLocalDraft(_draft());
      fixture.remote.publishError = const DeploymentConflictException(
        'Safe conflict message.',
      );

      await expectLater(
        fixture.repository.publishLocalDraft(created.localId),
        throwsA(isA<DeploymentConflictException>()),
      );

      final preserved = await fixture.repository.getLocalWorkItem(
        created.localId,
      );
      expect(preserved?.syncState, LocalSyncState.conflict);
      expect(preserved?.draft, created.draft);
    });

    test(
      'permission failure is recoverable but never labelled offline',
      () async {
        final fixture = _fixture();
        addTearDown(fixture.close);
        final created = await fixture.repository.createLocalDraft(_draft());
        fixture.remote.publishError = const DeploymentPermissionException(
          'Safe permission message.',
        );

        await expectLater(
          fixture.repository.publishLocalDraft(created.localId),
          throwsA(isA<DeploymentPermissionException>()),
        );

        final preserved = await fixture.repository.getLocalWorkItem(
          created.localId,
        );
        expect(preserved?.syncState, LocalSyncState.publicationFailed);
        expect(preserved?.safeErrorMessage, isNot(contains('offline')));
      },
    );
  });
}

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
final _now = DateTime.utc(2026, 8, 28, 4);
final _retrievedAt = DateTime.utc(2026, 8, 28, 3);

_Fixture _fixture() {
  final database = createInMemoryTestDatabase();
  final remote = _FakeRemote();
  final local = _localSource(database, _ownerA, 'owner-a');
  return _Fixture(
    database: database,
    remote: remote,
    local: local,
    repository: HybridDeploymentRepository(
      remoteDataSource: remote,
      draftPublisher: remote,
      localDataSource: local,
      clock: () => _now,
    ),
  );
}

SqliteDeploymentLocalDataSource _localSource(
  AppDatabase database,
  String ownerId,
  String prefix,
) {
  var sequence = 0;
  return SqliteDeploymentLocalDataSource(
    database: database,
    userScope: LocalUserScope(ownerId),
    localIdGenerator: () => '$prefix-${++sequence}',
    clock: () => _now,
  );
}

class _Fixture {
  const _Fixture({
    required this.database,
    required this.remote,
    required this.local,
    required this.repository,
  });

  final AppDatabase database;
  final _FakeRemote remote;
  final SqliteDeploymentLocalDataSource local;
  final HybridDeploymentRepository repository;

  Future<void> close() => database.close();
}

class _FakeRemote
    implements DeploymentRemoteDataSource, DeploymentDraftRemotePublisher {
  List<DeploymentRecordDto> records = const [];
  DeploymentRecordDto publishedRecord = _record();
  Object? fetchError;
  Object? publishError;
  Completer<DeploymentRecordDto>? publishCompleter;
  Completer<void>? publishStarted;
  LocalDeploymentDraft? publishedDraft;
  int publishCount = 0;

  @override
  Future<List<DeploymentRecordDto>> fetchAll() async {
    if (fetchError case final error?) {
      throw error;
    }
    return records;
  }

  @override
  Future<DeploymentRecordDto?> fetchByCode(String deploymentCode) async {
    if (fetchError case final error?) {
      throw error;
    }
    for (final record in records) {
      if (record.deploymentCode == deploymentCode) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<DeploymentRecordDto> publishDraft(LocalDeploymentDraft draft) async {
    publishCount++;
    publishedDraft = draft;
    final started = publishStarted;
    if (started != null && !started.isCompleted) {
      started.complete();
    }
    if (publishError case final error?) {
      throw error;
    }
    final completer = publishCompleter;
    if (completer != null) {
      return completer.future;
    }
    return publishedRecord;
  }

  @override
  Future<DeploymentRecordDto> insert(DeploymentRecordDto record) async {
    return publishedRecord;
  }

  @override
  Future<DeploymentRecordDto> update(
    DeploymentRecordDto record, {
    required int expectedVersion,
  }) async {
    return publishedRecord;
  }

  @override
  Future<DeploymentRecordDto> transitionStatus(
    String deploymentCode, {
    required String fromStatus,
    required String toStatus,
    required String changedByLabel,
    required DateTime changedAt,
    required int expectedVersion,
  }) async {
    return publishedRecord;
  }

  @override
  Future<void> delete(
    String deploymentCode, {
    required int expectedVersion,
  }) async {
    throw UnimplementedError();
  }
}

LocalDeploymentDraft _draft({
  String routeName = 'Terminal Maluri ~ Lebuh Ampang',
  List<String> vehicleIds = const ['REPLACEMENT-BUS-01', 'REPLACEMENT-BUS-02'],
}) {
  return LocalDeploymentDraft(
    routeId: '300',
    routeName: routeName,
    vehicleIds: vehicleIds,
    startTime: DateTime.parse('2026-08-28T04:40:00+08:00'),
    endTime: DateTime.parse('2026-08-28T05:40:00+08:00'),
    purpose: 'Replace unavailable Bus B1023',
    incidentId: 'INC-2026-0142',
    recommendationId: 'REC-0088',
  );
}

DeploymentRecordDto _record({
  int version = 4,
  List<String> vehicleIds = const ['REPLACEMENT-BUS-01', 'REPLACEMENT-BUS-02'],
}) {
  return DeploymentRecordDto(
    storageId: '00000000-0000-0000-0000-000000000120',
    deploymentCode: 'DEP-120',
    routeId: '300',
    routeName: 'Terminal Maluri ~ Lebuh Ampang',
    vehicleIds: vehicleIds,
    startTime: DateTime.parse('2026-08-28T04:40:00+08:00'),
    endTime: DateTime.parse('2026-08-28T05:40:00+08:00'),
    status: 'draft',
    purpose: 'Replace unavailable Bus B1023',
    createdByLabel: _ownerA,
    createdAt: DateTime.utc(2026, 8, 27, 20),
    updatedAt: DateTime.utc(2026, 8, 27, 21),
    version: version,
    incidentId: 'INC-2026-0142',
    recommendationId: 'REC-0088',
  );
}
