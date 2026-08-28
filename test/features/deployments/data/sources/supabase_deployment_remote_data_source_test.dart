import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/data/dto/deployment_record_dto.dart';
import 'package:prasa_assist/features/deployments/data/dto/local_deployment_draft.dart';
import 'package:prasa_assist/features/deployments/data/sources/supabase_deployment_remote_data_source.dart';
import 'package:prasa_assist/features/deployments/repositories/deployment_data_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseDeploymentRemoteDataSource', () {
    test('maps aliased table rows and ordered nested vehicles', () async {
      final gateway = _FakeGateway()
        ..allRows = [
          _response(
            vehicles: [
              {'vehicle_id': 'REPLACEMENT-BUS-02', 'display_order': 2},
              {'vehicle_id': 'REPLACEMENT-BUS-01', 'display_order': 1},
            ],
          ),
        ];
      final source = SupabaseDeploymentRemoteDataSource.withGateway(gateway);

      final records = await source.fetchAll();

      expect(records, hasLength(1));
      expect(records.single.storageId, _storageId);
      expect(records.single.createdByLabel, _actorId);
      expect(records.single.vehicleIds, [
        'REPLACEMENT-BUS-01',
        'REPLACEMENT-BUS-02',
      ]);
      expect(records.single.incidentId, 'INC-B1023-ROUTE-300');
      expect(records.single.recommendationId, 'REC-B1023-ROUTE-300');
    });

    test('returns null when deployment code is missing', () async {
      final gateway = _FakeGateway()..singleRow = null;
      final source = SupabaseDeploymentRemoteDataSource.withGateway(gateway);

      expect(await source.fetchByCode('DEP-MISSING'), isNull);
      expect(gateway.requestedCode, 'DEP-MISSING');
    });

    test('preserves the row creator when the current user differs', () async {
      const currentAuthenticatedUserId = 'user-current';
      const currentAuthenticatedEmail = 'current@example.com';
      const originalCreatorId = 'user-original';
      final gateway = _FakeGateway()
        ..singleRow = {..._rpcResponse(), 'created_by': originalCreatorId};
      final source = SupabaseDeploymentRemoteDataSource.withGateway(gateway);

      final deployment = await source.fetchByCode('DEP-121');

      expect(deployment?.createdByLabel, originalCreatorId);
      expect(deployment?.createdByLabel, isNot(currentAuthenticatedUserId));
      expect(deployment?.createdByLabel, isNot(currentAuthenticatedEmail));
    });

    test('create sends only approved save RPC parameters', () async {
      final gateway = _FakeGateway()..rpcResponse = _rpcResponse();
      final source = SupabaseDeploymentRemoteDataSource.withGateway(gateway);

      final created = await source.insert(_record());

      expect(created.deploymentCode, 'DEP-121');
      expect(created.createdByLabel, _actorId);
      expect(gateway.rpcName, SupabaseDeploymentRemoteDataSource.saveRpc);
      expect(gateway.rpcParams.keys, {'p_payload', 'p_expected_version'});
      expect(gateway.rpcParams['p_expected_version'], isNull);
      final payload = gateway.rpcParams['p_payload'] as Map<String, dynamic>;
      expect(payload.keys, {
        'linked_incident_ref',
        'linked_recommendation_ref',
        'route_id',
        'route_name',
        'start_time',
        'end_time',
        'purpose',
        'vehicle_ids',
      });
      expect(payload, isNot(contains('deployment_code')));
      expect(payload, isNot(contains('id')));
      expect(payload, isNot(contains('status')));
      expect(payload, isNot(contains('created_by')));
      expect(payload, isNot(contains('updated_by')));
      expect(payload, isNot(contains('created_at')));
      expect(payload, isNot(contains('updated_at')));
      expect(payload, isNot(contains('version')));
      expect(payload['linked_incident_ref'], 'INC-2026-0142');
      expect(payload['linked_recommendation_ref'], 'REC-0088');
    });

    test('publishes a local draft without fabricated server fields', () async {
      final gateway = _FakeGateway()..rpcResponse = _rpcResponse();
      final source = SupabaseDeploymentRemoteDataSource.withGateway(gateway);

      final created = await source.publishDraft(_localDraft());

      expect(created.deploymentCode, 'DEP-121');
      expect(gateway.rpcParams.keys, {'p_payload', 'p_expected_version'});
      expect(gateway.rpcParams['p_expected_version'], isNull);
      final payload = gateway.rpcParams['p_payload'] as Map<String, dynamic>;
      expect(payload.keys, {
        'linked_incident_ref',
        'linked_recommendation_ref',
        'route_id',
        'route_name',
        'start_time',
        'end_time',
        'purpose',
        'vehicle_ids',
      });
      expect(payload, isNot(contains('deployment_code')));
      expect(payload, isNot(contains('id')));
      expect(payload, isNot(contains('status')));
      expect(payload, isNot(contains('created_by')));
      expect(payload, isNot(contains('created_at')));
      expect(payload, isNot(contains('updated_at')));
      expect(payload, isNot(contains('version')));
    });

    test(
      'update sends deployment code and optimistic version only once',
      () async {
        final gateway = _FakeGateway()
          ..rpcResponse = _rpcResponse(version: 6, deploymentCode: 'DEP-120');
        final source = SupabaseDeploymentRemoteDataSource.withGateway(gateway);

        final updated = await source.update(
          _record(version: 5),
          expectedVersion: 5,
        );

        expect(updated.version, 6);
        expect(gateway.rpcParams.keys, {'p_payload', 'p_expected_version'});
        expect(gateway.rpcParams['p_expected_version'], 5);
        final payload = gateway.rpcParams['p_payload'] as Map<String, dynamic>;
        expect(payload['deployment_code'], 'DEP-CLIENT-PROVISIONAL');
        expect(payload, isNot(contains('version')));
        expect(payload, isNot(contains('status')));
      },
    );

    test('update preserves local service-window instants as UTC', () async {
      final start = DateTime.parse('2026-08-28T04:40:00+08:00');
      final end = DateTime.parse('2026-08-28T05:40:00+08:00');
      final gateway = _FakeGateway()
        ..rpcResponse = _rpcResponse(version: 6, deploymentCode: 'DEP-120');
      final source = SupabaseDeploymentRemoteDataSource.withGateway(gateway);

      await source.update(
        _record(version: 5, startTime: start, endTime: end),
        expectedVersion: 5,
      );

      final payload = gateway.rpcParams['p_payload'] as Map<String, dynamic>;
      expect(payload['start_time'], '2026-08-27T20:40:00.000Z');
      expect(payload['end_time'], '2026-08-27T21:40:00.000Z');
    });

    test('transition ignores all server-owned neutral inputs', () async {
      final gateway = _FakeGateway()
        ..rpcResponse = _rpcResponse(
          deploymentCode: 'DEP-120',
          status: 'active',
          version: 3,
        );
      final source = SupabaseDeploymentRemoteDataSource.withGateway(gateway);

      final transitioned = await source.transitionStatus(
        'DEP-120',
        fromStatus: 'draft',
        toStatus: 'active',
        changedByLabel: 'do-not-send@example.com',
        changedAt: DateTime.utc(1999),
        expectedVersion: 2,
      );

      expect(transitioned.status, 'active');
      expect(gateway.rpcName, SupabaseDeploymentRemoteDataSource.transitionRpc);
      expect(gateway.rpcParams, {
        'p_deployment_code': 'DEP-120',
        'p_to_status': 'active',
        'p_expected_version': 2,
      });
    });

    test('persistent delete is rejected without an RPC', () async {
      final gateway = _FakeGateway();
      final source = SupabaseDeploymentRemoteDataSource.withGateway(gateway);

      await expectLater(
        source.delete('DEP-120', expectedVersion: 1),
        throwsA(isA<DeploymentPermissionException>()),
      );
      expect(gateway.rpcCallCount, 0);
    });

    test('rejects a non-Draft create before invoking RPC', () async {
      final gateway = _FakeGateway();
      final source = SupabaseDeploymentRemoteDataSource.withGateway(gateway);

      await expectLater(
        source.insert(_record(status: 'scheduled')),
        throwsA(isA<DeploymentValidationException>()),
      );
      expect(gateway.rpcCallCount, 0);
    });

    final databaseFailures = <String, Matcher>{
      'P0002': isA<DeploymentNotFoundException>(),
      '23505': isA<DeploymentDuplicateException>(),
      '40001': isA<DeploymentConflictException>(),
      '42501': isA<DeploymentPermissionException>(),
      '22023': isA<DeploymentValidationException>(),
      'XX000': isA<DeploymentUnknownDataException>(),
    };
    for (final entry in databaseFailures.entries) {
      test('maps PostgreSQL ${entry.key} to ${entry.value}', () async {
        final gateway = _FakeGateway()
          ..fetchError = PostgrestException(
            message: 'Unsafe backend detail',
            code: entry.key,
          );
        final source = SupabaseDeploymentRemoteDataSource.withGateway(gateway);

        await expectLater(source.fetchAll(), throwsA(entry.value));
      });
    }

    test('maps socket connectivity failures to a safe offline error', () async {
      final gateway = _FakeGateway()
        ..fetchError = const SocketException('socket detail');
      final source = SupabaseDeploymentRemoteDataSource.withGateway(gateway);

      await expectLater(
        source.fetchAll(),
        throwsA(
          isA<DeploymentOfflineException>().having(
            (error) => error.message,
            'message',
            isNot(contains('socket detail')),
          ),
        ),
      );
    });

    test('maps request timeouts to a safe offline error', () async {
      final gateway = _FakeGateway()
        ..fetchError = TimeoutException('timeout detail');
      final source = SupabaseDeploymentRemoteDataSource.withGateway(gateway);

      await expectLater(
        source.fetchAll(),
        throwsA(isA<DeploymentOfflineException>()),
      );
    });

    test('does not classify auth failure as offline', () async {
      final gateway = _FakeGateway()
        ..fetchError = const AuthException('unsafe auth detail');
      final source = SupabaseDeploymentRemoteDataSource.withGateway(gateway);

      await expectLater(
        source.fetchAll(),
        throwsA(isA<DeploymentPermissionException>()),
      );
    });

    test('does not classify an unknown exception as offline', () async {
      final gateway = _FakeGateway()
        ..fetchError = StateError('unsafe programming detail');
      final source = SupabaseDeploymentRemoteDataSource.withGateway(gateway);

      await expectLater(
        source.fetchAll(),
        throwsA(isA<DeploymentUnknownDataException>()),
      );
    });

    test('rejects malformed RPC response as mapping failure', () async {
      final gateway = _FakeGateway()..rpcResponse = ['not', 'a', 'record'];
      final source = SupabaseDeploymentRemoteDataSource.withGateway(gateway);

      await expectLater(
        source.insert(_record()),
        throwsA(isA<DeploymentMappingException>()),
      );
    });
  });
}

