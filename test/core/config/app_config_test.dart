import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('accepts a valid URL and publishable key', () {
      final config = AppConfig.fromValues(
        supabaseUrl: ' http://127.0.0.1:54321 ',
        publishableKey: ' test-publishable-key ',
      );

      expect(config.supabaseUrl, 'http://127.0.0.1:54321');
      expect(config.publishableKey, 'test-publishable-key');
    });

    test('rejects missing URL', () {
      expect(
        () => AppConfig.fromValues(
          supabaseUrl: '',
          publishableKey: 'test-publishable-key',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects invalid URL', () {
      expect(
        () => AppConfig.fromValues(
          supabaseUrl: 'not-a-url',
          publishableKey: 'test-publishable-key',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects missing or placeholder publishable key', () {
      for (final key in ['', 'your-publishable-key']) {
        expect(
          () => AppConfig.fromValues(
            supabaseUrl: 'https://example.supabase.co',
            publishableKey: key,
          ),
          throwsA(isA<AppConfigException>()),
        );
      }
    });

    test('rejects modern Supabase secret keys', () {
      expect(
        () => AppConfig.fromValues(
          supabaseUrl: 'https://example.supabase.co',
          publishableKey: 'sb_secret_do-not-use-in-client',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects legacy JWTs with the service role claim', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(utf8.encode('{"role":"service_role"}'));

      expect(
        () => AppConfig.fromValues(
          supabaseUrl: 'https://example.supabase.co',
          publishableKey: '$header.$payload.signature',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects separately supplied forbidden configuration', () {
      expect(
        () => AppConfig.fromValues(
          supabaseUrl: 'https://example.supabase.co',
          publishableKey: 'test-publishable-key',
          serviceRoleKey: 'must-not-enter-client',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });
  });
}
