import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/local_sync_state.dart';
import 'package:prasa_assist/features/deployments/controllers/deployment_controller.dart';
import 'package:prasa_assist/features/deployments/data/dto/local_deployment_draft.dart';
import 'package:prasa_assist/features/deployments/data/dto/local_deployment_record.dart';
import 'package:prasa_assist/features/deployments/models/deployment_read_result.dart';
import 'package:prasa_assist/features/deployments/models/deployment_status.dart';
import 'package:prasa_assist/features/deployments/models/service_deployment.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_hybrid_operations.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_repository.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_repository_capabilities.dart';

void main() {
  test(
    'loads provenance and unpublished work through repository boundaries',
    () async {
      final repository = _HybridRepository()
        ..readSource = DeploymentReadSource.cachedSqlite
        ..localItems = [_localRecord()];
      final controller = DeploymentController(repository: repository);
      addTearDown(controller.dispose);

      await controller.loadDeployments();

      expect(controller.deployments.single.deploymentId, 'DEP-120');
      expect(controller.localWorkItems.single.localId, 'local-1');
      expect(
        controller.listProvenance?.source,
        DeploymentReadSource.cachedSqlite,
      );
      expect(controller.supportsLocalDrafts, isTrue);
      expect(repository.readCount, 1);

      await controller.getDeploymentById('DEP-120');
      expect(
        controller.detailProvenance?.source,
        DeploymentReadSource.cachedSqlite,
      );
    },
  );

  test('prevents duplicate controller publication submissions', () async {
    final repository = _HybridRepository()..localItems = [_localRecord()];
    final controller = DeploymentController(repository: repository);
    addTearDown(controller.dispose);
    final completer = Completer<ServiceDeployment>();
    repository.publicationCompleter = completer;

    final first = controller.publishLocalDraft('local-1');
    await _waitFor(() => repository.publishCount == 1);
    expect(await controller.publishLocalDraft('local-1'), isFalse);
    expect(repository.publishCount, 1);

    completer.complete(_deployment());
    expect(await first, isTrue);
    expect(controller.selectedDeployment?.deploymentId, 'DEP-120');
  });

  test('does not render raw unexpected repository details', () async {
    final repository = _HybridRepository()
      ..readError = StateError('raw provider programming detail');
    final controller = DeploymentController(repository: repository);
    addTearDown(controller.dispose);

    await controller.loadDeployments();

    expect(
      controller.errorMessage,
      'Unable to complete the deployment operation.',
    );
    expect(controller.errorMessage, isNot(contains('raw provider')));
  });
}

class _HybridRepository
    implements
        DeploymentRepository,
        DeploymentRepositoryCapabilitiesProvider,
        DeploymentHybridOperations {
  DeploymentReadSource readSource = DeploymentReadSource.liveSupabase;
  List<LocalDeploymentRecord> localItems = const [];
  Object? readError;
  Completer<ServiceDeployment>? publicationCompleter;
  int readCount = 0;
  int publishCount = 0;

  @override
  DeploymentRepositoryCapabilities get capabilities =>
      const DeploymentRepositoryCapabilities.persistent();

  @override
  Future<DeploymentReadResult<List<ServiceDeployment>>>
  getAllWithProvenance() async {
    readCount++;
    if (readError case final error?) {
      throw error;
    }
    return DeploymentReadResult(
      data: [_deployment()],
      provenance: DeploymentReadProvenance(
        source: readSource,
        retrievedAtUtc: DateTime.utc(2026, 8, 28, 3),
      ),
    );
  }

  @override
  Future<DeploymentReadResult<ServiceDeployment?>> getByIdWithProvenance(
    String deploymentId,
  ) async {
    return DeploymentReadResult(
      data: _deployment(),
      provenance: DeploymentReadProvenance(
        source: readSource,
        retrievedAtUtc: DateTime.utc(2026, 8, 28, 3),
      ),
    );
  }

  @override
  Future<List<ServiceDeployment>> getAll() async => [_deployment()];

  @override
  Future<ServiceDeployment?> getById(String deploymentId) async =>
      _deployment();

  @override
  Future<List<LocalDeploymentRecord>> getLocalWorkItems() async => localItems;

  @override
  Future<LocalDeploymentRecord?> getLocalWorkItem(String localId) async {
    for (final record in localItems) {
      if (record.localId == localId) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<LocalDeploymentRecord> createLocalDraft(
    LocalDeploymentDraft draft,
  ) async {
    final record = _localRecord(draft: draft);
    localItems = [record];
    return record;
  }

  @override
  Future<LocalDeploymentRecord> updateLocalDraft(
    String localId,
    LocalDeploymentDraft draft,
  ) async {
    final record = _localRecord(draft: draft);
    localItems = [record];
    return record;
  }

  @override
  Future<void> discardLocalDraft(String localId) async {
    localItems = const [];
  }

  @override
  Future<ServiceDeployment> publishLocalDraft(String localId) async {
    publishCount++;
    final completer = publicationCompleter;
    final result = completer == null ? _deployment() : await completer.future;
    localItems = const [];
    return result;
  }

  @override
  Future<ServiceDeployment> create(ServiceDeployment deployment) async =>
      deployment;

  @override
  Future<ServiceDeployment> update(ServiceDeployment deployment) async =>
      deployment;

  @override
  Future<void> delete(String deploymentId) async {}

  @override
  Future<ServiceDeployment> transitionStatus(
    String deploymentCode,
    DeploymentStatus targetStatus, {
    required String changedByLabel,
    DateTime? changedAt,
  }) async => _deployment().copyWith(status: targetStatus);
}

LocalDeploymentRecord _localRecord({LocalDeploymentDraft? draft}) {
  return LocalDeploymentRecord(
    localId: 'local-1',
    ownerUserId: '11111111-1111-4111-8111-111111111111',
    draft: draft ?? _draft(),
    status: 'draft',
    syncState: LocalSyncState.localDraft,
    localCreatedAt: DateTime.utc(2026, 8, 28),
    localModifiedAt: DateTime.utc(2026, 8, 28),
  );
}

LocalDeploymentDraft _draft() {
  return LocalDeploymentDraft(
    routeId: '300',
    routeName: 'Terminal Maluri ~ Lebuh Ampang',
    vehicleIds: const ['REPLACEMENT-BUS-01', 'REPLACEMENT-BUS-02'],
    startTime: DateTime.utc(2026, 8, 27, 20, 40),
    endTime: DateTime.utc(2026, 8, 27, 21, 40),
    purpose: 'Replacement service',
  );
}

ServiceDeployment _deployment() {
  return ServiceDeployment(
    deploymentId: 'DEP-120',
    routeId: '300',
    routeName: 'Terminal Maluri ~ Lebuh Ampang',
    vehicleIds: const ['REPLACEMENT-BUS-01', 'REPLACEMENT-BUS-02'],
    startTime: DateTime.utc(2026, 8, 27, 20, 40),
    endTime: DateTime.utc(2026, 8, 27, 21, 40),
    status: DeploymentStatus.draft,
    purpose: 'Replacement service',
    createdBy: '11111111-1111-4111-8111-111111111111',
    createdAt: DateTime.utc(2026, 8, 27, 20),
    updatedAt: DateTime.utc(2026, 8, 27, 20),
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('Timed out waiting for controller publication.');
}
