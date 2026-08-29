import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/incidents/data/dto/incident_record_dto.dart';
import 'package:prasa_assist/features/incidents/data/mappers/incident_mapper.dart';
import 'package:prasa_assist/features/incidents/data/sources/incident_remote_data_source.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';
import 'package:prasa_assist/features/incidents/models/incident_query.dart';
import 'package:prasa_assist/features/incidents/repositories/incident_data_exception.dart';
import 'package:prasa_assist/features/incidents/repositories/persistent_incident_repository.dart';

void main() {
  group('PersistentIncidentRepository', () {
    test('filters and sorts mapped remote records locally', () async {
      final source = _FakeSource()
        ..records = [
          _record(code: 'INC-LOW', severity: 'low', delay: 10),
          _record(code: 'INC-HIGH', severity: 'high', delay: 75),
        ];
      final repository = PersistentIncidentRepository(dataSource: source);

      final incidents = await repository.getAll(
        query: IncidentQuery(
          severities: {IncidentSeverity.high},
          sortOrder: IncidentSortOrder.longestEstimatedDelay,
        ),
      );

      expect(incidents.map((incident) => incident.incidentId), ['INC-HIGH']);
    });

    test('create returns database-generated incident code', () async {
      final source = _FakeSource()
        ..insertResult = _record(code: 'INC-20260828-002');
      final repository = PersistentIncidentRepository(dataSource: source);
      final input = const IncidentMapper().toDomain(
        _record(code: 'INC-CLIENT-TEMP'),
      );

      final created = await repository.create(input);

      expect(source.inserted?.incidentCode, 'INC-CLIENT-TEMP');
      expect(created.incidentId, 'INC-20260828-002');
    });

    test('update forwards the current optimistic version', () async {
      final source = _FakeSource()
        ..updateResult = _record(code: 'INC-001', version: 4);
      final repository = PersistentIncidentRepository(dataSource: source);
      final input = const IncidentMapper().toDomain(
        _record(code: 'INC-001', version: 3),
      );

      final updated = await repository.update(input);

      expect(source.expectedVersion, 3);
      expect(updated.version, 4);
    });

    test(
      'transition validates locally then forwards database version',
      () async {
        final source = _FakeSource()
          ..single = _record(code: 'INC-001', version: 2)
          ..transitionResult = _record(
            code: 'INC-001',
            status: 'under_review',
            version: 3,
            history: [
              _history(),
              _history(sequence: 2, from: 'reported', to: 'under_review'),
            ],
          );
        final repository = PersistentIncidentRepository(dataSource: source);

        final updated = await repository.transitionStatus(
          'INC-001',
          IncidentStatus.underReview,
          changedBy: 'staff@example.com',
          note: 'Acknowledged',
        );

        expect(source.expectedVersion, 2);
        expect(source.transitionTo, 'under_review');
        expect(updated.status, IncidentStatus.underReview);
        expect(updated.version, 3);
      },
    );

    test('never physically deletes persistent Incident records', () async {
      final source = _FakeSource();
      final repository = PersistentIncidentRepository(dataSource: source);

      await expectLater(
        repository.delete('INC-001'),
        throwsA(isA<IncidentDeletionException>()),
      );
      expect(source.deleteRequested, isFalse);
      expect(repository.capabilities.isPersistent, isTrue);
      expect(repository.capabilities.supportsPhysicalDelete, isFalse);
    });
  });
}

class _FakeSource implements IncidentRemoteDataSource {
  List<IncidentRecordDto> records = [];
  IncidentRecordDto? single;
  IncidentRecordDto? inserted;
  IncidentRecordDto? insertResult;
  IncidentRecordDto? updateResult;
  IncidentRecordDto? transitionResult;
  int? expectedVersion;
  String? transitionTo;
  bool deleteRequested = false;

  @override
  Future<List<IncidentRecordDto>> fetchAll() async => records;

  @override
  Future<IncidentRecordDto?> fetchByCode(String incidentCode) async => single;

  @override
  Future<IncidentRecordDto> insert(IncidentRecordDto record) async {
    inserted = record;
    return insertResult!;
  }

  @override
  Future<IncidentRecordDto> update(
    IncidentRecordDto record, {
    required int expectedVersion,
  }) async {
    this.expectedVersion = expectedVersion;
    return updateResult!;
  }

  @override
  Future<IncidentRecordDto> transitionStatus(
    String incidentCode, {
    required String toStatus,
    String? note,
    required int expectedVersion,
  }) async {
    this.expectedVersion = expectedVersion;
    transitionTo = toStatus;
    return transitionResult!;
  }
}

IncidentRecordDto _record({
  required String code,
  String status = 'reported',
  String severity = 'high',
  int delay = 75,
  int version = 1,
  List<Map<String, dynamic>>? history,
}) => IncidentRecordDto.fromMap(<String, dynamic>{
  'incident_code': code,
  'incident_type': 'vehicle_breakdown',
  'title': 'Bus B1023 breakdown',
  'description': 'Bus B1023 is immobilised on Route 300.',
  'route_id': '300',
  'route_name': 'Route 300',
  'vehicle_id': 'B1023',
  'location': 'Jalan Tun Razak',
  'reported_at': '2026-08-28T00:00:00Z',
  'severity': severity,
  'status': status,
  'vehicle_condition': 'immobilised',
  'disruption_scope': 'partial_obstruction',
  'estimated_delay_minutes': delay,
  'impact_level': delay > 60 ? 'severe' : 'minor',
  'estimation_reasons': ['Vehicle cannot move.'],
  'estimation_model_version': 1,
  'data_source': 'staff_entered',
  'reported_by_label': 'staff@example.com',
  'created_at': '2026-08-28T00:05:00Z',
  'updated_at': status == 'reported'
      ? '2026-08-28T00:05:00Z'
      : '2026-08-28T00:10:00Z',
  'version': version,
  'incident_status_history': history ?? [_history()],
});

Map<String, dynamic> _history({
  int sequence = 1,
  String? from,
  String to = 'reported',
}) => <String, dynamic>{
  'sequence_no': sequence,
  'from_status': from,
  'to_status': to,
  'changed_at': sequence == 1 ? '2026-08-28T00:05:00Z' : '2026-08-28T00:10:00Z',
  'changed_by_label': 'staff@example.com',
  'note': null,
};