const _storageId = '00000000-0000-0000-0000-000000000120';
const _actorId = '00000000-0000-0000-0000-000000000001';

LocalDeploymentDraft _localDraft() {
  return LocalDeploymentDraft(
    routeId: '300',
    routeName: 'Terminal Maluri ~ Lebuh Ampang',
    vehicleIds: const ['REPLACEMENT-BUS-01', 'REPLACEMENT-BUS-02'],
    startTime: DateTime.parse('2026-08-28T04:40:00+08:00'),
    endTime: DateTime.parse('2026-08-28T05:40:00+08:00'),
    purpose: 'Replace unavailable Bus B1023',
    incidentId: 'INC-2026-0142',
    recommendationId: 'REC-0088',
  );
}

DeploymentRecordDto _record({
  int version = 1,
  String status = 'draft',
  DateTime? startTime,
  DateTime? endTime,
}) {
  return DeploymentRecordDto(
    deploymentCode: 'DEP-CLIENT-PROVISIONAL',
    routeId: '300',
    routeName: 'Route 300',
    vehicleIds: const ['REPLACEMENT-BUS-01', 'REPLACEMENT-BUS-02'],
    startTime: startTime ?? DateTime.utc(2026, 8, 28),
    endTime: endTime ?? DateTime.utc(2026, 8, 28, 1),
    status: status,
    purpose: 'Replace unavailable Bus B1023',
    createdByLabel: 'staff@example.com',
    createdAt: DateTime.utc(2026, 8, 27, 23),
    updatedAt: DateTime.utc(2026, 8, 27, 23),
    version: version,
    incidentId: 'INC-2026-0142',
    recommendationId: 'REC-0088',
  );
}

