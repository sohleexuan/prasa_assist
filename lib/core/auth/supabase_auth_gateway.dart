import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_gateway.dart';

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);

  final SupabaseClient _client;

  @override
  AuthSession? get currentSession => _mapSession(_client.auth.currentSession);

  @override
  Stream<AuthSession?> get authStateChanges {
    return _client.auth.onAuthStateChange.map(
      (state) => _mapSession(state.session),
    );
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  AuthSession? _mapSession(Session? session) {
    final user = session?.user;
    if (user == null) {
      return null;
    }

    return AuthSession(userId: user.id, email: user.email);
  }
}
