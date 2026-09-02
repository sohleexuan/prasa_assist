import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/local_sync_state.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_draft.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_record.dart';
import 'package:prasa_assist/features/work_orders/data/dto/work_order_record_dto.dart';
import 'package:prasa_assist/features/work_orders/data/dto/work_order_update_input.dart';
import 'package:prasa_assist/features/work_orders/data/sources/work_order_local_data_source.dart';
import 'package:prasa_assist/features/work_orders/data/sources/work_order_remote_data_source.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/models/work_order_read_result.dart';
import 'package:prasa_assist/features/work_orders/repositories/hybrid_work_order_repository.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';

void main() {
  group('HybridWorkOrderRepository reads', () {
    test('returns live records and refreshes confirmed cache', () async {
      final fixture = _Fixture();
      fixture.remote.records = [_confirmed()];

      final result = await fixture.repository.readAllWithProvenance();

      expect(result.provenance.source, WorkOrderReadSource.liveSupabase);
      expect(result.data.single.workOrderId, 'WO-0001');
      expect(fixture.local.cached.single.draft.incidentId, 'INC-300');
      expect(
        fixture.local.cached.single.draft.recommendationId,
        'REC-INSPECT-B1023',
      );
    });

    test(
      'uses confirmed cache only for verified read transport failure',
      () async {
        final fixture = _Fixture();
        fixture.local.cached = [_cached(_confirmed())];
        fixture.remote.readError = TimeoutException('network timeout');

        final result = await fixture.repository.readAllWithProvenance();

        expect(result.provenance.source, WorkOrderReadSource.cachedSqlite);
        expect(result.provenance.isCached, isTrue);
        expect(result.data.single.vehicleId, 'B1023');
      },
    );

    test('does not hide permission failures with cached data', () async {
      final fixture = _Fixture();
      fixture.local.cached = [_cached(_confirmed())];
      fixture.remote.readError = const WorkOrderPermissionException('denied');

      await expectLater(
        fixture.repository.readAllWithProvenance(),
        throwsA(isA<WorkOrderPermissionException>()),
      );
    });

    test(
      'reports cache refresh failure without mislabelling live data',
      () async {
        final fixture = _Fixture();
        fixture.remote.records = [_confirmed()];
        fixture.local.upsertError = const WorkOrderLocalStorageException('bad');

        final result = await fixture.repository.readAllWithProvenance();

        expect(result.provenance.source, WorkOrderReadSource.liveSupabase);
        expect(
          result.provenance.warningMessage,
          HybridWorkOrderRepository.cacheRefreshWarning,
        );
      },
    );
  });

  group('HybridWorkOrderRepository writes', () {
    test(
      'publishes only an explicit local draft and preserves linkage',
      () async {
        final fixture = _Fixture();
        final draft = _draft();
        final local = await fixture.repository.createLocalDraft(draft);
        fixture.remote.createResult = _confirmed();

        final result = await fixture.repository.publishLocalDraft(
          local.localId,
        );

        expect(fixture.remote.createdDraft, same(draft));
        expect(result.incidentId, 'INC-300');
        expect(result.recommendationId, 'REC-INSPECT-B1023');
        expect(result.routeId, '300');
        expect(fixture.remote.publicationKey, local.localId);
        expect(
          fixture.local.cached.single.syncState,
          LocalSyncState.cachedRemote,
        );
      },
    );

    test('does not retry an ambiguous publication failure', () async {
      final fixture = _Fixture();
      final local = await fixture.repository.createLocalDraft(_draft());
      fixture.remote.createError = TimeoutException('unknown outcome');

      await expectLater(
        fixture.repository.publishLocalDraft(local.localId),
        throwsA(isA<TimeoutException>()),
      );

      expect(fixture.remote.createCalls, 1);
      expect(
        fixture.local.local.single.syncState,
        LocalSyncState.publicationFailed,
      );
    });

    test('blocks concurrent publication of the same local draft', () async {
      final fixture = _Fixture();
      final local = await fixture.repository.createLocalDraft(_draft());
      final gate = Completer<WorkOrderRecordDto>();
      fixture.remote.createCompleter = gate;

      final first = fixture.repository.publishLocalDraft(local.localId);
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        fixture.repository.publishLocalDraft(local.localId),
        throwsA(isA<WorkOrderValidationException>()),
      );
      gate.complete(_confirmed());
      await first;
      expect(fixture.remote.createCalls, 1);
    });

    test('legacy equality draft remains readable but cannot publish', () async {
      final fixture = _Fixture();
      final instant = DateTime.utc(2026, 9, 2, 1);
      final local = await fixture.repository.createLocalDraft(
        LocalWorkOrderDraft(
          vehicleId: 'B1023',
          taskType: 'Inspection',
          description: 'Legacy equality draft',
          priority: WorkOrderPriority.high,
          scheduledStart: instant,
          scheduledEnd: instant,
          createdByLabel: 'Staff A',
          allowLegacyScheduleEquality: true,
        ),
      );

      expect(
        (await fixture.repository.readLocalWorkItem(local.localId))
            ?.draft
            .hasLegacyScheduleEquality,
        isTrue,
      );
      await expectLater(
        fixture.repository.publishLocalDraft(local.localId),
        throwsA(isA<WorkOrderValidationException>()),
      );
      expect(fixture.remote.createCalls, 0);
    });

    test(
      'passes restricted update values and expected remote version',
      () async {
        final fixture = _Fixture();
        fixture.remote.updateResult = _confirmed(version: 3);
        final input = WorkOrderUpdateInput(
          vehicleId: ' B1023 ',
          taskType: ' Inspection ',
          description: ' Inspect after Route 300 breakdown ',
          priority: WorkOrderPriority.urgent,
        );

        final result = await fixture.repository.updateConfirmed(
          'WO-0001',
          input,
          expectedVersion: 2,
        );

        expect(fixture.remote.updatedInput, same(input));
        expect(fixture.remote.expectedVersion, 2);
        expect(result.remoteVersion, 3);
      },
    );

    test('validates transitions before contacting remote authority', () async {
      final fixture = _Fixture();

      await expectLater(
        fixture.repository.transitionConfirmed(
          'WO-0001',
          fromStatus: WorkOrderStatus.completed,
          toStatus: WorkOrderStatus.open,
          expectedVersion: 2,
        ),
        throwsA(isA<WorkOrderValidationException>()),
      );

      expect(fixture.remote.transitionCalls, 0);
    });

    test('uses enum statuses and version for remote transition', () async {
      final fixture = _Fixture();
      fixture.remote.records = [
        _confirmed(
          status: WorkOrderStatus.assigned,
          assignedTo: 'Technician A',
          version: 3,
        ),
      ];
      fixture.remote.transitionResult = _confirmed(
        status: WorkOrderStatus.inProgress,
        assignedTo: 'Technician A',
        version: 4,
      );

      await fixture.repository.transitionConfirmed(
        'WO-0001',
        fromStatus: WorkOrderStatus.assigned,
        toStatus: WorkOrderStatus.inProgress,
        expectedVersion: 3,
      );

      expect(fixture.remote.toStatus, WorkOrderStatus.inProgress);
      expect(fixture.remote.expectedVersion, 3);
    });

    test('legacy equality record can be cancelled and hydrated', () async {
      final fixture = _Fixture();
      final instant = DateTime.utc(2026, 9, 2, 1);
      fixture.remote.transitionResult = _confirmed(
        status: WorkOrderStatus.cancelled,
        version: 3,
        scheduledStart: instant,
        scheduledEnd: instant,
        allowLegacyScheduleEquality: true,
      );

      final result = await fixture.repository.transitionConfirmed(
        'WO-0001',
        fromStatus: WorkOrderStatus.draft,
        toStatus: WorkOrderStatus.cancelled,
        expectedVersion: 2,
      );

      expect(fixture.remote.transitionCalls, 1);
      expect(fixture.remote.toStatus, WorkOrderStatus.cancelled);
      expect(result.status, WorkOrderStatus.cancelled);
      expect(result.hasLegacyScheduleEquality, isTrue);
    });
  });
}

