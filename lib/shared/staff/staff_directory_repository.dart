import 'staff_directory_data_source.dart';
import 'staff_directory_exception.dart';
import 'staff_profile.dart';

enum StaffDirectorySource { liveSupabase, cachedSqlite }

class StaffDirectorySnapshot {
  StaffDirectorySnapshot({
    required Iterable<StaffProfile> profiles,
    required this.source,
    required DateTime retrievedAt,
    required this.isStale,
    this.cacheRefreshFailed = false,
  }) : profiles = List<StaffProfile>.unmodifiable(profiles),
       retrievedAt = retrievedAt.toUtc();

  final List<StaffProfile> profiles;
  final StaffDirectorySource source;
  final DateTime retrievedAt;
  final bool isStale;
  final bool cacheRefreshFailed;

  bool get isCached => source == StaffDirectorySource.cachedSqlite;

  List<StaffProfile> get assignableStaff => List<StaffProfile>.unmodifiable(
    profiles.where((profile) => profile.isAssignable),
  );

  StaffProfile? findByUserId(String? userId) {
    if (userId == null) return null;
    for (final profile in profiles) {
      if (profile.userId == userId) return profile;
    }
    return null;
  }
}

abstract interface class StaffDirectoryRepository {
  Future<StaffDirectorySnapshot> load();

  Future<StaffDirectorySnapshot> loadAssignable();
}

class HybridStaffDirectoryRepository implements StaffDirectoryRepository {
  factory HybridStaffDirectoryRepository({
    required StaffDirectoryRemoteDataSource remote,
    required StaffDirectoryLocalDataSource local,
    DateTime Function()? clock,
    Duration staleAfter = const Duration(hours: 24),
  }) => HybridStaffDirectoryRepository._(
    remote,
    local,
    clock ?? DateTime.now,
    staleAfter,
  );

  HybridStaffDirectoryRepository._(
    this._remote,
    this._local,
    this._clock,
    this.staleAfter,
  );

  static const noOfflineDirectoryMessage =
      'The staff directory is unavailable and no offline cache exists.';

  final StaffDirectoryRemoteDataSource _remote;
  final StaffDirectoryLocalDataSource _local;
  final DateTime Function() _clock;
  final Duration staleAfter;

  @override
  Future<StaffDirectorySnapshot> load() => _load(
    fetchRemote: _remote.fetchActiveDirectory,
    cacheRemote: _local.replaceActiveDirectory,
    cachedFilter: (_) => true,
  );

  @override
  Future<StaffDirectorySnapshot> loadAssignable() => _load(
    fetchRemote: _remote.fetchAssignableStaff,
    cacheRemote: _local.upsert,
    cachedFilter: (profile) => profile.isAssignable,
  );

  Future<StaffDirectorySnapshot> _load({
    required Future<List<StaffProfile>> Function() fetchRemote,
    required Future<void> Function(
      Iterable<StaffProfile> profiles, {
      required DateTime retrievedAt,
    })
    cacheRemote,
    required bool Function(StaffProfile profile) cachedFilter,
  }) async {
    try {
      final profiles = await fetchRemote();
      final retrievedAt = _clock().toUtc();
      var cacheRefreshFailed = false;
      try {
        await cacheRemote(profiles, retrievedAt: retrievedAt);
      } catch (_) {
        cacheRefreshFailed = true;
      }
      return StaffDirectorySnapshot(
        profiles: profiles,
        source: StaffDirectorySource.liveSupabase,
        retrievedAt: retrievedAt,
        isStale: false,
        cacheRefreshFailed: cacheRefreshFailed,
      );
    } on StaffDirectoryOfflineException catch (remoteError) {
      final cached = await _local.readAll();
      if (cached.isEmpty) {
        throw StaffDirectoryOfflineException(
          noOfflineDirectoryMessage,
          cause: remoteError,
        );
      }
      final oldest = cached
          .map((record) => record.retrievedAt)
          .reduce((first, second) => first.isBefore(second) ? first : second);
      return StaffDirectorySnapshot(
        profiles: cached.map((record) => record.profile).where(cachedFilter),
        source: StaffDirectorySource.cachedSqlite,
        retrievedAt: oldest,
        isStale: _clock().toUtc().difference(oldest) > staleAfter,
      );
    }
  }
}
