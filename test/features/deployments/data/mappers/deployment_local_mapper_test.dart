import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/data/dto/deployment_record_dto.dart';
import 'package:prasa_assist/features/deployments/data/mappers/deployment_local_mapper.dart';

void main() {
  test('confirmed DTO round-trips through local rows with vehicle order', () {
    const mapper = DeploymentLocalMapper();
    final dto = _dto();
    final local = mapper.confirmedFromDto(
      localId: 'local-remote-1',
      ownerUserId: _ownerId,
      record: dto,
      retrievedAtUtc: DateTime.utc(2026, 8, 28, 3),
      localCreatedAtUtc: DateTime.utc(2026, 8, 28, 3),
      localModifiedAtUtc: DateTime.utc(2026, 8, 28, 3),
    );
    final vehicleRows = mapper.toVehicleRows(local).reversed.toList();

    final restored = mapper.fromRows(mapper.toParentRow(local), vehicleRows);
    final restoredDto = restored.toConfirmedDto();

    expect(restoredDto.toMap(), dto.toMap());
    expect(restoredDto.vehicleIds, [
      'REPLACEMENT-BUS-01',
      'REPLACEMENT-BUS-02',
    ]);
    expect(restored.retrievedAt, DateTime.utc(2026, 8, 28, 3));
  });

  test('confirmed mapping preserves a nullable remote storage ID', () {
    const mapper = DeploymentLocalMapper();
    final local = mapper.confirmedFromDto(
      localId: 'local-remote-1',
      ownerUserId: _ownerId,
      record: _dto(storageId: null),
      retrievedAtUtc: DateTime.utc(2026, 8, 28, 3),
      localCreatedAtUtc: DateTime.utc(2026, 8, 28, 3),
      localModifiedAtUtc: DateTime.utc(2026, 8, 28, 3),
    );

    expect(local.toConfirmedDto().storageId, isNull);
  });
}

const _ownerId = '11111111-1111-4111-8111-111111111111';

DeploymentRecordDto _dto({
  Object? storageId = '00000000-0000-0000-0000-000000000120',
}) {
  return DeploymentRecordDto(
    storageId: storageId as String?,
    deploymentCode: 'DEP-120',
    routeId: '300',
    routeName: 'Terminal Maluri ~ Lebuh Ampang',
    vehicleIds: const ['REPLACEMENT-BUS-01', 'REPLACEMENT-BUS-02'],
    startTime: DateTime.parse('2026-08-28T04:40:00+08:00'),
    endTime: DateTime.parse('2026-08-28T05:40:00+08:00'),
    status: 'scheduled',
    purpose: 'Replace unavailable Bus B1023',
    createdByLabel: '00000000-0000-0000-0000-000000000001',
    createdAt: DateTime.utc(2026, 8, 27, 20),
    updatedAt: DateTime.utc(2026, 8, 27, 21),
    version: 4,
    incidentId: 'INC-2026-0142',
    recommendationId: 'REC-0088',
  );
}
