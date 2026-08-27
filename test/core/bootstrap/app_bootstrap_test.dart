import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/bootstrap/app_bootstrap.dart';
import 'package:prasa_assist/core/config/app_config.dart';
import 'package:prasa_assist/core/supabase/supabase_initializer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_auth_gateway.dart';

void main() {
  test(
    'bootstrap initializes Supabase and builds injected dependencies',
    () async {
      final config = AppConfig.fromValues(
        supabaseUrl: 'http://127.0.0.1:54321',
        publishableKey: 'test-publishable-key',
      );
      final client = SupabaseClient(
        'http://127.0.0.1:54321',
        'test-publishable-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final initializer = _FakeInitializer(client);
      final gateway = FakeAuthGateway();
      addTearDown(gateway.dispose);

      final dependencies = await bootstrapApplication(
        config: config,
        initializer: initializer,
        authGatewayFactory: (_) => gateway,
      );

      expect(initializer.receivedConfig, same(config));
      expect(dependencies.supabaseClient, same(client));
      expect(dependencies.authGateway, same(gateway));
    },
  );
}

class _FakeInitializer implements SupabaseClientInitializer {
  _FakeInitializer(this.client);

  final SupabaseClient client;
  AppConfig? receivedConfig;

  @override
  Future<SupabaseClient> initialize(AppConfig config) async {
    receivedConfig = config;
    return client;
  }
}
