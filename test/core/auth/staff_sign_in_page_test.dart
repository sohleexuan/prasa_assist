import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/auth/staff_sign_in_page.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';

import '../../support/fake_auth_gateway.dart';

void main() {
  late FakeAuthGateway authGateway;

  tearDown(() async {
    await authGateway.dispose();
  });

  testWidgets('submits trimmed staff credentials without offering sign-up', (
    tester,
  ) async {
    authGateway = FakeAuthGateway();
    await tester.pumpWidget(_TestHost(authGateway: authGateway));

    await tester.enterText(
      find.byKey(const Key('staff-email-field')),
      ' staff@example.com ',
    );
    await tester.enterText(
      find.byKey(const Key('staff-password-field')),
      'correct horse battery staple',
    );
    await tester.tap(find.byKey(const Key('staff-sign-in-button')));
    await tester.pump();

    expect(authGateway.signInCallCount, 1);
    expect(authGateway.signedInEmail, 'staff@example.com');
    expect(authGateway.signedInPassword, 'correct horse battery staple');
    expect(find.textContaining('Sign up'), findsNothing);
    expect(find.textContaining('Register'), findsNothing);
  });

  testWidgets('shows a safe failure instead of raw provider details', (
    tester,
  ) async {
    authGateway = FakeAuthGateway()
      ..signInError = Exception('provider stack and sensitive detail');
    await tester.pumpWidget(_TestHost(authGateway: authGateway));

    await tester.enterText(
      find.byKey(const Key('staff-email-field')),
      'staff@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('staff-password-field')),
      'incorrect-password',
    );
    await tester.tap(find.byKey(const Key('staff-sign-in-button')));
    await tester.pump();

    expect(find.textContaining('Sign-in was unsuccessful'), findsOneWidget);
    expect(find.textContaining('provider stack'), findsNothing);
  });

  testWidgets('validates required credentials locally', (tester) async {
    authGateway = FakeAuthGateway();
    await tester.pumpWidget(_TestHost(authGateway: authGateway));

    await tester.tap(find.byKey(const Key('staff-sign-in-button')));
    await tester.pump();

    expect(find.text('Enter your staff email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(authGateway.signInCallCount, 0);
  });
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.authGateway});

  final FakeAuthGateway authGateway;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: StaffSignInPage(authGateway: authGateway),
    );
  }
}
