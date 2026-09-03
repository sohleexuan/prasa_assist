import 'staff_profile.dart';

class CachedStaffProfile {
  const CachedStaffProfile({required this.profile, required this.retrievedAt});

  final StaffProfile profile;
  final DateTime retrievedAt;
}

abstract interface class StaffDirectoryRemoteDataSource {
  Future<List<StaffProfile>> fetchActiveDirectory();

  Future<List<StaffProfile>> fetchAssignableStaff();
}

abstract interface class StaffDirectoryLocalDataSource {
  Future<List<CachedStaffProfile>> readAll();

  Future<void> replaceActiveDirectory(
    Iterable<StaffProfile> profiles, {
    required DateTime retrievedAt,
  });

  Future<void> upsert(
    Iterable<StaffProfile> profiles, {
    required DateTime retrievedAt,
  });
}
