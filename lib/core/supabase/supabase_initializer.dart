import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

abstract interface class SupabaseClientInitializer {
  Future<SupabaseClient> initialize(AppConfig config);
}

class SupabaseFlutterInitializer implements SupabaseClientInitializer {
  const SupabaseFlutterInitializer();

  @override
  Future<SupabaseClient> initialize(AppConfig config) async {
    final supabase = await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.publishableKey,
    );
    return supabase.client;
  }
}
