import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/data/dto/incident_record_dto.dart';
import 'package:prasa_assist/features/incidents/data/sources/supabase_incident_remote_data_source.dart';
import 'package:prasa_assist/features/incidents/repositories/incident_data_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseIncidentRemoteDataSource', () {
    test('maps nested history in sequence order', () async {
      final gateway = _FakeGateway()
        ..allRows = [
          _response(
            history: [
              _history(sequence: 2, from: 'reported', to: 'under_review'),
              _history(sequence: 1, from: null, to: 'reported'),
            ],
          ),
        ];
      final source = SupabaseIncidentRemoteDataSource.withGateway(gateway);

      final records = await source.fetchAll();

      expect(records.single.storageId, _storageId);
      expect(records.single.statusHistory.map((row) => row.sequenceNumber), [
        1,
        2,
      ]);
    });

    test('create omits client code and every server-owned field', () async {
      final gateway = _FakeGateway()..rpcResponse = _response();
      final source = SupabaseIncidentRemoteDataSource.withGateway(gateway);

      final created = await source.insert(_record());

      expect(created.incidentCode, 'INC-20260828-002');
      expect(gateway.rpcName, SupabaseIncidentRemoteDataSource.saveRpc);
      expect(gateway.rpcParams.keys, {'p_payload', 'p_expected_version'});
      expect(gateway.rpcParams['p_expected_version'], isNull);
      final payload = gateway.rpcParams['p_payload'] as Map<String, dynamic>;
      expect(payload, isNot(contains('incident_code')));
      expect(payload, isNot(contains('id')));
      expect(payload, isNot(contains('status')));
      expect(payload, isNot(contains('reported_by_label')));
      expect(payload, isNot(contains('data_source')));
      expect(payload, isNot(contains('version')));
      expect(payload, isNot(contains('incident_status_history')));
    });

    test('update sends code and optimistic version', () async {
      final gateway = _FakeGateway()
        ..rpcResponse = _response(version: 6, code: 'INC-20260828-002');
      final source = SupabaseIncidentRemoteDataSource.withGateway(gateway);

      final updated = await source.update(
        _record(version: 5),
        expectedVersion: 5,
      );

      expect(updated.version, 6);
      expect(gateway.rpcParams['p_expected_version'], 5);
      final payload = gateway.rpcParams['p_payload'] as Map<String, dynamic>;
      expect(payload['incident_code'], 'INC-CLIENT-TEMP');
      expect(payload, isNot(contains('version')));
      expect(payload, isNot(contains('status')));
    });

    test('transition sends note and optimistic version only', () async {
      final gateway = _FakeGateway()
        ..rpcResponse = _response(status: 'under_review', version: 2);
      final source = SupabaseIncidentRemoteDataSource.withGateway(gateway);

      await source.transitionStatus(
        'INC-20260828-002',
        toStatus: 'under_review',
        note: '  Staff acknowledged  ',
        expectedVersion: 1,
      );

      expect(gateway.rpcName, SupabaseIncidentRemoteDataSource.transitionRpc);
      expect(gateway.rpcParams, {
        'p_incident_code': 'INC-20260828-002',
        'p_to_status': 'under_review',
        'p_note': 'Staff acknowledged',
        'p_expected_version': 1,
      });
    });

    final failures = <String, Matcher>{
      'P0002': isA<IncidentNotFoundException>(),
      '23505': isA<IncidentDuplicateException>(),
      '40001': isA<IncidentConflictException>(),
      '42501': isA<IncidentPermissionException>(),
      'PGRST202': isA<IncidentPersistenceSetupException>(),
      'PGRST205': isA<IncidentPersistenceSetupException>(),
      '23514': isA<IncidentValidationException>(),
      'XX000': isA<IncidentUnknownDataException>(),
    };
    for (final entry in failures.entries) {
      test('maps PostgreSQL ${entry.key} safely', () async {
        final gateway = _FakeGateway()
          ..fetchError = PostgrestException(
            message: 'unsafe detail',
            code: entry.key,
          );
        final source = SupabaseIncidentRemoteDataSource.withGateway(gateway);

        await expectLater(source.fetchAll(), throwsA(entry.value));
      });
    }

    test('rejects malformed rows as mapping errors', () async {
      final gateway = _FakeGateway()..allRows = ['invalid'];
      final source = SupabaseIncidentRemoteDataSource.withGateway(gateway);

      await expectLater(
        source.fetchAll(),
        throwsA(isA<IncidentMappingException>()),
      );
    });
  });
}

class _FakeGateway implements IncidentSupabaseGateway {
  Object? allRows = <Object?>[];
  Object? singleRow;
  Object? rpcResponse;
  Object? fetchError;
  String? rpcName;
  Map<String, dynamic> rpcParams = {};

  @override
  Future<Object?> fetchAllIncidentRows() async {
    if (fetchError case final Object error) {
      throw error;
    }
    return allRows;
  }

  @override
  Future<Object?> fetchIncidentRow(String incidentCode) async => singleRow;

  @override
  Future<Object?> invokeRpc(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    rpcName = functionName;
    rpcParams = params;
    return rpcResponse;
  }
}

IncidentRecordDto _record({int version = 1}) => IncidentRecordDto.fromMap(
  _response(code: 'INC-CLIENT-TEMP', version: version),
);

Map<String, dynamic> _response({
  String code = 'INC-20260828-002',
  String status = 'reported',
  int version = 1,
  List<Map<String, dynamic>>? history,
}) => <String, dynamic>{
  'id': _storageId,
  'incident_code': code,
  'incident_type': 'vehicle_breakdown',
  'title': 'Bus B1023 breakdown',
  'description': 'Bus B1023 is immobilised on Route 300.',
  'route_id': '300',
  'route_name': 'Route 300',
  'vehicle_id': 'B1023',
  'location': 'Jalan Tun Razak',
  'reported_at': '2026-08-28T00:00:00Z',
  'severity': 'high',
  'status': status,
  'vehicle_condition': 'immobilised',
  'disruption_scope': 'partial_obstruction',
  'estimated_delay_minutes': 75,
  'impact_level': 'severe',
  'estimation_reasons': ['Vehicle cannot move.'],
  'estimation_model_version': 1,
  'data_source': 'staff_entered',
  'reported_by_label': 'staff@example.com',
  'created_at': '2026-08-28T00:05:00Z',
  'updated_at': '2026-08-28T00:05:00Z',
  'version': version,
  'incident_status_history': history ?? [_history()],
};

Map<String, dynamic> _history({
  int sequence = 1,
  String? from,
  String to = 'reported',
}) => <String, dynamic>{
  'sequence_no': sequence,
  'from_status': from,
  'to_status': to,
  'changed_at': '2026-08-28T00:05:00Z',
  'changed_by_label': 'staff@example.com',
  'note': null,
};

const _storageId = '00000000-0000-4000-8000-000000000002';
