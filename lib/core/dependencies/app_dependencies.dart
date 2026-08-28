import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_gateway.dart';
import '../database/app_database.dart';

class AppDependencies {
  const AppDependencies({
    required this.supabaseClient,
    required this.authGateway,
    required this.appDatabase,
  });

  final SupabaseClient supabaseClient;
  final AuthGateway authGateway;
  final AppDatabase appDatabase;

  Future<void> close() => appDatabase.close();
}
