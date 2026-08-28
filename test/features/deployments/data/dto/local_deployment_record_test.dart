import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/local_sync_state.dart';
import 'package:prasa_assist/features/deployments/data/dto/local_deployment_draft.dart';
import 'package:prasa_assist/features/deployments/data/dto/local_deployment_record.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_data_exception.dart';

void main() {
  group('LocalDeploymentDraft', () {
    test('normalizes editable values and UTC instants only', () {
      final draft = _draft();

      expect(draft.routeId, '300');
      expect(draft.vehicleIds, ['REPLACEMENT-BUS-01', 'REPLACEMENT-BUS-02']);
      expect(draft.startTime.isUtc, isTrue);
      expect(draft.endTime.isUtc, isTrue);
      expect(draft.vehicleIds, isNot(contains('B1023')));
    });

    test('reuses domain timing and vehicle validation', () {
      expect(
        () => _draft(
          startTime: DateTime.utc(2026, 8, 28, 2),
          endTime: DateTime.utc(2026, 8, 28, 1),
        ),
        throwsA(isA<DeploymentValidationException>()),
      );
      expect(
        () => _draft(vehicleIds: const []),
        throwsA(isA<DeploymentValidationException>()),
      );
    });
  });

  group('LocalDeploymentRecord', () {
    test('unpublished draft has no server-owned values', () {
      final record = LocalDeploymentRecord(
        localId: 'local-1',
        ownerUserId: _ownerId,
        draft: _draft(),
        status: 'draft',
        syncState: LocalSyncState.localDraft,
        localCreatedAt: _localTime,
        localModifiedAt: _localTime,
      );

      expect(record.remoteStorageId, isNull);
      expect(record.deploymentCode, isNull);
      expect(record.remoteVersion, isNull);
      expect(record.retrievedAt, isNull);
      expect(
        record.toConfirmedDto,
        throwsA(isA<DeploymentValidationException>()),
      );
    });

    test('rejects invalid state metadata and local chronology', () {
      expect(
        () => LocalDeploymentRecord(
          localId: 'local-1',
          ownerUserId: _ownerId,
          draft: _draft(),
          status: 'draft',
          syncState: LocalSyncState.publicationFailed,
          localCreatedAt: _localTime,
          localModifiedAt: _localTime,
        ),
        throwsA(isA<DeploymentValidationException>()),
      );
      expect(
        () => LocalDeploymentRecord(
          localId: 'local-1',
          ownerUserId: _ownerId,
          draft: _draft(),
          status: 'draft',
          syncState: LocalSyncState.localDraft,
          localCreatedAt: _localTime,
          localModifiedAt: _localTime.subtract(const Duration(minutes: 1)),
        ),
        throwsA(isA<DeploymentValidationException>()),
      );
    });
  });
}

const _ownerId = '11111111-1111-4111-8111-111111111111';
final _localTime = DateTime.utc(2026, 8, 28);

LocalDeploymentDraft _draft({
  List<String> vehicleIds = const [
    ' REPLACEMENT-BUS-01 ',
    'REPLACEMENT-BUS-02',
  ],
  DateTime? startTime,
  DateTime? endTime,
}) {
  return LocalDeploymentDraft(
    routeId: ' 300 ',
    routeName: 'Terminal Maluri ~ Lebuh Ampang',
    vehicleIds: vehicleIds,
    startTime: startTime ?? DateTime.parse('2026-08-28T04:40:00+08:00'),
    endTime: endTime ?? DateTime.parse('2026-08-28T05:40:00+08:00'),
    purpose: 'Replace unavailable Bus B1023',
    incidentId: 'INC-2026-0142',
    recommendationId: 'REC-0088',
  );
}
