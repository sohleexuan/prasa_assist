import 'dart:convert';

class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}

class AppConfig {
  const AppConfig._({required this.supabaseUrl, required this.publishableKey});

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _serviceRoleKey = String.fromEnvironment(
    'SUPABASE_SERVICE_ROLE_KEY',
  );
  static const _secretKey = String.fromEnvironment('SUPABASE_SECRET_KEY');

  final String supabaseUrl;
  final String publishableKey;

  factory AppConfig.fromEnvironment() {
    return AppConfig.fromValues(
      supabaseUrl: _supabaseUrl,
      publishableKey: _publishableKey,
      serviceRoleKey: _serviceRoleKey,
      secretKey: _secretKey,
    );
  }

  factory AppConfig.fromValues({
    required String supabaseUrl,
    required String publishableKey,
    String serviceRoleKey = '',
    String secretKey = '',
  }) {
    final url = supabaseUrl.trim();
    final key = publishableKey.trim();

    if (serviceRoleKey.trim().isNotEmpty || secretKey.trim().isNotEmpty) {
      throw const AppConfigException(
        'Secret and service-role configuration must never enter Flutter.',
      );
    }

    if (url.isEmpty) {
      throw const AppConfigException('SUPABASE_URL is required.');
    }

    final uri = Uri.tryParse(url);
    final usesSupportedScheme = uri?.scheme == 'https' || uri?.scheme == 'http';
    if (uri == null || !usesSupportedScheme || uri.host.isEmpty) {
      throw const AppConfigException(
        'SUPABASE_URL must be a valid HTTP or HTTPS URL.',
      );
    }

    if (key.isEmpty) {
      throw const AppConfigException('SUPABASE_PUBLISHABLE_KEY is required.');
    }

    if (_looksLikePlaceholder(key)) {
      throw const AppConfigException(
        'SUPABASE_PUBLISHABLE_KEY still contains an example placeholder.',
      );
    }

    if (_isForbiddenKey(key)) {
      throw const AppConfigException(
        'Only a Supabase publishable key may enter Flutter.',
      );
    }

    return AppConfig._(supabaseUrl: url, publishableKey: key);
  }

  static bool _looksLikePlaceholder(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('your-publishable-key') ||
        normalized.contains('placeholder') ||
        normalized.contains('<') ||
        normalized.contains('>');
  }

  static bool _isForbiddenKey(String value) {
    final normalized = value.toLowerCase();
    if (normalized.startsWith('sb_secret_') ||
        normalized.contains('service_role') ||
        normalized.contains('service-role')) {
      return true;
    }

    final segments = value.split('.');
    if (segments.length != 3) {
      return false;
    }

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(segments[1])),
      );
      final claims = jsonDecode(payload);
      return claims is Map<String, dynamic> &&
          claims['role']?.toString().toLowerCase() == 'service_role';
    } on FormatException {
      return false;
    }
  }
}
