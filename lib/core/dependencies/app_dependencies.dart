import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_gateway.dart';

class AppDependencies {
  const AppDependencies({
    required this.supabaseClient,
    required this.authGateway,
  });

  final SupabaseClient supabaseClient;
  final AuthGateway authGateway;
}
