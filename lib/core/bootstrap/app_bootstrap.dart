import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_gateway.dart';
import '../auth/supabase_auth_gateway.dart';
import '../config/app_config.dart';
import '../database/app_database.dart';
import '../database/app_database_opener.dart';
import '../dependencies/app_dependencies.dart';
import '../supabase/supabase_initializer.dart';

typedef AuthGatewayFactory = AuthGateway Function(SupabaseClient client);
typedef AppDatabaseFactory = AppDatabase Function();

AppDatabase createPlatformAppDatabase() {
  return AppDatabase(opener: AppDatabaseOpener());
}

Future<AppDependencies> bootstrapApplication({
  AppConfig? config,
  SupabaseClientInitializer initializer = const SupabaseFlutterInitializer(),
  AuthGatewayFactory authGatewayFactory = SupabaseAuthGateway.new,
  AppDatabaseFactory appDatabaseFactory = createPlatformAppDatabase,
}) async {
  final resolvedConfig = config ?? AppConfig.fromEnvironment();
  final client = await initializer.initialize(resolvedConfig);

  return AppDependencies(
    supabaseClient: client,
    authGateway: authGatewayFactory(client),
    appDatabase: appDatabaseFactory(),
  );
}
