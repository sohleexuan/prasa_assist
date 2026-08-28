import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/app_database.dart';
import 'package:prasa_assist/core/database/local_sync_state.dart';
import 'package:prasa_assist/core/database/local_user_scope.dart';
import 'package:prasa_assist/core/database/migrations/app_database_migration_v2.dart';
import 'package:prasa_assist/features/deployments/data/dto/deployment_record_dto.dart';
import 'package:prasa_assist/features/deployments/data/dto/local_deployment_draft.dart';
import 'package:prasa_assist/features/deployments/data/sources/sqlite_deployment_local_data_source.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_data_exception.dart';

import '../../../../support/sqlite_test_database.dart';

void main() {
  group('SqliteDeploymentLocalDataSource owner isolation', () {
    test('one owner cannot read or mutate another owner records', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final ownerA = _source(database, _ownerA, idPrefix: 'owner-a');
      final ownerB = _source(database, _ownerB, idPrefix: 'owner-b');
      await ownerA.upsertConfirmedCache([
        _remoteDto(),
      ], retrievedAtUtc: _retrievedAt);
      final draft = await ownerA.createDraft(_draft());

      expect(await ownerB.readConfirmedCache(), isEmpty);
      expect(await ownerB.readConfirmedCacheByCode('DEP-120'), isNull);
      expect(await ownerB.readLocalWorkItems(), isEmpty);
      expect(await ownerB.readLocalWorkItem(draft.localId), isNull);
      await expectLater(
        ownerB.updateDraft(draft.localId, _draft(routeName: 'Changed')),
        throwsA(isA<DeploymentNotFoundException>()),
      );
      await expectLater(
        ownerB.markPendingPublication(draft.localId),
        throwsA(isA<DeploymentNotFoundException>()),
      );
      await expectLater(
        ownerB.applyPublicationSuccess(
          draft.localId,
          _remoteDto(),
          retrievedAtUtc: _retrievedAt,
        ),
        throwsA(isA<DeploymentNotFoundException>()),
      );
      await expectLater(
        ownerB.discardLocalDraft(draft.localId),
        throwsA(isA<DeploymentNotFoundException>()),
      );

      expect(await ownerA.readConfirmedCache(), hasLength(1));
      expect(await ownerA.readLocalWorkItems(), hasLength(1));
    });
  });

  group('confirmed remote cache', () {
    test(
      'round-trips every DTO field, UTC instant and vehicle order',
      () async {
        final database = createInMemoryTestDatabase();
        addTearDown(database.close);
        final source = _source(database, _ownerA);
        final dto = _remoteDto(storageId: null);

        await source.upsertConfirmedCache([dto], retrievedAtUtc: _retrievedAt);

        final cached = (await source.readConfirmedCache()).single;
        expect(cached.toMap(), dto.toMap());
        expect(cached.storageId, isNull);
        expect(cached.startTime.isUtc, isTrue);
        expect(cached.endTime.isUtc, isTrue);
        expect(cached.vehicleIds, ['REPLACEMENT-BUS-01', 'REPLACEMENT-BUS-02']);
        expect(cached.vehicleIds, isNot(contains('B1023')));
        expect(
          (await source.readConfirmedCacheByCode('dep-120'))?.toMap(),
          dto.toMap(),
        );
      },
    );

    test(
      'upserts an existing cache and never deletes missing results',
      () async {
        final database = createInMemoryTestDatabase();
        addTearDown(database.close);
        final source = _source(database, _ownerA);
        await source.upsertConfirmedCache([
          _remoteDto(version: 1),
        ], retrievedAtUtc: _retrievedAt);

        final updated = _remoteDto(
          version: 2,
          routeName: 'Updated Route 300',
          vehicleIds: const ['REPLACEMENT-BUS-03'],
        );
        await source.upsertConfirmedCache([
          updated,
        ], retrievedAtUtc: _retrievedAt.add(const Duration(minutes: 5)));
        await source.upsertConfirmedCache(
          const [],
          retrievedAtUtc: _retrievedAt.add(const Duration(minutes: 10)),
        );

        final cached = await source.readConfirmedCache();
        expect(cached, hasLength(1));
        expect(cached.single.toMap(), updated.toMap());
      },
    );

    test('multi-record cache upsert rolls back atomically', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final source = SqliteDeploymentLocalDataSource(
        database: database,
        userScope: LocalUserScope(_ownerA),
        localIdGenerator: () => 'duplicate-local-id',
        clock: () => _localTime,
      );

      await expectLater(
        source.upsertConfirmedCache([
          _remoteDto(),
          _remoteDto(
            deploymentCode: 'DEP-121',
            storageId: '00000000-0000-0000-0000-000000000121',
          ),
        ], retrievedAtUtc: _retrievedAt),
        throwsA(isA<DeploymentLocalStorageException>()),
      );

      expect(await source.readConfirmedCache(), isEmpty);
    });

    test(
      'duplicate remote storage IDs are rejected before cache writes',
      () async {
        final database = createInMemoryTestDatabase();
        addTearDown(database.close);
        final source = _source(database, _ownerA);

        await expectLater(
          source.upsertConfirmedCache([
            _remoteDto(storageId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
            _remoteDto(
              deploymentCode: 'DEP-121',
              storageId: 'AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA',
            ),
          ], retrievedAtUtc: _retrievedAt),
          throwsA(isA<DeploymentValidationException>()),
        );

        expect(await source.readConfirmedCache(), isEmpty);
      },
    );

    test(
      'invalid confirmed chronology is rejected before cache writes',
      () async {
        final database = createInMemoryTestDatabase();
        addTearDown(database.close);
        final source = _source(database, _ownerA);
        final invalid = DeploymentRecordDto(
          deploymentCode: 'DEP-INVALID',
          routeId: '300',
          routeName: 'Route 300',
          vehicleIds: const ['REPLACEMENT-BUS-01'],
          startTime: DateTime.utc(2026, 8, 28, 2),
          endTime: DateTime.utc(2026, 8, 28, 1),
          status: 'scheduled',
          purpose: 'Replacement service',
          createdByLabel: '00000000-0000-0000-0000-000000000001',
          createdAt: DateTime.utc(2026, 8, 28),
          updatedAt: DateTime.utc(2026, 8, 28),
          version: 1,
        );

        await expectLater(
          source.upsertConfirmedCache([invalid], retrievedAtUtc: _retrievedAt),
          throwsA(isA<DeploymentMappingException>()),
        );
        expect(await source.readConfirmedCache(), isEmpty);
      },
    );

    test('cache refresh does not overwrite any local-work state', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final source = _source(database, _ownerA);
      final draft = await source.createDraft(_draft(routeName: 'Draft'));
      final pending = await source.markPendingPublication(
        (await source.createDraft(_draft(routeName: 'Pending'))).localId,
      );
      final failedPending = await source.markPendingPublication(
        (await source.createDraft(_draft(routeName: 'Failed'))).localId,
      );
      final failed = await source.markPublicationFailure(failedPending.localId);
      final conflictPending = await source.markPendingPublication(
        (await source.createDraft(_draft(routeName: 'Conflict'))).localId,
      );
      final conflict = await source.markConflict(conflictPending.localId);

      await source.upsertConfirmedCache([
        _remoteDto(),
      ], retrievedAtUtc: _retrievedAt);

      final work = await source.readLocalWorkItems();
      expect(work, hasLength(4));
      expect(work.map((record) => record.syncState).toSet(), {
        LocalSyncState.localDraft,
        LocalSyncState.pendingPublication,
        LocalSyncState.publicationFailed,
        LocalSyncState.conflict,
      });
      expect(
        (await source.readLocalWorkItem(draft.localId))?.draft.routeName,
        'Draft',
      );
      expect(
        (await source.readLocalWorkItem(pending.localId))?.draft.routeName,
        'Pending',
      );
      expect(
        (await source.readLocalWorkItem(failed.localId))?.draft.routeName,
        'Failed',
      );
      expect(
        (await source.readLocalWorkItem(conflict.localId))?.draft.routeName,
        'Conflict',
      );
    });
  });

  group('local draft workflow', () {
    test('creates an unpublished Draft without server fields', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final source = _source(database, _ownerA);

      final record = await source.createDraft(_draft());

      expect(record.syncState, LocalSyncState.localDraft);
      expect(record.status, 'draft');
      expect(record.remoteStorageId, isNull);
      expect(record.deploymentCode, isNull);
      expect(record.createdByLabel, isNull);
      expect(record.remoteCreatedAt, isNull);
      expect(record.remoteUpdatedAt, isNull);
      expect(record.remoteVersion, isNull);
      expect(record.retrievedAt, isNull);
      expect(record.safeErrorMessage, isNull);
    });

    test('updates values and ordered vehicles atomically', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final source = _source(database, _ownerA);
      final created = await source.createDraft(_draft());

      final updated = await source.updateDraft(
        created.localId,
        _draft(
          routeName: 'Updated Route 300',
          vehicleIds: const ['REPLACEMENT-BUS-04', 'REPLACEMENT-BUS-03'],
        ),
      );

      expect(updated.syncState, LocalSyncState.localDraft);
      expect(updated.draft.routeName, 'Updated Route 300');
      expect(updated.draft.vehicleIds, [
        'REPLACEMENT-BUS-04',
        'REPLACEMENT-BUS-03',
      ]);
      expect(
        (await source.readLocalWorkItem(created.localId))?.draft,
        updated.draft,
      );
    });

    test('enforces pending, failure retry and conflict restoration', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final source = _source(database, _ownerA);
      final first = await source.createDraft(_draft());

      final pending = await source.markPendingPublication(first.localId);
      final failed = await source.markPublicationFailure(pending.localId);
      expect(failed.syncState, LocalSyncState.publicationFailed);
      expect(
        failed.safeErrorMessage,
        SqliteDeploymentLocalDataSource.publicationFailureMessage,
      );
      final retry = await source.markPendingPublication(failed.localId);
      expect(retry.syncState, LocalSyncState.pendingPublication);
      expect(retry.safeErrorMessage, isNull);
      final conflict = await source.markConflict(retry.localId);
      expect(conflict.syncState, LocalSyncState.conflict);
      expect(
        conflict.safeErrorMessage,
        SqliteDeploymentLocalDataSource.conflictMessage,
      );
      final restored = await source.updateDraft(
        conflict.localId,
        _draft(routeName: 'Reviewed Route'),
      );
      expect(restored.syncState, LocalSyncState.localDraft);
      expect(restored.safeErrorMessage, isNull);
    });

    test('failed update restores Draft and clears safe error', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final source = _source(database, _ownerA);
      final created = await source.createDraft(_draft());
      final pending = await source.markPendingPublication(created.localId);
      final failed = await source.markPublicationFailure(pending.localId);

      final restored = await source.updateDraft(
        failed.localId,
        _draft(routeName: 'Retry Route'),
      );

      expect(restored.syncState, LocalSyncState.localDraft);
      expect(restored.safeErrorMessage, isNull);
      expect(restored.draft.routeName, 'Retry Route');
    });

    test(
      'publication success replaces all values with exact server DTO',
      () async {
        final database = createInMemoryTestDatabase();
        addTearDown(database.close);
        final source = _source(database, _ownerA);
        final created = await source.createDraft(
          _draft(routeName: 'Unconfirmed local name'),
        );
        await source.markPendingPublication(created.localId);
        final server = _remoteDto(
          version: 7,
          routeName: 'Confirmed server route',
          vehicleIds: const ['REPLACEMENT-BUS-09'],
        );

        final published = await source.applyPublicationSuccess(
          created.localId,
          server,
          retrievedAtUtc: _retrievedAt,
        );

        expect(published.syncState, LocalSyncState.cachedRemote);
        expect(published.toConfirmedDto().toMap(), server.toMap());
        expect(await source.readLocalWorkItem(created.localId), isNull);
        expect(
          (await source.readConfirmedCache()).single.toMap(),
          server.toMap(),
        );
      },
    );

    test(
      'publication success reconciles an existing confirmed cache row',
      () async {
        final database = createInMemoryTestDatabase();
        addTearDown(database.close);
        final source = _source(database, _ownerA);
        final originalCache = _remoteDto(
          version: 4,
          vehicleIds: const ['REPLACEMENT-BUS-01', 'REPLACEMENT-BUS-02'],
        );
        await source.upsertConfirmedCache([
          originalCache,
        ], retrievedAtUtc: _retrievedAt);
        final oldCacheRow = (await database.query(
          AppDatabaseMigrationV2.deploymentRecordsTable,
          where: 'owner_user_id = ? AND deployment_code = ?',
          whereArgs: [_ownerA, originalCache.deploymentCode],
        )).single;
        final oldCacheLocalId = oldCacheRow['local_id']! as String;
        final draft = await source.createDraft(
          _draft(
            routeName: 'Unconfirmed draft route',
            vehicleIds: const ['REPLACEMENT-BUS-08'],
          ),
        );
        await source.markPendingPublication(draft.localId);
        final server = _remoteDto(
          version: 9,
          routeName: 'Exact confirmed server route',
          vehicleIds: const [
            'REPLACEMENT-BUS-12',
            'REPLACEMENT-BUS-10',
            'REPLACEMENT-BUS-11',
          ],
        );

        final published = await source.applyPublicationSuccess(
          draft.localId,
          server,
          retrievedAtUtc: _retrievedAt.add(const Duration(minutes: 5)),
        );

        expect(published.localId, draft.localId);
        expect(published.toConfirmedDto().toMap(), server.toMap());
        final cached = await source.readConfirmedCache();
        expect(cached, hasLength(1));
        expect(cached.single.toMap(), server.toMap());
        expect(
          await database.query(
            AppDatabaseMigrationV2.deploymentRecordsTable,
            where: 'owner_user_id = ? AND local_id = ?',
            whereArgs: [_ownerA, oldCacheLocalId],
          ),
          isEmpty,
        );
        expect(
          await database.query(
            AppDatabaseMigrationV2.deploymentVehiclesTable,
            where: 'owner_user_id = ? AND local_deployment_id = ?',
            whereArgs: [_ownerA, oldCacheLocalId],
          ),
          isEmpty,
        );
        final vehicleRows = await database.query(
          AppDatabaseMigrationV2.deploymentVehiclesTable,
          columns: ['vehicle_id'],
          where: 'owner_user_id = ? AND local_deployment_id = ?',
          whereArgs: [_ownerA, draft.localId],
          orderBy: 'display_order ASC',
        );
        expect(
          vehicleRows.map((row) => row['vehicle_id']).toList(),
          server.vehicleIds,
        );
      },
    );

    test(
      'inconsistent confirmed identities roll publication success back',
      () async {
        final database = createInMemoryTestDatabase();
        addTearDown(database.close);
        final source = _source(database, _ownerA);
        final storageMatch = _remoteDto(
          storageId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          deploymentCode: 'DEP-A',
          vehicleIds: const ['REPLACEMENT-BUS-A'],
        );
        final codeMatch = _remoteDto(
          storageId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          deploymentCode: 'DEP-B',
          vehicleIds: const ['REPLACEMENT-BUS-B'],
        );
        await source.upsertConfirmedCache([
          storageMatch,
          codeMatch,
        ], retrievedAtUtc: _retrievedAt);
        final draft = await source.createDraft(_draft());
        final pending = await source.markPendingPublication(draft.localId);

        await expectLater(
          source.applyPublicationSuccess(
            pending.localId,
            _remoteDto(
              storageId: storageMatch.storageId,
              deploymentCode: codeMatch.deploymentCode,
              version: 8,
            ),
            retrievedAtUtc: _retrievedAt.add(const Duration(minutes: 5)),
          ),
          throwsA(isA<DeploymentLocalStorageException>()),
        );

        final preservedPending = await source.readLocalWorkItem(
          pending.localId,
        );
        expect(preservedPending?.syncState, LocalSyncState.pendingPublication);
        final caches = await source.readConfirmedCache();
        expect(caches, hasLength(2));
        final cacheByCode = {
          for (final record in caches) record.deploymentCode: record,
        };
        expect(cacheByCode['DEP-A']?.toMap(), storageMatch.toMap());
        expect(cacheByCode['DEP-B']?.toMap(), codeMatch.toMap());
      },
    );

    test('rejects every disallowed state transition', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final source = _source(database, _ownerA);
      final draft = await source.createDraft(_draft());

      await expectLater(
        source.markPublicationFailure(draft.localId),
        throwsA(isA<DeploymentValidationException>()),
      );
      await expectLater(
        source.markConflict(draft.localId),
        throwsA(isA<DeploymentValidationException>()),
      );
      await expectLater(
        source.applyPublicationSuccess(
          draft.localId,
          _remoteDto(),
          retrievedAtUtc: _retrievedAt,
        ),
        throwsA(isA<DeploymentValidationException>()),
      );
      final pending = await source.markPendingPublication(draft.localId);
      await expectLater(
        source.markPendingPublication(pending.localId),
        throwsA(isA<DeploymentValidationException>()),
      );
      await expectLater(
        source.updateDraft(pending.localId, _draft()),
        throwsA(isA<DeploymentValidationException>()),
      );
    });

    test('only localDraft can be discarded and child rows cascade', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final source = _source(database, _ownerA);
      final discardable = await source.createDraft(_draft());
      await source.discardLocalDraft(discardable.localId);

      expect(await source.readLocalWorkItem(discardable.localId), isNull);
      expect(
        await database.query(
          AppDatabaseMigrationV2.deploymentVehiclesTable,
          where: 'owner_user_id = ? AND local_deployment_id = ?',
          whereArgs: [_ownerA, discardable.localId],
        ),
        isEmpty,
      );

      final pending = await source.markPendingPublication(
        (await source.createDraft(_draft())).localId,
      );
      await expectLater(
        source.discardLocalDraft(pending.localId),
        throwsA(isA<DeploymentValidationException>()),
      );
      final failed = await source.markPublicationFailure(pending.localId);
      await expectLater(
        source.discardLocalDraft(failed.localId),
        throwsA(isA<DeploymentValidationException>()),
      );
      final retried = await source.markPendingPublication(failed.localId);
      final conflict = await source.markConflict(retried.localId);
      await expectLater(
        source.discardLocalDraft(conflict.localId),
        throwsA(isA<DeploymentValidationException>()),
      );

      await source.upsertConfirmedCache([
        _remoteDto(),
      ], retrievedAtUtc: _retrievedAt);
      final confirmedLocalId =
          (await database.query(
                AppDatabaseMigrationV2.deploymentRecordsTable,
                where: 'owner_user_id = ? AND deployment_code = ?',
                whereArgs: [_ownerA, 'DEP-120'],
              )).single['local_id']!
              as String;
      await expectLater(
        source.discardLocalDraft(confirmedLocalId),
        throwsA(isA<DeploymentValidationException>()),
      );
      expect(await source.readConfirmedCache(), hasLength(1));
    });

    test(
      'vehicle write failure rolls back the previous draft values',
      () async {
        final database = createInMemoryTestDatabase();
        addTearDown(database.close);
        final source = _source(database, _ownerA);
        final original = await source.createDraft(
          _draft(routeName: 'Original'),
        );
        await database.execute('''
        CREATE TRIGGER reject_test_vehicle
        BEFORE INSERT ON ${AppDatabaseMigrationV2.deploymentVehiclesTable}
        WHEN NEW.vehicle_id = 'FAIL-VEHICLE'
        BEGIN
          SELECT RAISE(ABORT, 'raw sqlite trigger detail');
        END
      ''');

        await expectLater(
          source.updateDraft(
            original.localId,
            _draft(
              routeName: 'Must roll back',
              vehicleIds: const ['REPLACEMENT-BUS-03', 'FAIL-VEHICLE'],
            ),
          ),
          throwsA(
            isA<DeploymentLocalStorageException>().having(
              (error) => error.message,
              'safe message',
              isNot(contains('raw sqlite trigger detail')),
            ),
          ),
        );

        final preserved = await source.readLocalWorkItem(original.localId);
        expect(preserved?.draft.routeName, 'Original');
        expect(preserved?.draft.vehicleIds, original.draft.vehicleIds);
        expect(preserved?.safeErrorMessage, isNull);
      },
    );
  });

  test('closed SQLite becomes a safe typed Module 3 failure', () async {
    final database = createInMemoryTestDatabase();
    final source = _source(database, _ownerA);
    await database.close();

    await expectLater(
      source.readConfirmedCache(),
      throwsA(
        isA<DeploymentLocalStorageException>()
            .having(
              (error) => error.message,
              'message',
              'Local deployment data is unavailable.',
            )
            .having(
              (error) => error.toString(),
              'display',
              isNot(contains('closed')),
            ),
      ),
    );
  });

  test('file database reopen preserves local work and cache', () async {
    final directory = await Directory.systemTemp.createTemp(
      'prasa-assist-deployment-local-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}deployments.db';
    final firstDatabase = createFileTestDatabase(path);
    final first = _source(firstDatabase, _ownerA);
    final draft = await first.createDraft(_draft());
    await first.upsertConfirmedCache([
      _remoteDto(),
    ], retrievedAtUtc: _retrievedAt);
    await firstDatabase.close();

    final secondDatabase = createFileTestDatabase(path);
    addTearDown(secondDatabase.close);
    final second = _source(secondDatabase, _ownerA);

    expect(await second.readConfirmedCache(), hasLength(1));
    expect((await second.readLocalWorkItem(draft.localId))?.draft, draft.draft);
  });
}

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
final _localTime = DateTime.utc(2026, 8, 28, 3, 30);
final _retrievedAt = DateTime.utc(2026, 8, 28, 3);

