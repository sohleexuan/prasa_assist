import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/app/prasa_assist_app.dart';

void main() {
  const moduleNames = [
    'Incident Management',
    'Maintenance Work Orders',
    'Service Deployment',
    'AI Recommendations',
  ];

  testWidgets('home page renders foundation messaging and four modules', (
    tester,
  ) async {
    await tester.pumpWidget(const PrasaAssistApp());

    expect(find.text('Development foundation'), findsOneWidget);
    expect(find.text('AI recommends. Staff decides.'), findsOneWidget);

    for (final moduleName in moduleNames) {
      final moduleEntry = find.text(moduleName);
      await tester.scrollUntilVisible(
        moduleEntry,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(moduleEntry, findsOneWidget);
    }
  });

  for (final moduleName in moduleNames) {
    testWidgets('navigates from $moduleName to its placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(const PrasaAssistApp());

      final moduleEntry = find.text(moduleName);
      await tester.scrollUntilVisible(
        moduleEntry,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(moduleEntry);
      await tester.pumpAndSettle();

      expect(find.text('Module integration pending'), findsOneWidget);
      expect(find.text('Not integrated'), findsOneWidget);
      expect(
        find.textContaining('$moduleName currently opens'),
        findsOneWidget,
      );
    });
  }

  testWidgets('home page remains overflow-free at a small phone size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PrasaAssistApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('AI Recommendations'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('AI Recommendations'), findsOneWidget);
  });
}
