import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_gateway.dart';
import '../auth/supabase_auth_gateway.dart';
import '../config/app_config.dart';
import '../dependencies/app_dependencies.dart';
import '../supabase/supabase_initializer.dart';

typedef AuthGatewayFactory = AuthGateway Function(SupabaseClient client);

Future<AppDependencies> bootstrapApplication({
  AppConfig? config,
  SupabaseClientInitializer initializer = const SupabaseFlutterInitializer(),
  AuthGatewayFactory authGatewayFactory = SupabaseAuthGateway.new,
}) async {
  final resolvedConfig = config ?? AppConfig.fromEnvironment();
  final client = await initializer.initialize(resolvedConfig);

  return AppDependencies(
    supabaseClient: client,
    authGateway: authGatewayFactory(client),
  );
}