SqliteDeploymentLocalDataSource _source(
  AppDatabase database,
  String ownerId, {
  String idPrefix = 'local',
}) {
  var sequence = 0;
  return SqliteDeploymentLocalDataSource(
    database: database,
    userScope: LocalUserScope(ownerId),
    localIdGenerator: () => '$idPrefix-${++sequence}',
    clock: () => _localTime,
  );
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

DeploymentRecordDto _remoteDto({
  Object? storageId = '00000000-0000-0000-0000-000000000120',
  String deploymentCode = 'DEP-120',
  String routeName = 'Terminal Maluri ~ Lebuh Ampang',
  List<String> vehicleIds = const ['REPLACEMENT-BUS-01', 'REPLACEMENT-BUS-02'],
  int version = 4,
}) {
  return DeploymentRecordDto(
    storageId: storageId as String?,
    deploymentCode: deploymentCode,
    routeId: '300',
    routeName: routeName,
    vehicleIds: vehicleIds,
    startTime: DateTime.parse('2026-08-28T04:40:00+08:00'),
    endTime: DateTime.parse('2026-08-28T05:40:00+08:00'),
    status: 'scheduled',
    purpose: 'Replace unavailable Bus B1023',
    createdByLabel: '00000000-0000-0000-0000-000000000001',
    createdAt: DateTime.utc(2026, 8, 27, 20),
    updatedAt: DateTime.utc(2026, 8, 27, 21),
    version: version,
    incidentId: 'INC-2026-0142',
    recommendationId: 'REC-0088',
  );
}
