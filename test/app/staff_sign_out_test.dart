import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/app/prasa_assist_app.dart';
import 'package:prasa_assist/core/auth/auth_gateway.dart';
import 'package:prasa_assist/core/auth/staff_sign_in_page.dart';

import '../support/fake_auth_gateway.dart';
import '../support/test_dependencies.dart';

void main() {
  late FakeAuthGateway authGateway;

  tearDown(() async {
    await authGateway.dispose();
  });

  testWidgets('authenticated staff can access the sign-out action', (
    tester,
  ) async {
    authGateway = FakeAuthGateway(
      initialSession: const AuthSession(userId: 'staff-1'),
    );

    await _pumpApp(tester, authGateway);

    expect(find.byKey(const Key('staff-sign-out-button')), findsOneWidget);
    expect(find.byTooltip('Sign out'), findsOneWidget);
  });

  testWidgets('sign out invokes the gateway and returns to staff sign in', (
    tester,
  ) async {
    authGateway = FakeAuthGateway(
      initialSession: const AuthSession(userId: 'staff-1'),
    );
    await _pumpApp(tester, authGateway);

    await tester.tap(find.byKey(const Key('staff-sign-out-button')));
    await tester.pump();

    expect(authGateway.signOutCallCount, 1);
    expect(find.byType(StaffSignInPage), findsOneWidget);
  });

  testWidgets('sign-out failure shows only the safe error message', (
    tester,
  ) async {
    authGateway = FakeAuthGateway(
      initialSession: const AuthSession(userId: 'staff-1'),
    )..signOutError = Exception('raw provider details');
    await _pumpApp(tester, authGateway);

    await tester.tap(find.byKey(const Key('staff-sign-out-button')));
    await tester.pump();

    expect(authGateway.signOutCallCount, 1);
    expect(
      find.text('Unable to sign out. Check the connection and try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('raw provider details'), findsNothing);
    expect(find.text('Operations workspace'), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester, FakeAuthGateway authGateway) async {
  await tester.pumpWidget(
    PrasaAssistApp(dependencies: createTestDependencies(authGateway)),
  );
  await tester.pump();
}
