import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_gateway.dart';
import '../database/app_database.dart';
import '../database/local_user_scope.dart';
import '../../shared/staff/sqlite_staff_directory_data_source.dart';
import '../../shared/staff/staff_directory_repository.dart';
import '../../shared/staff/supabase_staff_directory_data_source.dart';

class AppDependencies {
  const AppDependencies({
    required this.supabaseClient,
    required this.authGateway,
    required this.appDatabase,
  });

  final SupabaseClient supabaseClient;
  final AuthGateway authGateway;
  final AppDatabase appDatabase;

  StaffDirectoryRepository staffDirectoryFor(LocalUserScope userScope) =>
      HybridStaffDirectoryRepository(
        remote: SupabaseStaffDirectoryDataSource(supabaseClient),
        local: SqliteStaffDirectoryDataSource(
          database: appDatabase,
          userScope: userScope,
        ),
      );

  Future<void> close() => appDatabase.close();
}
