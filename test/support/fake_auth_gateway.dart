import 'dart:async';

import 'package:prasa_assist/core/auth/auth_gateway.dart';

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({AuthSession? initialSession}) : _session = initialSession;

  final _controller = StreamController<AuthSession?>.broadcast(sync: true);
  AuthSession? _session;

  Object? signInError;
  Object? signOutError;
  String? signedInEmail;
  String? signedInPassword;
  var signInCallCount = 0;
  var signOutCallCount = 0;

  @override
  AuthSession? get currentSession => _session;

  @override
  Stream<AuthSession?> get authStateChanges => _controller.stream;

  void emit(AuthSession? session) {
    _session = session;
    _controller.add(session);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInCallCount += 1;
    signedInEmail = email;
    signedInPassword = password;
    if (signInError case final error?) {
      throw error;
    }
  }

  @override
  Future<void> signOut() async {
    signOutCallCount += 1;
    if (signOutError case final error?) {
      throw error;
    }
    emit(null);
  }

  Future<void> dispose() => _controller.close();
}
