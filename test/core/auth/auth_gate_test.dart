import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/auth/auth_gate.dart';
import 'package:prasa_assist/core/auth/auth_gateway.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';

import '../../support/fake_auth_gateway.dart';

void main() {
  late FakeAuthGateway authGateway;

  tearDown(() async {
    await authGateway.dispose();
  });

  testWidgets('shows an accessible loading state while restoring session', (
    tester,
  ) async {
    authGateway = FakeAuthGateway();

    await tester.pumpWidget(_TestHost(authGateway: authGateway));

    expect(find.text('Checking staff access'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows staff sign in when unauthenticated', (tester) async {
    authGateway = FakeAuthGateway();

    await tester.pumpWidget(_TestHost(authGateway: authGateway));
    await tester.pump();

    expect(find.text('Staff sign in'), findsOneWidget);
    expect(find.text('Authenticated content'), findsNothing);
  });

  testWidgets('shows application content when authenticated', (tester) async {
    authGateway = FakeAuthGateway(
      initialSession: const AuthSession(
        userId: 'staff-1',
        email: 'staff@example.com',
      ),
    );

    await tester.pumpWidget(_TestHost(authGateway: authGateway));
    await tester.pump();

    expect(find.text('Authenticated content'), findsOneWidget);
  });

  testWidgets('reacts to later authentication changes', (tester) async {
    authGateway = FakeAuthGateway();

    await tester.pumpWidget(_TestHost(authGateway: authGateway));
    await tester.pump();
    expect(find.text('Staff sign in'), findsOneWidget);

    authGateway.emit(const AuthSession(userId: 'staff-2'));
    await tester.pump();
    expect(find.text('Authenticated content'), findsOneWidget);

    authGateway.emit(null);
    await tester.pump();
    expect(find.text('Staff sign in'), findsOneWidget);
  });

  testWidgets('presents a safe auth stream error', (tester) async {
    authGateway = FakeAuthGateway();

    await tester.pumpWidget(_TestHost(authGateway: authGateway));
    authGateway.emitError(Exception('raw provider details'));
    await tester.pump();

    expect(find.text('Unable to verify staff access'), findsOneWidget);
    expect(find.text('Check the connection and try again.'), findsOneWidget);
    expect(find.textContaining('raw provider details'), findsNothing);
  });
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.authGateway});

  final AuthGateway authGateway;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: AuthGate(
        authGateway: authGateway,
        authenticatedChild: const Text('Authenticated content'),
      ),
    );
  }
}
