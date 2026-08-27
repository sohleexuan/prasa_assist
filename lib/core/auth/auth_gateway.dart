class AuthSession {
  const AuthSession({required this.userId, this.email});

  final String userId;
  final String? email;

  @override
  bool operator ==(Object other) {
    return other is AuthSession &&
        other.userId == userId &&
        other.email == email;
  }

  @override
  int get hashCode => Object.hash(userId, email);
}

abstract interface class AuthGateway {
  AuthSession? get currentSession;

  Stream<AuthSession?> get authStateChanges;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
