import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/local_user_scope.dart';
import 'package:prasa_assist/shared/staff/sqlite_staff_directory_data_source.dart';
import 'package:prasa_assist/shared/staff/staff_directory_exception.dart';
import 'package:prasa_assist/shared/staff/staff_profile.dart';

import '../../support/sqlite_test_database.dart';

void main() {
  test('cache is owner-scoped and refresh upserts profile versions', () async {
    final database = createInMemoryTestDatabase();
    addTearDown(database.close);
    final ownerA = SqliteStaffDirectoryDataSource(
      database: database,
      userScope: LocalUserScope(_ownerA),
    );
    final ownerB = SqliteStaffDirectoryDataSource(
      database: database,
      userScope: LocalUserScope(_ownerB),
    );

    await ownerA.upsert([
      _maintenance(version: 1),
    ], retrievedAt: DateTime.utc(2026, 9, 3, 1));
    expect((await ownerA.readAll()).single.profile.version, 1);
    expect(await ownerB.readAll(), isEmpty);

    await ownerA.upsert([
      _maintenance(version: 2, name: 'Maintenance Two'),
    ], retrievedAt: DateTime.utc(2026, 9, 3, 2));
    final refreshed = (await ownerA.readAll()).single;
    expect(refreshed.profile.displayLabel, 'Maintenance Two (M-002)');
    expect(refreshed.profile.version, 2);
    expect(refreshed.retrievedAt, DateTime.utc(2026, 9, 3, 2));
  });

  test(
    'successful replacement retains missing staff as inactive history',
    () async {
      final database = createInMemoryTestDatabase();
      addTearDown(database.close);
      final source = SqliteStaffDirectoryDataSource(
        database: database,
        userScope: LocalUserScope(_ownerA),
      );
      await source.upsert([
        _maintenance(),
        _supervisor,
      ], retrievedAt: DateTime.utc(2026, 9, 2));

      await source.replaceActiveDirectory([
        _supervisor,
      ], retrievedAt: DateTime.utc(2026, 9, 3));

      final records = await source.readAll();
      expect(records, hasLength(2));
      expect(
        records
            .singleWhere((item) => item.profile.staffCode == 'M-002')
            .profile
            .active,
        isFalse,
      );
      expect(
        records
            .singleWhere((item) => item.profile.staffCode == 'S-001')
            .profile
            .active,
        isTrue,
      );
    },
  );

  test('case variants share one canonical cache identity', () async {
    final database = createInMemoryTestDatabase();
    addTearDown(database.close);
    final source = SqliteStaffDirectoryDataSource(
      database: database,
      userScope: LocalUserScope(_ownerA),
    );

    await expectLater(
      source.upsert([
        _maintenance(),
        StaffProfile(
          userId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          staffCode: 'm-002',
          displayName: 'Duplicate Code',
          role: StaffRole.maintenanceStaff,
          active: true,
          version: 1,
        ),
      ], retrievedAt: DateTime.utc(2026, 9, 3)),
      throwsA(isA<StaffDirectoryMappingException>()),
    );
  });
}

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

StaffProfile _maintenance({int version = 1, String name = 'Maintenance One'}) =>
    StaffProfile(
      userId: '22222222-2222-4222-8222-222222222222',
      staffCode: 'M-002',
      displayName: name,
      role: StaffRole.maintenanceStaff,
      active: true,
      version: version,
    );

final _supervisor = StaffProfile(
  userId: '33333333-3333-4333-8333-333333333333',
  staffCode: 'S-001',
  displayName: 'Supervisor One',
  role: StaffRole.supervisor,
  active: true,
  version: 1,
);
