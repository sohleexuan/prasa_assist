import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/app_database.dart';
import 'package:prasa_assist/core/database/local_sync_state.dart';
import 'package:prasa_assist/core/database/local_user_scope.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_draft.dart';
import 'package:prasa_assist/features/work_orders/data/dto/work_order_record_dto.dart';
import 'package:prasa_assist/features/work_orders/data/sources/sqlite_work_order_local_data_source.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';

import '../../../../support/sqlite_test_database.dart';

void main() {
  group('SqliteWorkOrderLocalDataSource', () {
    test('derives draft creator UUID and preserves linkage', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final source = _source(database, _ownerA);

      final created = await source.createDraft(_draft());

      expect(created.createdByUserId, _ownerA);
      expect(created.ownerUserId, _ownerA);
      expect(created.draft.incidentId, 'INC-1');
      expect(created.draft.recommendationId, 'REC-1');
      expect(created.draft.routeId, '300');
      expect(created.syncState, LocalSyncState.localDraft);
      expect(created.remoteStorageId, isNull);
    });

    test('isolates every read and mutation by owner UUID', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final ownerA = _source(database, _ownerA, prefix: 'a');
      final ownerB = _source(database, _ownerB, prefix: 'b');
      final draft = await ownerA.createDraft(_draft());
      await ownerA.upsertConfirmedCache([
        _confirmed(),
      ], retrievedAtUtc: _retrievedAt);

      expect(await ownerB.readLocalWorkItems(), isEmpty);
      expect(await ownerB.readConfirmedCache(), isEmpty);
      expect(await ownerB.readLocalWorkItem(draft.localId), isNull);
      await expectLater(
        ownerB.markPendingPublication(draft.localId),
        throwsA(isA<WorkOrderNotFoundException>()),
      );
      expect(
        (await ownerA.readLocalWorkItem(draft.localId))?.syncState,
        LocalSyncState.localDraft,
      );
    });

    test('owner isolation protects every local mutation method', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final ownerA = _source(database, _ownerA, prefix: 'owned');
      final ownerB = _source(database, _ownerB, prefix: 'other');
      final editable = await ownerA.createDraft(_draft());
      final failure = await ownerA.createDraft(_draft());
      await ownerA.markPendingPublication(failure.localId);
      final conflict = await ownerA.createDraft(_draft());
      await ownerA.markPendingPublication(conflict.localId);
      final success = await ownerA.createDraft(_draft());
      await ownerA.markPendingPublication(success.localId);
      final discard = await ownerA.createDraft(_draft());

      final operations = <Future<Object?> Function()>[
        () => ownerB.updateDraft(editable.localId, _draft()),
        () => ownerB.markPendingPublication(editable.localId),
        () => ownerB.markPublicationFailure(failure.localId, 'Safe failure.'),
        () => ownerB.markConflict(conflict.localId, 'Safe conflict.'),
        () => ownerB.applyPublicationSuccess(
          success.localId,
          _confirmed(),
          retrievedAtUtc: _retrievedAt,
        ),
        () => ownerB.discardLocalDraft(discard.localId),
      ];
      for (final operation in operations) {
        await expectLater(
          operation(),
          throwsA(isA<WorkOrderNotFoundException>()),
        );
      }

      expect(
        (await ownerA.readLocalWorkItem(editable.localId))?.syncState,
        LocalSyncState.localDraft,
      );
      expect(
        (await ownerA.readLocalWorkItem(failure.localId))?.syncState,
        LocalSyncState.pendingPublication,
      );
      expect(await ownerA.readLocalWorkItem(discard.localId), isNotNull);
    });

    test('round-trips confirmed cache including creator and linkage', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final source = _source(database, _ownerA);
      final record = _confirmed();

      await source.upsertConfirmedCache([record], retrievedAtUtc: _retrievedAt);

      final cached = await source.readConfirmedCacheById('wo-1');
      expect(cached?.toMap(), record.toMap());
      expect(cached?.createdByUserId, _creator);
      expect(cached?.incidentId, 'INC-1');
      expect(cached?.recommendationId, 'REC-1');
      expect(cached?.routeId, '300');
    });

    test('enforces pending, failure, retry and conflict states', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final source = _source(database, _ownerA);
      final draft = await source.createDraft(_draft());
      final pending = await source.markPendingPublication(draft.localId);
      final failed = await source.markPublicationFailure(
        pending.localId,
        'Publication was not confirmed.',
      );
      expect(failed.syncState, LocalSyncState.publicationFailed);
      final retry = await source.markPendingPublication(failed.localId);
      final conflict = await source.markConflict(
        retry.localId,
        'Submission needs staff review.',
      );
      expect(conflict.syncState, LocalSyncState.conflict);
      expect(conflict.safeErrorMessage, 'Submission needs staff review.');
      final reviewed = await source.updateDraft(conflict.localId, _draft());
      expect(reviewed.syncState, LocalSyncState.localDraft);
      expect(reviewed.safeErrorMessage, isNull);
    });

    test('local draft update cannot rewrite linked records', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final source = _source(database, _ownerA);
      final original = await source.createDraft(_draft());

      await expectLater(
        source.updateDraft(
          original.localId,
          LocalWorkOrderDraft(
            incidentId: 'INC-1',
            recommendationId: 'REC-1',
            routeId: '999',
            vehicleId: 'B1023',
            taskType: 'Inspection',
            description: 'Changed route attempt',
            priority: WorkOrderPriority.urgent,
            createdByLabel: 'Staff A',
          ),
        ),
        throwsA(isA<WorkOrderValidationException>()),
      );
      expect(
        (await source.readLocalWorkItem(original.localId))?.draft.routeId,
        '300',
      );
    });

    test(
      'cache refresh leaves every local publication state untouched',
      () async {
        final database = createInMemoryTestDatabase();
        addTearDown(database.close);
        final source = _source(database, _ownerA);
        final draft = await source.createDraft(_draft());
        final pending = await source.createDraft(_draft());
        await source.markPendingPublication(pending.localId);
        final failed = await source.createDraft(_draft());
        await source.markPendingPublication(failed.localId);
        await source.markPublicationFailure(failed.localId, 'Safe failure.');
        final conflict = await source.createDraft(_draft());
        await source.markPendingPublication(conflict.localId);
        await source.markConflict(conflict.localId, 'Safe conflict.');

        await source.upsertConfirmedCache([
          _confirmed(sequence: 1),
          _confirmed(sequence: 2),
          _confirmed(sequence: 3),
          _confirmed(sequence: 4),
        ], retrievedAtUtc: _retrievedAt);

        final states = {
          for (final record in await source.readLocalWorkItems())
            record.localId: record.syncState,
        };
        expect(states[draft.localId], LocalSyncState.localDraft);
        expect(states[pending.localId], LocalSyncState.pendingPublication);
        expect(states[failed.localId], LocalSyncState.publicationFailed);
        expect(states[conflict.localId], LocalSyncState.conflict);
        expect(await source.readConfirmedCache(), hasLength(4));
      },
    );

    test('multi-record cache refresh rolls back atomically', () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final source = SqliteWorkOrderLocalDataSource(
        database: database,
        userScope: LocalUserScope(_ownerA),
        localIdGenerator: () => 'same-local-id',
        clock: () => DateTime.utc(2026, 8, 29, 5),
      );

      await expectLater(
        source.upsertConfirmedCache([
          _confirmed(sequence: 1),
          _confirmed(sequence: 2),
        ], retrievedAtUtc: _retrievedAt),
        throwsA(isA<WorkOrderLocalStorageException>()),
      );
      expect(await source.readConfirmedCache(), isEmpty);
    });

    test(
      'publication success uses exact server creator and record values',
      () async {
        final database = createInMemoryTestDatabase();
        addTearDown(database.close);
        final source = _source(database, _ownerA);
        final draft = await source.createDraft(_draft());
        await source.markPendingPublication(draft.localId);

        final published = await source.applyPublicationSuccess(
          draft.localId,
          _confirmed(),
          retrievedAtUtc: _retrievedAt,
        );

        expect(published.syncState, LocalSyncState.cachedRemote);
        expect(published.createdByUserId, _creator);
        expect(published.toConfirmedDto().toMap(), _confirmed().toMap());
        expect(await source.readLocalWorkItem(draft.localId), isNull);
      },
    );

    test(
      'publication reconciliation rolls back atomically on failure',
      () async {
        final database = createInMemoryTestDatabase();
        addTearDown(database.close);
        var clock = DateTime.utc(2026, 8, 29, 5);
        var sequence = 0;
        final source = SqliteWorkOrderLocalDataSource(
          database: database,
          userScope: LocalUserScope(_ownerA),
          localIdGenerator: () => 'atomic-${++sequence}',
          clock: () => clock,
        );
        final confirmed = _confirmed();
        await source.upsertConfirmedCache([
          confirmed,
        ], retrievedAtUtc: _retrievedAt);
        clock = DateTime.utc(2026, 8, 29, 6);
        final draft = await source.createDraft(_draft());
        await source.markPendingPublication(draft.localId);
        clock = DateTime.utc(2026, 8, 29, 4);

        await expectLater(
          source.applyPublicationSuccess(
            draft.localId,
            confirmed,
            retrievedAtUtc: _retrievedAt,
          ),
          throwsA(isA<WorkOrderValidationException>()),
        );
        expect(await source.readConfirmedCacheById('WO-1'), isNotNull);
        expect(
          (await source.readLocalWorkItem(draft.localId))?.syncState,
          LocalSyncState.pendingPublication,
        );
      },
    );

    test(
      'duplicate-cache reconciliation preserves server linkage atomically',
      () async {
        final database = createInMemoryTestDatabase();
        addTearDown(database.close);
        final source = _source(database, _ownerA);
        final confirmed = _confirmed();
        await source.upsertConfirmedCache([
          confirmed,
        ], retrievedAtUtc: _retrievedAt);
        final draft = await source.createDraft(
          LocalWorkOrderDraft(
            incidentId: 'LOCAL-INC',
            recommendationId: 'LOCAL-REC',
            vehicleId: 'B1023',
            taskType: 'Inspection',
            description: 'Inspect Route 300 breakdown.',
            priority: WorkOrderPriority.urgent,
            createdByLabel: 'Staff A',
          ),
        );
        await source.markPendingPublication(draft.localId);

        final reconciled = await source.applyPublicationSuccess(
          draft.localId,
          confirmed,
          retrievedAtUtc: _retrievedAt,
        );

        expect(reconciled.localId, draft.localId);
        expect(reconciled.draft.incidentId, 'INC-1');
        expect(reconciled.draft.recommendationId, 'REC-1');
        expect(reconciled.draft.routeId, '300');
        expect(await source.readConfirmedCache(), hasLength(1));
        expect(await source.readLocalWorkItems(), isEmpty);
      },
    );

    test('closed database becomes a safe typed exception', () async {
      final database = createInMemoryTestDatabase();
      final source = _source(database, _ownerA);
      await database.close();
      await expectLater(
        source.readConfirmedCache(),
        throwsA(
          isA<WorkOrderLocalStorageException>().having(
            (error) => error.message,
            'message',
            'Local work-order data is unavailable.',
          ),
        ),
      );
    });
  });
}

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _creator = '33333333-3333-4333-8333-333333333333';
final _retrievedAt = DateTime.utc(2026, 8, 29, 4);