class _Fixture {
  _Fixture() {
    remote = _FakeRemote();
    local = _FakeLocal();
    repository = HybridWorkOrderRepository(
      remoteDataSource: remote,
      localDataSource: local,
      clock: () => DateTime.utc(2026, 8, 30, 12),
    );
  }

  late final _FakeRemote remote;
  late final _FakeLocal local;
  late final HybridWorkOrderRepository repository;
}

class _FakeRemote implements WorkOrderRemoteDataSource {
  List<WorkOrderRecordDto> records = [];
  Object? readError;
  Object? createError;
  WorkOrderRecordDto? createResult;
  Completer<WorkOrderRecordDto>? createCompleter;
  WorkOrderRecordDto? updateResult;
  WorkOrderRecordDto? transitionResult;
  LocalWorkOrderDraft? createdDraft;
  String? publicationKey;
  WorkOrderUpdateInput? updatedInput;
  WorkOrderStatus? toStatus;
  int? expectedVersion;
  int createCalls = 0;
  int transitionCalls = 0;

  @override
  Future<List<WorkOrderRecordDto>> fetchAll() async {
    if (readError case final error?) throw error;
    return records;
  }

  @override
  Future<WorkOrderRecordDto?> fetchById(String workOrderId) async {
    if (readError case final error?) throw error;
    return records.where((item) => item.workOrderId == workOrderId).firstOrNull;
  }

