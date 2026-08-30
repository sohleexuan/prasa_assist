import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/work_orders/controllers/work_orders_controller.dart';
import 'package:prasa_assist/features/work_orders/data/in_memory_work_order_repository.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_draft.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_record.dart';
import 'package:prasa_assist/features/work_orders/data/dto/work_order_update_input.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/models/work_order_read_result.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_hybrid_operations.dart';
import 'package:prasa_assist/core/database/local_sync_state.dart';

void main() {
  final operationTime = DateTime(2026, 8, 28, 10, 30);

  test('loads local records and creates a normalized draft', () async {
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: []),
    );
    await controller.load();

    final created = await controller.createDraft(
      vehicleId: ' B1023 ',
      taskType: ' Inspection ',
      description: ' Inspect Route 300 breakdown ',
      priority: WorkOrderPriority.urgent,
      notes: '   ',
      createdBy: ' Staff A ',
    );

    expect(created.status, WorkOrderStatus.draft);
    expect(created.vehicleId, 'B1023');
    expect(created.notes, isNull);
    expect(controller.workOrders, hasLength(1));
  });

  test(
    'createDraft preserves optional incident and recommendation IDs',
    () async {
      final controller = WorkOrdersController(
        InMemoryWorkOrderRepository(initialWorkOrders: []),
      );
      addTearDown(controller.dispose);
      await controller.load();

      final created = await controller.createDraft(
        incidentId: ' INC-1 ',
        recommendationId: ' REC-1 ',
        vehicleId: 'B1023',
        taskType: 'Inspection',
        description: 'Inspect Route 300 breakdown.',
        priority: WorkOrderPriority.urgent,
        createdBy: 'Staff A',
      );

      expect(created.incidentId, 'INC-1');
      expect(created.recommendationId, 'REC-1');
      expect(created.createdByUserId, isNull);
    },
  );

  test('updates an eligible local record', () async {
    final now = DateTime(2026, 8, 27);
    final original = WorkOrder(
      workOrderId: 'WO-1',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Original',
      priority: WorkOrderPriority.high,
      status: WorkOrderStatus.draft,
      createdByUserId: '11111111-1111-4111-8111-111111111111',
      createdBy: 'Staff A',
      createdAt: now,
      updatedAt: now,
    );
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: [original]),
    );
    await controller.load();

    await controller.updateEligible(
      original: original,
      vehicleId: 'B1023',
      taskType: 'Vehicle inspection',
      description: 'Updated description',
      priority: WorkOrderPriority.urgent,
    );

    expect(controller.findById('WO-1')?.description, 'Updated description');
  });

  test('does not edit a terminal record', () async {
    final now = DateTime(2026, 8, 27);
    final completed = WorkOrder(
      workOrderId: 'WO-1',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Done',
      priority: WorkOrderPriority.high,
      assignedTo: 'Staff B',
      status: WorkOrderStatus.completed,
      createdByUserId: '11111111-1111-4111-8111-111111111111',
      createdBy: 'Staff A',
      createdAt: now,
      updatedAt: now,
      completedAt: now,
    );
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: [completed]),
    );
    await controller.load();

    expect(
      () => controller.updateEligible(
        original: completed.copyWith(status: WorkOrderStatus.draft),
        vehicleId: 'B1023',
        taskType: 'Inspection',
        description: 'Changed',
        priority: WorkOrderPriority.high,
      ),
      throwsA(anyOf(isA<StateError>(), isA<WorkOrderValidationException>())),
    );
    expect(controller.workOrders, hasLength(1));
    expect(controller.workOrders.single.status, WorkOrderStatus.completed);
  });

  test('enforces the full workflow and uses one operation timestamp', () async {
    final repository = InMemoryWorkOrderRepository(
      initialWorkOrders: [_readyRecord()],
    );
    final controller = WorkOrdersController(
      repository,
      now: () => operationTime,
    );
    await controller.load();

    await controller.openWorkOrder('WO-1');
    expect(controller.findById('WO-1')?.status, WorkOrderStatus.open);

    await controller.assignWorkOrder('WO-1', assignedTo: '  Staff B  ');
    expect(controller.findById('WO-1')?.assignedTo, 'Staff B');
    expect(controller.findById('WO-1')?.status, WorkOrderStatus.assigned);

    await controller.startWork('WO-1');
    expect(controller.findById('WO-1')?.status, WorkOrderStatus.inProgress);

    final completed = await controller.completeWork('WO-1');
    expect(completed.status, WorkOrderStatus.completed);
    expect(completed.updatedAt, operationTime.toUtc());
    expect(completed.completedAt, operationTime.toUtc());
    expect(completed.cancelledAt, isNull);
  });

  test('cancels every non-terminal status and retains the record', () async {
    for (final status in WorkOrderStatus.values.where(
      (status) => !status.isTerminal,
    )) {
      final record = _readyRecord(
        status: status,
        assignedTo:
            status == WorkOrderStatus.assigned ||
                status == WorkOrderStatus.inProgress ||
                status == WorkOrderStatus.completed
            ? 'Staff B'
            : null,
      );
      final controller = WorkOrdersController(
        InMemoryWorkOrderRepository(initialWorkOrders: [record]),
        now: () => operationTime,
      );
      await controller.load();

      final cancelled = await controller.cancelWorkOrder('WO-1');

      expect(cancelled.status, WorkOrderStatus.cancelled);
      expect(cancelled.cancelledAt, operationTime.toUtc());
      expect(cancelled.completedAt, isNull);
      expect(controller.workOrders, hasLength(1));
      controller.dispose();
    }
  });

  test('rejects skipped and terminal transitions without mutation', () async {
    final repository = InMemoryWorkOrderRepository(
      initialWorkOrders: [_readyRecord()],
    );
    final controller = WorkOrdersController(repository);
    await controller.load();

    await expectLater(
      controller.assignWorkOrder('WO-1', assignedTo: 'Staff B'),
      throwsA(isA<WorkOrderValidationException>()),
    );
    final unchanged = await repository.read('WO-1');
    expect(unchanged?.status, WorkOrderStatus.draft);
    expect(unchanged?.assignedTo, isNull);

    final terminalRepository = InMemoryWorkOrderRepository(
      initialWorkOrders: [_readyRecord(status: WorkOrderStatus.completed)],
    );
    final terminalController = WorkOrdersController(terminalRepository);
    await terminalController.load();
    await expectLater(
      terminalController.cancelWorkOrder('WO-1'),
      throwsA(isA<WorkOrderValidationException>()),
    );
    expect(
      (await terminalRepository.read('WO-1'))?.status,
      WorkOrderStatus.completed,
    );
  });

  test(
    'validates required schedule and assignment before transitions',
    () async {
      final missingSchedule = _readyRecord(includeSchedule: false);
      final controller = WorkOrdersController(
        InMemoryWorkOrderRepository(initialWorkOrders: [missingSchedule]),
      );
      await controller.load();
      await expectLater(
        controller.openWorkOrder('WO-1'),
        throwsA(isA<WorkOrderValidationException>()),
      );

      final open = _readyRecord(status: WorkOrderStatus.open);
      final assignmentController = WorkOrdersController(
        InMemoryWorkOrderRepository(initialWorkOrders: [open]),
      );
      await assignmentController.load();
      await expectLater(
        assignmentController.assignWorkOrder('WO-1', assignedTo: '   '),
        throwsA(isA<WorkOrderValidationException>()),
      );
      expect(
        assignmentController.findById('WO-1')?.status,
        WorkOrderStatus.open,
      );
    },
  );

  test(
    'filters status and searches all approved fields case-insensitively',
    () async {
      final controller = WorkOrdersController(
        InMemoryWorkOrderRepository(
          initialWorkOrders: [
            _readyRecord(),
            _readyRecord(
              workOrderId: 'WO-2',
              vehicleId: 'B2040',
              taskType: 'Brake repair',
              description: 'Replace brake pads',
              assignedTo: 'Aina Rahman',
              status: WorkOrderStatus.assigned,
            ),
          ],
        ),
      );
      await controller.load();

      for (final query in [
        'wo-2',
        'b2040',
        'BRAKE REPAIR',
        'brake pads',
        'aina',
      ]) {
        controller.setSearchQuery('  $query  ');
        expect(controller.visibleWorkOrders.single.workOrderId, 'WO-2');
      }
      controller.setSearchQuery('');
      controller.setStatusFilter(WorkOrderStatus.draft);
      expect(controller.visibleWorkOrders.single.workOrderId, 'WO-1');
      controller.setSearchQuery('b2040');
      expect(controller.visibleWorkOrders, isEmpty);
      controller.clearFilters();
      expect(controller.visibleWorkOrders, hasLength(2));
    },
  );

  test('hybrid drafts save locally and publish only when staff requests it', () async {
    final operations = _HybridOperationsFake();
    final controller = WorkOrdersController.hybrid(operations);
    addTearDown(controller.dispose);

    await controller.load();
    expect(operations.publicationCalls, 0);

    final draft = await controller.createDraft(
      incidentId: 'INC-B1023',
      recommendationId: 'REC-B1023',
      vehicleId: ' B1023 ',
      taskType: ' Inspection ',
      description: ' Inspect Route 300 breakdown ',
      priority: WorkOrderPriority.urgent,
    );
    expect(operations.createDraftCalls, 1);
    expect(draft.incidentId, 'INC-B1023');
    expect(draft.recommendationId, 'REC-B1023');
    expect(operations.publicationCalls, 0);

    final confirmed = await controller.publishLocalDraft(draft.workOrderId);
    expect(operations.publicationCalls, 1);
    expect(operations.publicationKeys, ['local-1']);
    expect(confirmed.remoteVersion, 1);
  });
}

