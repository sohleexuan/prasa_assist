import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/data/dto/deployment_record_dto.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_data_exception.dart';

void main() {
  group('DeploymentRecordDto', () {
    test('parses a valid persistence map', () {
      final dto = DeploymentRecordDto.fromMap(_validMap());

      expect(dto.storageId, 'storage-120');
      expect(dto.deploymentCode, 'DEP-120');
      expect(dto.routeId, '300');
      expect(dto.vehicleIds, ['ABC 1230', 'DEF 4567']);
      expect(dto.status, 'scheduled');
      expect(dto.version, 3);
      expect(dto.incidentId, 'INC-2026-0142');
      expect(dto.recommendationId, 'REC-0088');
    });

    test('round trips through proposed database map keys', () {
      final original = DeploymentRecordDto.fromMap(_validMap());
      final map = original.toMap();
      final restored = DeploymentRecordDto.fromMap(map);

      expect(
        map.keys,
        containsAll(<String>[
          'id',
          'deployment_code',
          'route_id',
          'route_name',
          'vehicle_ids',
          'start_time',
          'end_time',
          'status',
          'purpose',
          'created_by_label',
          'created_at',
          'updated_at',
          'version',
          'incident_id',
          'recommendation_id',
        ]),
      );
      expect(restored.deploymentCode, original.deploymentCode);
      expect(restored.vehicleIds, original.vehicleIds);
      expect(restored.startTime, original.startTime);
      expect(restored.updatedAt, original.updatedAt);
      expect(restored.version, original.version);
    });

    test('normalizes every timestamp to UTC', () {
      final dto = DeploymentRecordDto.fromMap(
        _validMap(
          startTime: '2026-08-27T08:00:00+08:00',
          endTime: '2026-08-27T10:00:00+08:00',
        ),
      );

      expect(dto.startTime, DateTime.utc(2026, 8, 27));
      expect(dto.endTime, DateTime.utc(2026, 8, 27, 2));
      expect(dto.startTime.isUtc, isTrue);
      expect(dto.createdAt.isUtc, isTrue);
      expect(dto.toMap()['start_time'], '2026-08-27T00:00:00.000Z');
    });

    test('preserves nullable Incident and Recommendation links', () {
      final dto = DeploymentRecordDto.fromMap(
        _validMap()..addAll({'incident_id': null, 'recommendation_id': null}),
      );

      expect(dto.incidentId, isNull);
      expect(dto.recommendationId, isNull);
      expect(dto.toMap()['incident_id'], isNull);
      expect(dto.toMap()['recommendation_id'], isNull);
    });

    test('preserves a database actor UUID as a stable identifier', () {
      const actorId = '00000000-0000-0000-0000-000000000001';
      final dto = DeploymentRecordDto.fromMap(
        _validMap()..['created_by_label'] = actorId,
      );

      expect(dto.createdByLabel, actorId);
      expect(dto.toMap()['created_by_label'], actorId);
    });

    test('rejects missing required fields', () {
      final map = _validMap()..remove('deployment_code');

      expect(
        () => DeploymentRecordDto.fromMap(map),
        throwsA(
          isA<DeploymentMappingException>().having(
            (error) => error.message,
            'message',
            contains('deployment_code'),
          ),
        ),
      );
    });

    test('rejects malformed ISO-8601 timestamps', () {
      expect(
        () => DeploymentRecordDto.fromMap(
          _validMap(startTime: 'not-a-timestamp'),
        ),
        throwsA(
          isA<DeploymentMappingException>().having(
            (error) => error.message,
            'message',
            contains('ISO-8601'),
          ),
        ),
      );
    });

    test('rejects unknown and UI-label status values', () {
      for (final invalidStatus in ['Complete', 'Cancel', 'unknown']) {
        expect(
          () => DeploymentRecordDto.fromMap(
            _validMap()..['status'] = invalidStatus,
          ),
          throwsA(isA<DeploymentMappingException>()),
        );
      }
    });

    test('rejects a version below 1', () {
      expect(
        () => DeploymentRecordDto.fromMap(_validMap()..['version'] = 0),
        throwsA(
          isA<DeploymentMappingException>().having(
            (error) => error.message,
            'message',
            contains('version'),
          ),
        ),
      );
    });

    test('rejects empty vehicle collections and values', () {
      for (final vehicles in <List<dynamic>>[
        [],
        ['ABC 1230', ''],
      ]) {
        expect(
          () => DeploymentRecordDto.fromMap(
            _validMap()..['vehicle_ids'] = vehicles,
          ),
          throwsA(isA<DeploymentMappingException>()),
        );
      }
    });

    test('rejects case-insensitive duplicate vehicle IDs', () {
      expect(
        () => DeploymentRecordDto.fromMap(
          _validMap()..['vehicle_ids'] = ['Bus-1', ' bus-1 '],
        ),
        throwsA(
          isA<DeploymentMappingException>().having(
            (error) => error.message,
            'message',
            contains('duplicates'),
          ),
        ),
      );
    });

    test('protects vehicle IDs from external mutation', () {
      final sourceVehicles = <String>['ABC 1230'];
      final dto = DeploymentRecordDto.fromMap(
        _validMap()..['vehicle_ids'] = sourceVehicles,
      );

      sourceVehicles.add('MUTATED');

      expect(dto.vehicleIds, ['ABC 1230']);
      expect(() => dto.vehicleIds.add('NEW'), throwsUnsupportedError);
    });

    test('sorts nested deployment vehicles by display_order', () {
      final map = _validMap()
        ..remove('vehicle_ids')
        ..['deployment_vehicles'] = <Map<String, dynamic>>[
          {'vehicle_id': 'SECOND', 'display_order': 2},
          {'vehicle_id': 'FIRST', 'display_order': 1},
          {'vehicle_id': 'THIRD', 'display_order': 3},
        ];

      final dto = DeploymentRecordDto.fromMap(map);

      expect(dto.vehicleIds, ['FIRST', 'SECOND', 'THIRD']);
    });

    test('rejects malformed or duplicate nested vehicle rows', () {
      final malformed = _validMap()
        ..['deployment_vehicles'] = <Map<String, dynamic>>[
          {'vehicle_id': 'BUS-1'},
        ];
      final duplicate = _validMap()
        ..['deployment_vehicles'] = <Map<String, dynamic>>[
          {'vehicle_id': 'BUS-1', 'display_order': 1},
          {'vehicle_id': 'bus-1', 'display_order': 2},
        ];

      expect(
        () => DeploymentRecordDto.fromMap(malformed),
        throwsA(isA<DeploymentMappingException>()),
      );
      expect(
        () => DeploymentRecordDto.fromMap(duplicate),
        throwsA(isA<DeploymentMappingException>()),
      );
    });
  });
}

Map<String, dynamic> _validMap({
  String startTime = '2026-08-27T08:00:00Z',
  String endTime = '2026-08-27T10:00:00Z',
}) => <String, dynamic>{
  'id': 'storage-120',
  'deployment_code': 'DEP-120',
  'route_id': '300',
  'route_name': 'Route 300',
  'vehicle_ids': <String>['ABC 1230', 'DEF 4567'],
  'start_time': startTime,
  'end_time': endTime,
  'status': 'scheduled',
  'purpose': 'Replace unavailable Bus B1023 during peak hour',
  'created_by_label': 'Demo Operations Staff',
  'created_at': '2026-08-27T07:30:00Z',
  'updated_at': '2026-08-27T07:45:00Z',
  'version': 3,
  'incident_id': 'INC-2026-0142',
  'recommendation_id': 'REC-0088',
};
