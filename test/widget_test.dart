import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/app/prasa_assist_app.dart';

void main() {
  testWidgets('PrasaAssist starts with one root MaterialApp', (tester) async {
    await tester.pumpWidget(const PrasaAssistApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('PrasaAssist'), findsOneWidget);
    expect(find.text('Operations workspace'), findsOneWidget);
  });
}
