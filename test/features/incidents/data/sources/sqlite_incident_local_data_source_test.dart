import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/local_user_scope.dart';
import 'package:prasa_assist/features/incidents/data/dto/incident_record_dto.dart';
import 'package:prasa_assist/features/incidents/data/dto/local_incident_draft.dart';
import 'package:prasa_assist/features/incidents/data/mappers/incident_mapper.dart';
import 'package:prasa_assist/features/incidents/data/sources/sqlite_incident_local_data_source.dart';
import 'package:prasa_assist/features/incidents/repositories/incident_data_exception.dart';

import '../../../../support/sqlite_test_database.dart';

void main() {
  const ownerA = '00000000-0000-4000-8000-000000000001';
  const ownerB = '00000000-0000-4000-8000-000000000002';

  test(
    'confirmed Incident cache round-trips only for its UUID owner',
    () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final sourceA = SqliteIncidentLocalDataSource(
        database: database,
        userScope: LocalUserScope(ownerA),
        clock: () => DateTime.utc(2026, 8, 29),
      );
      final sourceB = SqliteIncidentLocalDataSource(
        database: database,
        userScope: LocalUserScope(ownerB),
      );

      await sourceA.upsertConfirmedCache([
        _record(),
      ], retrievedAtUtc: DateTime.utc(2026, 8, 29));

      final cached = await sourceA.readConfirmedCacheByCode('INC-LOCAL-001');
      expect(cached?.incidentCode, 'INC-LOCAL-001');
      expect(cached?.reportedAt.isUtc, isTrue);
      expect(cached?.statusHistory.single.note, isNull);
      expect(await sourceB.readConfirmedCache(), isEmpty);
      await expectLater(
        sourceB.readConfirmedCacheByCode('INC-LOCAL-001'),
        completion(isNull),
      );
    },
  );

  test(
    'local drafts are separate from confirmed cache and can be discarded',
    () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final source = SqliteIncidentLocalDataSource(
        database: database,
        userScope: LocalUserScope(ownerA),
        clock: () => DateTime.utc(2026, 8, 28, 1),
      );
      final draft = await source.createDraft(
        LocalIncidentDraft(const IncidentMapper().toDomain(_record())),
      );
      expect(await source.readConfirmedCache(), isEmpty);
      expect((await source.readLocalWorkItems()).single.localId, draft.localId);
      await source.discardDraft(draft.localId);
      expect(await source.readLocalWorkItems(), isEmpty);
    },
  );

  test('owner B cannot discard owner A local draft', () async {
    final database = createInMemoryTestDatabase();
    addTearDown(database.close);
    final sourceA = SqliteIncidentLocalDataSource(
      database: database,
      userScope: LocalUserScope(ownerA),
      clock: () => DateTime.utc(2026, 8, 28),
    );
    final sourceB = SqliteIncidentLocalDataSource(
      database: database,
      userScope: LocalUserScope(ownerB),
    );
    final draft = await sourceA.createDraft(
      LocalIncidentDraft(const IncidentMapper().toDomain(_record())),
    );

    await expectLater(
      sourceB.discardDraft(draft.localId),
      throwsA(isA<IncidentNotFoundException>()),
    );
    expect((await sourceA.readLocalWorkItems()).single.localId, draft.localId);
  });
}

IncidentRecordDto _record() => IncidentRecordDto.fromMap(<String, dynamic>{
  'id': '11111111-1111-4111-8111-111111111111',
  'incident_code': 'INC-LOCAL-001',
  'incident_type': 'vehicle_breakdown',
  'title': 'Cached breakdown',
  'description': 'Owner-scoped SQLite cache verification.',
  'route_id': '300',
  'route_name': 'Route 300',
  'vehicle_id': 'B1023',
  'location': 'Depot',
  'reported_at': '2026-08-28T00:00:00Z',
  'severity': 'high',
  'status': 'reported',
  'vehicle_condition': 'immobilised',
  'disruption_scope': 'partial_obstruction',
  'estimated_delay_minutes': 75,
  'impact_level': 'severe',
  'estimation_reasons': ['Rule-based estimate.'],
  'estimation_model_version': 1,
  'data_source': 'staff_entered',
  'reported_by_label': 'Test staff',
  'created_at': '2026-08-28T00:00:00Z',
  'updated_at': '2026-08-28T00:01:00Z',
  'version': 1,
  'incident_status_history': [
    {
      'sequence_no': 1,
      'from_status': null,
      'to_status': 'reported',
      'changed_at': '2026-08-28T00:00:00Z',
      'changed_by_label': 'Test staff',
      'note': null,
    },
  ],
});