class _HybridOperationsFake implements WorkOrderHybridOperations {
  final List<LocalWorkOrderRecord> _local = [];
  int createDraftCalls = 0;
  int publicationCalls = 0;
  final List<String> publicationKeys = [];

  @override
  Future<WorkOrderReadResult<List<WorkOrder>>> readAllWithProvenance() async =>
      WorkOrderReadResult(
        data: const [],
        provenance: WorkOrderReadProvenance(
          source: WorkOrderReadSource.liveSupabase,
          retrievedAtUtc: DateTime.utc(2026, 8, 30),
        ),
      );

  @override
  Future<List<LocalWorkOrderRecord>> readLocalWorkItems() async =>
      List.unmodifiable(_local);

  @override
  Future<LocalWorkOrderRecord> createLocalDraft(LocalWorkOrderDraft draft) async {
    createDraftCalls++;
    final record = LocalWorkOrderRecord(
      localId: 'local-$createDraftCalls',
      ownerUserId: '11111111-1111-4111-8111-111111111111',
      createdByUserId: '11111111-1111-4111-8111-111111111111',
      draft: draft,
      status: WorkOrderStatus.draft,
      syncState: LocalSyncState.localDraft,
      localCreatedAt: DateTime.utc(2026, 8, 30),
      localModifiedAt: DateTime.utc(2026, 8, 30),
    );
    _local.add(record);
    return record;
  }

