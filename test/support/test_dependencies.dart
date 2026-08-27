import 'package:prasa_assist/core/auth/auth_gateway.dart';
import 'package:prasa_assist/core/dependencies/app_dependencies.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

AppDependencies createTestDependencies(AuthGateway authGateway) {
  return AppDependencies(
    supabaseClient: SupabaseClient(
      'http://127.0.0.1:54321',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ),
    authGateway: authGateway,
  );
}