  @override
  Future<WorkOrderRecordDto> create(
    String publicationKey,
    LocalWorkOrderDraft draft,
  ) async {
    createCalls++;
    this.publicationKey = publicationKey;
    createdDraft = draft;
    if (createError case final error?) throw error;
    return createCompleter?.future ?? createResult ?? _confirmed();
  }

  @override
  Future<WorkOrderRecordDto> update(
    String workOrderId,
    WorkOrderUpdateInput input, {
    required int expectedVersion,
  }) async {
    updatedInput = input;
    this.expectedVersion = expectedVersion;
    return updateResult ?? _confirmed();
  }

  @override
  Future<WorkOrderRecordDto> assign(
    String workOrderId, {
    required String assignedTo,
    required int expectedVersion,
  }) async {
    this.expectedVersion = expectedVersion;
    return _confirmed(status: WorkOrderStatus.assigned, assignedTo: assignedTo);
  }

  @override
  Future<WorkOrderRecordDto> transitionStatus(
    String workOrderId, {
    required WorkOrderStatus toStatus,
    required int expectedVersion,
  }) async {
    transitionCalls++;
    this.toStatus = toStatus;
    this.expectedVersion = expectedVersion;
    return transitionResult ?? _confirmed(status: toStatus);
  }
}

class _FakeLocal implements WorkOrderLocalDataSource {
  List<LocalWorkOrderRecord> cached = [];
  List<LocalWorkOrderRecord> local = [];
  Object? upsertError;
  int _nextId = 1;

  @override
  Future<void> upsertConfirmedCache(
    Iterable<WorkOrderRecordDto> records, {
    required DateTime retrievedAtUtc,
  }) async {
    if (upsertError case final error?) throw error;
    cached = records.map((item) => _cached(item)).toList();
  }

  @override
  Future<List<LocalWorkOrderRecord>> readConfirmedCacheRecords() async =>
      cached;
  @override
  Future<LocalWorkOrderRecord?> readConfirmedCacheRecordById(String id) async =>
      cached.where((item) => item.workOrderId == id).firstOrNull;
  @override
  Future<List<WorkOrderRecordDto>> readConfirmedCache() async =>
      cached.map((item) => item.toConfirmedDto()).toList();
  @override
  Future<WorkOrderRecordDto?> readConfirmedCacheById(String id) async =>
      (await readConfirmedCacheRecordById(id))?.toConfirmedDto();
  @override
  Future<List<LocalWorkOrderRecord>> readLocalWorkItems() async => local;
  @override
  Future<LocalWorkOrderRecord?> readLocalWorkItem(String id) async =>
      local.where((item) => item.localId == id).firstOrNull;

  @override
  Future<LocalWorkOrderRecord> createDraft(LocalWorkOrderDraft draft) async {
    final record = _localRecord('local-${_nextId++}', draft);
    local.add(record);
    return record;
  }

  @override
  Future<LocalWorkOrderRecord> updateDraft(
    String localId,
    LocalWorkOrderDraft draft,
  ) async {
    final index = local.indexWhere((item) => item.localId == localId);
    final record = _localRecord(localId, draft);
    local[index] = record;
    return record;
  }

  @override
  Future<LocalWorkOrderRecord> markPendingPublication(String localId) async =>
      _setState(localId, LocalSyncState.pendingPublication);

  @override
  Future<LocalWorkOrderRecord> markPublicationFailure(
    String localId,
    String safeMessage,
  ) async => _setState(
    localId,
    LocalSyncState.publicationFailed,
    safeMessage: safeMessage,
  );

  @override
  Future<LocalWorkOrderRecord> markConflict(
    String localId,
    String safeMessage,
  ) async =>
      _setState(localId, LocalSyncState.conflict, safeMessage: safeMessage);

  @override
  Future<LocalWorkOrderRecord> applyPublicationSuccess(
    String localId,
    WorkOrderRecordDto confirmedRecord, {
    required DateTime retrievedAtUtc,
  }) async {
    final index = local.indexWhere((item) => item.localId == localId);
    final confirmed = _cached(confirmedRecord, localId: localId);
    local.removeAt(index);
    cached = [confirmed];
    return confirmed;
  }

  @override
  Future<void> discardLocalDraft(String localId) async {
    local.removeWhere((item) => item.localId == localId);
  }