  @override
  Future<WorkOrder> publishLocalDraft(String localId) async {
    publicationCalls++;
    publicationKeys.add(localId);
    _local.removeWhere((record) => record.localId == localId);
    return WorkOrder(
      workOrderId: 'WO-000001',
      incidentId: 'INC-B1023',
      recommendationId: 'REC-B1023',
      vehicleId: 'B1023',
      taskType: 'Inspection',
      description: 'Inspect Route 300 breakdown',
      priority: WorkOrderPriority.urgent,
      status: WorkOrderStatus.draft,
      createdByUserId: '11111111-1111-4111-8111-111111111111',
      createdBy: 'staff@example.test',
      createdAt: DateTime.utc(2026, 8, 30),
      updatedAt: DateTime.utc(2026, 8, 30),
      remoteVersion: 1,
    );
  }

  @override
  Future<LocalWorkOrderRecord> updateLocalDraft(String localId, LocalWorkOrderDraft draft) => throw UnimplementedError();
  @override
  Future<void> discardLocalDraft(String localId) => throw UnimplementedError();
  @override
  Future<WorkOrder> updateConfirmed(String workOrderId, WorkOrderUpdateInput input, {required int expectedVersion}) => throw UnimplementedError();
  @override
  Future<WorkOrder> assignConfirmed(String workOrderId, {required String assignedTo, required int expectedVersion}) => throw UnimplementedError();
  @override
  Future<WorkOrder> transitionConfirmed(String workOrderId, {required WorkOrderStatus fromStatus, required WorkOrderStatus toStatus, required int expectedVersion}) => throw UnimplementedError();
  @override
  Future<LocalWorkOrderRecord?> readLocalWorkItem(String localId) async {
    for (final record in _local) {
      if (record.localId == localId) return record;
    }
    return null;
  }
  @override
  Future<WorkOrderReadResult<WorkOrder?>> readWithProvenance(String workOrderId) => throw UnimplementedError();
}

WorkOrder _readyRecord({
  String workOrderId = 'WO-1',
  String vehicleId = 'B1023',
  String taskType = 'Inspection',
  String description = 'Inspect Route 300 breakdown',
  String? assignedTo,
  WorkOrderStatus status = WorkOrderStatus.draft,
  DateTime? scheduledStart,
  DateTime? scheduledEnd,
  bool includeSchedule = true,
}) {
  final createdAt = DateTime(2026, 8, 27, 9);
  return WorkOrder(
    workOrderId: workOrderId,
    vehicleId: vehicleId,
    taskType: taskType,
    description: description,
    priority: WorkOrderPriority.high,
    assignedTo:
        assignedTo ??
        (status == WorkOrderStatus.assigned ||
                status == WorkOrderStatus.inProgress ||
                status == WorkOrderStatus.completed
            ? 'Staff B'
            : null),
    scheduledStart: includeSchedule
        ? scheduledStart ?? DateTime(2026, 8, 28, 9)
        : null,
    scheduledEnd: includeSchedule
        ? scheduledEnd ?? DateTime(2026, 8, 28, 11)
        : null,
    status: status,
    createdByUserId: '11111111-1111-4111-8111-111111111111',
    createdBy: 'Staff A',
    createdAt: createdAt,
    updatedAt: createdAt,
    completedAt: status == WorkOrderStatus.completed ? createdAt : null,
    cancelledAt: status == WorkOrderStatus.cancelled ? createdAt : null,
  );
}
