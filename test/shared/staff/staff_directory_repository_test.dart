import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/shared/staff/staff_directory_data_source.dart';
import 'package:prasa_assist/shared/staff/staff_directory_exception.dart';
import 'package:prasa_assist/shared/staff/staff_directory_repository.dart';
import 'package:prasa_assist/shared/staff/staff_profile.dart';

void main() {
  test(
    'live refresh caches active profiles and filters assignable role',
    () async {
      final local = _LocalFake();
      final repository = HybridStaffDirectoryRepository(
        remote: _RemoteFake([_maintenance, _supervisor]),
        local: local,
        clock: () => DateTime.utc(2026, 9, 3, 2),
      );

      final result = await repository.load();

      expect(result.source, StaffDirectorySource.liveSupabase);
      expect(result.assignableStaff, [_maintenance]);
      expect(local.replaced, [_maintenance, _supervisor]);
    },
  );

  test(
    'live directory remains authoritative when cache replacement fails',
    () async {
      final local = _LocalFake()
        ..cached = [
          CachedStaffProfile(
            profile: _inactive,
            retrievedAt: DateTime.utc(2026, 9, 1),
          ),
        ]
        ..replaceError = const StaffDirectoryException('cache detail');
      final repository = HybridStaffDirectoryRepository(
        remote: _RemoteFake([_maintenance, _supervisor]),
        local: local,
        clock: () => DateTime.utc(2026, 9, 3, 2),
      );

      final result = await repository.load();

      expect(result.source, StaffDirectorySource.liveSupabase);
      expect(result.profiles, [_maintenance, _supervisor]);
      expect(result.profiles, isNot(contains(_inactive)));
      expect(result.cacheRefreshFailed, isTrue);
      expect(local.readCount, 0);
    },
  );

  test(
    'assignable load uses remote restricted list and upserts the cache',
    () async {
      final local = _LocalFake();
      final remote = _RemoteFake([_maintenance, _supervisor]);
      final repository = HybridStaffDirectoryRepository(
        remote: remote,
        local: local,
        clock: () => DateTime.utc(2026, 9, 3, 2),
      );

      final result = await repository.loadAssignable();

      expect(remote.assignableFetchCount, 1);
      expect(remote.directoryFetchCount, 0);
      expect(result.profiles, [_maintenance]);
      expect(local.upserted, [_maintenance]);
    },
  );

  test('assignable live result survives cache upsert failure without stale fallback', () async {
    final local = _LocalFake()
      ..cached = [
        CachedStaffProfile(
          profile: _inactive,
          retrievedAt: DateTime.utc(2026, 9, 1),
        ),
      ]
      ..upsertError = const StaffDirectoryException('cache detail');
    final repository = HybridStaffDirectoryRepository(
      remote: _RemoteFake([_maintenance]),
      local: local,
    );

    final result = await repository.loadAssignable();

    expect(result.profiles, [_maintenance]);
    expect(result.profiles, isNot(contains(_inactive)));
    expect(result.cacheRefreshFailed, isTrue);
    expect(local.readCount, 0);
  });

  test('remote permission failure is not classified as a cache failure', () {
    final repository = HybridStaffDirectoryRepository(
      remote: _RemoteFake.permissionDenied(),
      local: _LocalFake(),
    );

    expect(
      repository.load(),
      throwsA(isA<StaffDirectoryPermissionException>()),
    );
  });

  test(
    'offline fallback marks old cache stale and excludes inactive staff',
    () async {
      final local = _LocalFake()
        ..cached = [
          CachedStaffProfile(
            profile: _maintenance,
            retrievedAt: DateTime.utc(2026, 9, 1),
          ),
          CachedStaffProfile(
            profile: StaffProfile(
              userId: _inactive.userId,
              staffCode: _inactive.staffCode,
              displayName: _inactive.displayName,
              role: _inactive.role,
              active: false,
              version: _inactive.version,
            ),
            retrievedAt: DateTime.utc(2026, 9, 1),
          ),
        ];
      final repository = HybridStaffDirectoryRepository(
        remote: _RemoteFake.offline(),
        local: local,
        clock: () => DateTime.utc(2026, 9, 3),
      );

      final result = await repository.load();

      expect(result.isCached, isTrue);
      expect(result.isStale, isTrue);
      expect(result.assignableStaff, [_maintenance]);
      expect(result.assignableStaff, isNot(contains(_inactive)));
    },
  );

  test('offline without cache fails with a safe typed error', () async {
    final repository = HybridStaffDirectoryRepository(
      remote: _RemoteFake.offline(),
      local: _LocalFake(),
    );

    await expectLater(
      repository.load(),
      throwsA(
        isA<StaffDirectoryOfflineException>().having(
          (error) => error.safeMessage,
          'safeMessage',
          HybridStaffDirectoryRepository.noOfflineDirectoryMessage,
        ),
      ),
    );
  });
}