Map<String, dynamic> _response({required List<Object?> vehicles}) {
  return {
    'id': _storageId,
    'deployment_code': 'DEP-120',
    'incident_id': 'INC-B1023-ROUTE-300',
    'recommendation_id': 'REC-B1023-ROUTE-300',
    'route_id': '300',
    'route_name': 'Route 300',
    'start_time': '2026-08-28T00:00:00Z',
    'end_time': '2026-08-28T01:00:00Z',
    'status': 'scheduled',
    'purpose': 'Replace unavailable Bus B1023',
    'created_by_label': _actorId,
    'created_at': '2026-08-27T23:00:00Z',
    'updated_at': '2026-08-27T23:00:00Z',
    'version': 1,
    'deployment_vehicles': vehicles,
  };
}

Map<String, dynamic> _rpcResponse({
  String deploymentCode = 'DEP-121',
  String status = 'draft',
  int version = 1,
}) {
  return {
    'deployment_code': deploymentCode,
    'linked_incident_ref': 'INC-2026-0142',
    'linked_recommendation_ref': 'REC-0088',
    'route_id': '300',
    'route_name': 'Route 300',
    'start_time': '2026-08-28T00:00:00Z',
    'end_time': '2026-08-28T01:00:00Z',
    'status': status,
    'purpose': 'Replace unavailable Bus B1023',
    'vehicle_ids': ['REPLACEMENT-BUS-01', 'REPLACEMENT-BUS-02'],
    'created_by': _actorId,
    'updated_by': _actorId,
    'created_at': '2026-08-27T23:00:00Z',
    'updated_at': '2026-08-27T23:00:00Z',
    'version': version,
  };
}

class _FakeGateway implements DeploymentSupabaseGateway {
  Object? allRows = const <Object?>[];
  Object? singleRow;
  Object? rpcResponse;
  Object? fetchError;
  String? requestedCode;
  String? rpcName;
  Map<String, dynamic> rpcParams = const {};
  int rpcCallCount = 0;

  @override
  Future<Object?> fetchAllDeploymentRows() async {
    if (fetchError case final error?) {
      throw error;
    }
    return allRows;
  }

  @override
  Future<Object?> fetchDeploymentRow(String deploymentCode) async {
    requestedCode = deploymentCode;
    if (fetchError case final error?) {
      throw error;
    }
    return singleRow;
  }

  @override
  Future<Object?> invokeRpc(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    rpcCallCount++;
    rpcName = functionName;
    rpcParams = params;
    if (fetchError case final error?) {
      throw error;
    }
    return rpcResponse;
  }
}
