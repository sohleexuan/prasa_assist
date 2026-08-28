import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/app/prasa_assist_app.dart';
import 'package:prasa_assist/core/auth/auth_gateway.dart';

import 'support/fake_auth_gateway.dart';
import 'support/test_dependencies.dart';

void main() {
  testWidgets('PrasaAssist starts with one root MaterialApp', (tester) async {
    final gateway = FakeAuthGateway(
      initialSession: const AuthSession(userId: 'staff-1'),
    );
    addTearDown(gateway.dispose);

    final dependencies = createTestDependencies(gateway);
    await tester.pumpWidget(PrasaAssistApp(dependencies: dependencies));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('PrasaAssist'), findsOneWidget);
    expect(find.text('Operations workspace'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(dependencies.appDatabase.isClosed, isTrue);
  });
}