class _RemoteFake implements StaffDirectoryRemoteDataSource {
  _RemoteFake(this.profiles) : offline = false, permissionDenied = false;
  _RemoteFake.offline()
    : profiles = const [],
      offline = true,
      permissionDenied = false;
  _RemoteFake.permissionDenied()
    : profiles = const [],
      offline = false,
      permissionDenied = true;

  final List<StaffProfile> profiles;
  final bool offline;
  final bool permissionDenied;
  int directoryFetchCount = 0;
  int assignableFetchCount = 0;

  @override
  Future<List<StaffProfile>> fetchActiveDirectory() async {
    directoryFetchCount += 1;
    if (permissionDenied) {
      throw const StaffDirectoryPermissionException('denied');
    }
    if (offline) {
      throw const StaffDirectoryOfflineException('offline');
    }
    return profiles;
  }

  @override
  Future<List<StaffProfile>> fetchAssignableStaff() async {
    assignableFetchCount += 1;
    if (permissionDenied) {
      throw const StaffDirectoryPermissionException('denied');
    }
    if (offline) {
      throw const StaffDirectoryOfflineException('offline');
    }
    return profiles.where((profile) => profile.isAssignable).toList();
  }
}

class _LocalFake implements StaffDirectoryLocalDataSource {
  List<CachedStaffProfile> cached = [];
  List<StaffProfile> replaced = [];
  List<StaffProfile> upserted = [];
  StaffDirectoryException? replaceError;
  StaffDirectoryException? upsertError;
  int readCount = 0;

  @override
  Future<List<CachedStaffProfile>> readAll() async {
    readCount += 1;
    return cached;
  }

  @override
  Future<void> replaceActiveDirectory(
    Iterable<StaffProfile> profiles, {
    required DateTime retrievedAt,
  }) async {
    if (replaceError case final error?) throw error;
    replaced = profiles.toList();
  }

  @override
  Future<void> upsert(
    Iterable<StaffProfile> profiles, {
    required DateTime retrievedAt,
  }) async {
    if (upsertError case final error?) throw error;
    upserted = profiles.toList();
  }
}

final _maintenance = StaffProfile(
  userId: '22222222-2222-4222-8222-222222222222',
  staffCode: 'M-002',
  displayName: 'Maintenance One',
  role: StaffRole.maintenanceStaff,
  active: true,
  version: 1,
);
final _inactive = StaffProfile(
  userId: '44444444-4444-4444-8444-444444444444',
  staffCode: 'M-004',
  displayName: 'Inactive Staff',
  role: StaffRole.maintenanceStaff,
  active: true,
  version: 3,
);
final _supervisor = StaffProfile(
  userId: '33333333-3333-4333-8333-333333333333',
  staffCode: 'S-001',
  displayName: 'Supervisor One',
  role: StaffRole.supervisor,
  active: true,
  version: 1,
);