  LocalWorkOrderRecord _setState(
    String localId,
    LocalSyncState state, {
    String? safeMessage,
  }) {
    final index = local.indexWhere((item) => item.localId == localId);
    final old = local[index];
    final updated = LocalWorkOrderRecord(
      localId: old.localId,
      ownerUserId: old.ownerUserId,
      createdByUserId: old.createdByUserId,
      draft: old.draft,
      status: WorkOrderStatus.draft,
      syncState: state,
      localCreatedAt: old.localCreatedAt,
      localModifiedAt: old.localModifiedAt.add(const Duration(minutes: 1)),
      safeErrorMessage: safeMessage,
    );
    local[index] = updated;
    return updated;
  }
}

LocalWorkOrderDraft _draft() => LocalWorkOrderDraft(
  incidentId: 'INC-300',
  recommendationId: 'REC-INSPECT-B1023',
  routeId: '300',
  vehicleId: 'B1023',
  taskType: 'Inspection',
  description: 'Inspect Bus B1023 after its Route 300 breakdown.',
  priority: WorkOrderPriority.urgent,
  createdByLabel: 'Demonstration staff',
);

LocalWorkOrderRecord _localRecord(String id, LocalWorkOrderDraft draft) =>
    LocalWorkOrderRecord(
      localId: id,
      ownerUserId: '11111111-1111-4111-8111-111111111111',
      createdByUserId: '11111111-1111-4111-8111-111111111111',
      draft: draft,
      status: WorkOrderStatus.draft,
      syncState: LocalSyncState.localDraft,
      localCreatedAt: DateTime.utc(2026, 8, 30, 10),
      localModifiedAt: DateTime.utc(2026, 8, 30, 10),
    );

LocalWorkOrderRecord _cached(
  WorkOrderRecordDto dto, {
  String localId = 'cache-1',
}) => LocalWorkOrderRecord(
  localId: localId,
  ownerUserId: '11111111-1111-4111-8111-111111111111',
  createdByUserId: dto.createdByUserId,
  draft: LocalWorkOrderDraft(
    incidentId: dto.incidentId,
    recommendationId: dto.recommendationId,
    routeId: dto.routeId,
    vehicleId: dto.vehicleId,
    taskType: dto.taskType,
    description: dto.description,
    priority: dto.priority,
    scheduledStart: dto.scheduledStart,
    scheduledEnd: dto.scheduledEnd,
    notes: dto.notes,
    createdByLabel: dto.createdByLabel,
    allowLegacyScheduleEquality: dto.hasLegacyScheduleEquality,
  ),
  status: dto.status,
  syncState: LocalSyncState.cachedRemote,
  remoteStorageId: dto.storageId,
  workOrderId: dto.workOrderId,
  assignedTo: dto.assignedTo,
  remoteCreatedAt: dto.createdAt,
  remoteUpdatedAt: dto.updatedAt,
  completedAt: dto.completedAt,
  cancelledAt: dto.cancelledAt,
  remoteVersion: dto.remoteVersion,
  retrievedAt: DateTime.utc(2026, 8, 30, 12),
  localCreatedAt: DateTime.utc(2026, 8, 30, 10),
  localModifiedAt: DateTime.utc(2026, 8, 30, 12),
);

WorkOrderRecordDto _confirmed({
  WorkOrderStatus status = WorkOrderStatus.open,
  String? assignedTo,
  int version = 2,
  DateTime? scheduledStart,
  DateTime? scheduledEnd,
  bool allowLegacyScheduleEquality = false,
}) => WorkOrderRecordDto(
  storageId: '22222222-2222-4222-8222-222222222222',
  workOrderId: 'WO-0001',
  incidentId: 'INC-300',
  recommendationId: 'REC-INSPECT-B1023',
  routeId: '300',
  vehicleId: 'B1023',
  taskType: 'Inspection',
  description: 'Inspect Bus B1023 after its Route 300 breakdown.',
  priority: WorkOrderPriority.urgent,
  assignedTo: assignedTo,
  scheduledStart: scheduledStart,
  scheduledEnd: scheduledEnd,
  status: status,
  createdByUserId: '33333333-3333-4333-8333-333333333333',
  createdByLabel: 'Operations staff',
  createdAt: DateTime.utc(2026, 8, 30, 10),
  updatedAt: DateTime.utc(2026, 8, 30, 11),
  cancelledAt: status == WorkOrderStatus.cancelled
      ? DateTime.utc(2026, 8, 30, 11)
      : null,
  remoteVersion: version,
  allowLegacyScheduleEquality: allowLegacyScheduleEquality,
);