SqliteWorkOrderLocalDataSource _source(
  AppDatabase database,
  String owner, {
  String prefix = 'local',
}) {
  var sequence = 0;
  return SqliteWorkOrderLocalDataSource(
    database: database,
    userScope: LocalUserScope(owner),
    localIdGenerator: () => '$prefix-${++sequence}',
    clock: () => DateTime.utc(2026, 8, 29, 5),
  );
}

LocalWorkOrderDraft _draft() => LocalWorkOrderDraft(
  incidentId: 'INC-1',
  recommendationId: 'REC-1',
  routeId: '300',
  vehicleId: 'B1023',
  taskType: 'Inspection',
  description: 'Inspect Route 300 breakdown.',
  priority: WorkOrderPriority.urgent,
  scheduledStart: DateTime.utc(2026, 8, 29, 6),
  scheduledEnd: DateTime.utc(2026, 8, 29, 7),
  notes: 'Staff reviewed.',
  createdByLabel: 'Staff A',
);

WorkOrderRecordDto _confirmed({int sequence = 1}) => WorkOrderRecordDto(
  storageId: 'aaaaaaaa-aaaa-4aaa-8aaa-${sequence.toString().padLeft(12, '0')}',
  workOrderId: 'WO-$sequence',
  incidentId: 'INC-1',
  recommendationId: 'REC-1',
  routeId: '300',
  vehicleId: 'B1023',
  taskType: 'Inspection',
  description: 'Inspect Route 300 breakdown.',
  priority: WorkOrderPriority.urgent,
  assignedTo: 'Staff B',
  scheduledStart: DateTime.utc(2026, 8, 29, 6),
  scheduledEnd: DateTime.utc(2026, 8, 29, 7),
  status: WorkOrderStatus.assigned,
  notes: 'Staff reviewed.',
  createdByUserId: _creator,
  createdByLabel: 'Staff A',
  createdAt: DateTime.utc(2026, 8, 29, 3),
  updatedAt: DateTime.utc(2026, 8, 29, 3, 30),
  remoteVersion: 2,
);
