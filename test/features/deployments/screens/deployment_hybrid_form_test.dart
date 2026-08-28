import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/local_sync_state.dart';
import 'package:prasa_assist/features/deployments/controllers/deployment_controller.dart';
import 'package:prasa_assist/features/deployments/controllers/route_catalog_controller.dart';
import 'package:prasa_assist/features/deployments/data/dto/local_deployment_draft.dart';
import 'package:prasa_assist/features/deployments/data/dto/local_deployment_record.dart';
import 'package:prasa_assist/features/deployments/models/deployment_read_result.dart';
import 'package:prasa_assist/features/deployments/models/deployment_status.dart';
import 'package:prasa_assist/features/deployments/models/service_deployment.dart';
import 'package:prasa_assist/features/deployments/repositories/bundled_route_catalog_repository.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_hybrid_operations.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_repository.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_repository_capabilities.dart';
import 'package:prasa_assist/features/deployments/screens/deployment_form_screen.dart';

void main() {
  testWidgets(
    'hybrid create saves a genuine local draft without fabricated server data',
    (tester) async {
      final repository = _FormHybridRepository();
      final controller = DeploymentController(repository: repository);
      addTearDown(controller.dispose);
      final routeController = RouteCatalogController(
        const BundledRouteCatalogRepository(),
      );
      addTearDown(routeController.dispose);
      LocalDeploymentRecord? saved;

      await tester.pumpWidget(
        MaterialApp(
          home: DeploymentFormScreen(
            controller: controller,
            routeCatalogController: routeController,
            currentUserId: 'staff@example.com',
            onLocalSaved: (record) => saved = record,
            clock: () => DateTime(2026, 8, 28, 4, 40),
          ),
        ),
      );

      expect(find.text('Assigned after publication'), findsOneWidget);
      expect(
        find.text('Local draft — stored on this device, not published'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('schedule-deployment-button')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const ValueKey('route-id-field')),
        '300',
      );
      await tester.enterText(
        find.byKey(const ValueKey('route-name-field')),
        'Terminal Maluri ~ Lebuh Ampang',
      );
      await tester.enterText(
        find.byKey(const ValueKey('vehicle-ids-field')),
        'REPLACEMENT-BUS-01, REPLACEMENT-BUS-02',
      );
      await tester.enterText(
        find.byKey(const ValueKey('purpose-field')),
        'Replace unavailable Bus B1023',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('save-draft-button')),
      );
      await tester.tap(find.byKey(const ValueKey('save-draft-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(saved?.localId, 'local-1');
      expect(saved?.deploymentCode, isNull);
      expect(saved?.remoteStorageId, isNull);
      expect(saved?.createdByLabel, isNull);
      expect(saved?.remoteCreatedAt, isNull);
      expect(saved?.remoteVersion, isNull);
      expect(saved?.draft.vehicleIds, isNot(contains('B1023')));
      expect(repository.remoteCallCount, 0);
      expect(repository.localItems, hasLength(1));
    },
  );

  testWidgets('hybrid form rejects B1023 as a replacement vehicle', (
    tester,
  ) async {
    final repository = _FormHybridRepository();
    final controller = DeploymentController(repository: repository);
    addTearDown(controller.dispose);
    final routeController = RouteCatalogController(
      const BundledRouteCatalogRepository(),
    );
    addTearDown(routeController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DeploymentFormScreen(
          controller: controller,
          routeCatalogController: routeController,
          currentUserId: 'staff@example.com',
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('vehicle-ids-field')),
      'B1023',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save-draft-button')));
    await tester.tap(find.byKey(const ValueKey('save-draft-button')));
    await tester.pump();

    expect(
      find.text('Unavailable Bus B1023 cannot be a replacement vehicle.'),
      findsOneWidget,
    );
    expect(repository.remoteCallCount, 0);
  });
}

class _FormHybridRepository
    implements
        DeploymentRepository,
        DeploymentRepositoryCapabilitiesProvider,
        DeploymentHybridOperations {
  List<LocalDeploymentRecord> localItems = const [];
  int remoteCallCount = 0;

  @override
  DeploymentRepositoryCapabilities get capabilities =>
      const DeploymentRepositoryCapabilities.persistent();

  @override
  Future<LocalDeploymentRecord> createLocalDraft(
    LocalDeploymentDraft draft,
  ) async {
    final record = _localRecord(draft);
    localItems = [record];
    return record;
  }

  @override
  Future<LocalDeploymentRecord> updateLocalDraft(
    String localId,
    LocalDeploymentDraft draft,
  ) async {
    final record = _localRecord(draft);
    localItems = [record];
    return record;
  }

  @override
  Future<List<LocalDeploymentRecord>> getLocalWorkItems() async => localItems;

  @override
  Future<LocalDeploymentRecord?> getLocalWorkItem(String localId) async {
    return localItems.isEmpty ? null : localItems.single;
  }

  @override
  Future<void> discardLocalDraft(String localId) async {
    localItems = const [];
  }

  Never _unexpectedRemote() {
    remoteCallCount++;
    throw StateError('Remote operation must not run while saving a draft.');
  }

  @override
  Future<List<ServiceDeployment>> getAll() async => _unexpectedRemote();

  @override
  Future<ServiceDeployment?> getById(String deploymentId) async =>
      _unexpectedRemote();

  @override
  Future<DeploymentReadResult<List<ServiceDeployment>>>
  getAllWithProvenance() async => _unexpectedRemote();

  @override
  Future<DeploymentReadResult<ServiceDeployment?>> getByIdWithProvenance(
    String deploymentId,
  ) async => _unexpectedRemote();

  @override
  Future<ServiceDeployment> create(ServiceDeployment deployment) async =>
      _unexpectedRemote();

  @override
  Future<ServiceDeployment> update(ServiceDeployment deployment) async =>
      _unexpectedRemote();

  @override
  Future<void> delete(String deploymentId) async => _unexpectedRemote();

  @override
  Future<ServiceDeployment> transitionStatus(
    String deploymentCode,
    DeploymentStatus targetStatus, {
    required String changedByLabel,
    DateTime? changedAt,
  }) async => _unexpectedRemote();

  @override
  Future<ServiceDeployment> publishLocalDraft(String localId) async =>
      _unexpectedRemote();
}

LocalDeploymentRecord _localRecord(LocalDeploymentDraft draft) {
  return LocalDeploymentRecord(
    localId: 'local-1',
    ownerUserId: '11111111-1111-4111-8111-111111111111',
    draft: draft,
    status: 'draft',
    syncState: LocalSyncState.localDraft,
    localCreatedAt: DateTime.utc(2026, 8, 28),
    localModifiedAt: DateTime.utc(2026, 8, 28),
  );
}
