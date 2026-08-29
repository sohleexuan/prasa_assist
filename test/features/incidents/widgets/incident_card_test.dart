import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/incidents/data/incident_demo_data.dart';
import 'package:prasa_assist/features/incidents/widgets/incident_card.dart';

void main() {
  testWidgets('renders operational summary and explicit data source', (
    tester,
  ) async {
    await _pumpCard(tester);

    expect(find.text('Bus B1023 breakdown'), findsOneWidget);
    expect(find.textContaining('INC-20260828-001'), findsOneWidget);
    expect(find.text('Route 300'), findsOneWidget);
    expect(find.text('B1023'), findsOneWidget);
    expect(find.text('Reported'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Severe'), findsOneWidget);
    expect(find.text('Estimated delay: 75 minutes'), findsOneWidget);
    expect(find.text('Mock / Demonstration Data'), findsOneWidget);
  });

  testWidgets('invokes onTap and exposes an accessible action label', (
    tester,
  ) async {
    var tapCount = 0;
    await _pumpCard(tester, onTap: () => tapCount++);

    final semantics = tester.getSemantics(find.byType(IncidentCard));
    expect(semantics.label, contains('Open incident INC-20260828-001'));

    await tester.tap(find.byType(IncidentCard));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets('long values remain overflow-free at narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final incident = IncidentDemoData.busB1023().copyWith(
      title:
          'A very long operational incident title that must wrap safely on '
          'small staff devices',
      routeName:
          'A very long Route 300 corridor description for responsive testing',
      vehicleId: 'BUS-WITH-A-VERY-LONG-IDENTIFIER-B1023',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(child: IncidentCard(incident: incident)),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCard(WidgetTester tester, {VoidCallback? onTap}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: IncidentCard(incident: IncidentDemoData.busB1023(), onTap: onTap),
      ),
    ),
  );
}
