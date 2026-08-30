import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/work_orders/data/dto/local_work_order_draft.dart';
import 'package:prasa_assist/features/work_orders/data/dto/work_order_update_input.dart';
import 'package:prasa_assist/features/work_orders/data/sources/supabase_work_order_remote_data_source.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseWorkOrderRemoteDataSource', () {
    test(
      'publishes with local ID and never sends local creator label',
      () async {
        final gateway = _Gateway()..rpcResponse = _row();
        final source = SupabaseWorkOrderRemoteDataSource.withGateway(gateway);

        final result = await source.create(' local-42 ', _draft());

        expect(gateway.rpcName, SupabaseWorkOrderRemoteDataSource.createRpc);
        expect(gateway.params['p_publication_key'], 'local-42');
        final payload = gateway.params['p_payload'] as Map<String, dynamic>;
        expect(payload, isNot(contains('created_by_label')));
        expect(payload['incident_id'], 'INC-B1023-ROUTE-300');
        expect(payload['recommendation_id'], 'REC-INSPECT-B1023');
        expect(result.createdByLabel, 'server.staff@example.com');
      },
    );

    test('explicit retry retains caller supplied publication key', () async {
      final gateway = _Gateway()..rpcResponse = _row();
      final source = SupabaseWorkOrderRemoteDataSource.withGateway(gateway);
      await source.create('local-42', _draft());
      await source.create('local-42', _draft());
      expect(gateway.keys, ['local-42', 'local-42']);
    });

    test('update sends only approved staff-editable fields', () async {
      final gateway = _Gateway()..rpcResponse = _row(version: 2);
      final source = SupabaseWorkOrderRemoteDataSource.withGateway(gateway);
      await source.update(
        'WO-20260830-000001',
        WorkOrderUpdateInput(
          vehicleId: 'B1023',
          taskType: 'Inspection',
          description: 'Staff-reviewed inspection',
          priority: WorkOrderPriority.high,
          scheduledStart: DateTime.utc(2026, 8, 30, 8),
          scheduledEnd: DateTime.utc(2026, 8, 30, 9),
          notes: 'Reviewed',
        ),
        expectedVersion: 1,
      );
      expect((gateway.params['p_payload'] as Map).keys.toSet(), {
        'vehicle_id',
        'task_type',
        'description',
        'priority',
        'scheduled_start',
        'scheduled_end',
        'notes',
      });
    });

    test('transition sends target status without caller from status', () async {
      final gateway = _Gateway()
        ..rpcResponse = _row(status: 'in_progress', version: 2);
      final source = SupabaseWorkOrderRemoteDataSource.withGateway(gateway);
      await source.transitionStatus(
        'WO-20260830-000001',
        toStatus: WorkOrderStatus.inProgress,
        expectedVersion: 1,
      );
      expect(gateway.params, {
        'p_work_order_id': 'WO-20260830-000001',
        'p_to_status': 'in_progress',
        'p_expected_version': 1,
      });
    });

    test('does not blindly retry an ambiguous write', () async {
      final gateway = _Gateway()..error = TimeoutException('unsafe detail');
      final source = SupabaseWorkOrderRemoteDataSource.withGateway(gateway);
      await expectLater(
        source.create('local-42', _draft()),
        throwsA(isA<WorkOrderOfflineException>()),
      );
      expect(gateway.rpcCalls, 1);
    });

    test(
      'maps server conflict, auth, validation and not-found errors',
      () async {
        for (final entry in <String, Type>{
          '40001': WorkOrderConflictException,
          '42501': WorkOrderPermissionException,
          '22023': WorkOrderValidationException,
          'P0002': WorkOrderNotFoundException,
        }.entries) {
          final gateway = _Gateway()
            ..error = PostgrestException(message: 'unsafe', code: entry.key);
          final source = SupabaseWorkOrderRemoteDataSource.withGateway(gateway);
          await expectLater(
            source.fetchAll(),
            throwsA(
              isA<WorkOrderDataException>().having(
                (error) => error.runtimeType,
                'type',
                entry.value,
              ),
            ),
          );
        }
      },
    );

    test(
      'rejects malformed server records as provider-neutral mapping errors',
      () async {
        final gateway = _Gateway()..rpcResponse = {'id': 'bad'};
        final source = SupabaseWorkOrderRemoteDataSource.withGateway(gateway);
        await expectLater(
          source.create('local-42', _draft()),
          throwsA(isA<WorkOrderMappingException>()),
        );
      },
    );
  });
}

LocalWorkOrderDraft _draft() => LocalWorkOrderDraft(
  incidentId: 'INC-B1023-ROUTE-300',
  recommendationId: 'REC-INSPECT-B1023',
  vehicleId: 'B1023',
  taskType: 'Inspection',
  description: 'Inspect Bus B1023 after its Route 300 breakdown.',
  priority: WorkOrderPriority.urgent,
  createdByLabel: 'non-authoritative local label',
);

Map<String, dynamic> _row({String status = 'draft', int version = 1}) => {
  'id': '22222222-2222-4222-8222-222222222222',
  'work_order_id': 'WO-20260830-000001',
  'incident_id': 'INC-B1023-ROUTE-300',
  'recommendation_id': 'REC-INSPECT-B1023',
  'vehicle_id': 'B1023',
  'task_type': 'Inspection',
  'description': 'Inspect Bus B1023 after its Route 300 breakdown.',
  'priority': 'urgent',
  'assigned_to': status == 'in_progress' ? 'Technician A' : null,
  'scheduled_start': status == 'in_progress' ? '2026-08-30T08:00:00Z' : null,
  'scheduled_end': status == 'in_progress' ? '2026-08-30T09:00:00Z' : null,
  'status': status,
  'notes': null,
  'created_by_user_id': '33333333-3333-4333-8333-333333333333',
  'created_by_label': 'server.staff@example.com',
  'created_at': '2026-08-30T07:00:00Z',
  'updated_at': '2026-08-30T07:00:00Z',
  'completed_at': null,
  'cancelled_at': null,
  'version': version,
};

class _Gateway implements WorkOrderSupabaseGateway {
  Object? rpcResponse;
  Object? error;
  String? rpcName;
  Map<String, dynamic> params = {};
  int rpcCalls = 0;
  final List<String> keys = [];

  @override
  Future<Object?> fetchAllWorkOrderRows() async {
    if (error case final value?) throw value;
    return <Object?>[];
  }

  @override
  Future<Object?> fetchWorkOrderRow(String workOrderId) async => null;

  @override
  Future<Object?> invokeRpc(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    rpcCalls++;
    rpcName = functionName;
    this.params = params;
    if (params['p_publication_key'] case final String key) keys.add(key);
    if (error case final value?) throw value;
    return rpcResponse;
  }
}
