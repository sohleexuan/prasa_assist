import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/deployment_demo_app.dart';
import 'package:prasa_assist/features/deployments/screens/deployment_detail_screen.dart';
import 'package:prasa_assist/features/deployments/screens/deployment_form_screen.dart';
import 'package:prasa_assist/features/deployments/screens/deployment_list_screen.dart';

void main() {
  testWidgets('launches the Module 3 demo with DEP-120 seed data', (
    tester,
  ) async {
    await _pumpDemo(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'PrasaAssist — Service Deployment');
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.theme!.useMaterial3, isTrue);
    expect(find.byType(DeploymentListScreen), findsOneWidget);
    expect(find.text('DEP-120'), findsOneWidget);
  });

  testWidgets('clearly identifies prototype data and its limitations', (
    tester,
  ) async {
    await _pumpDemo(tester);

    expect(find.text('Module 3 Prototype'), findsOneWidget);
    expect(find.textContaining('In-memory demonstration data'), findsOneWidget);
    expect(
      find.textContaining('Changes reset when the app restarts'),
      findsOneWidget,
    );
    expect(find.text('Not connected to live operations'), findsOneWidget);
    expect(
      find.text('Prototype user: demo-operations-staff (not authenticated)'),
      findsOneWidget,
    );
  });

  testWidgets('New Deployment opens Create and Cancel returns to List', (
    tester,
  ) async {
    await _pumpDemo(tester);

    await _openCreate(tester);
    expect(find.byType(DeploymentFormScreen), findsOneWidget);
    expect(find.text('New Deployment'), findsWidgets);

    await _tapByKey(tester, 'cancel-deployment-button');
    await _finishNavigation(tester);

    expect(find.byType(DeploymentListScreen), findsOneWidget);
    expect(find.byType(DeploymentFormScreen), findsNothing);
  });

  testWidgets('DEP-120 opens Details and Back returns to List', (tester) async {
    await _pumpDemo(tester);

    await _openDetails(tester, 'DEP-120');
    expect(find.byType(DeploymentDetailScreen), findsOneWidget);
    expect(find.text('Deployment Details'), findsOneWidget);
    expect(find.text('DEP-120'), findsOneWidget);

    await _tapByKey(tester, 'back-from-deployment-button');
    await _finishNavigation(tester);

    expect(find.byType(DeploymentListScreen), findsOneWidget);
    expect(find.byType(DeploymentDetailScreen), findsNothing);
  });

  testWidgets('Edit opens for Scheduled and Cancel returns to Details', (
    tester,
  ) async {
    await _pumpDemo(tester);
    await _openDetails(tester, 'DEP-120');

    await _tapByKey(tester, 'edit-deployment-button');
    await _finishNavigation(tester);

    expect(find.byType(DeploymentFormScreen), findsOneWidget);
    expect(find.text('Edit Deployment'), findsOneWidget);

    await _tapByKey(tester, 'cancel-deployment-button');
    await _finishNavigation(tester);

    expect(find.byType(DeploymentDetailScreen), findsOneWidget);
    expect(find.text('DEP-120'), findsOneWidget);
  });

  testWidgets('generates unique DEP identifiers during one session', (
    tester,
  ) async {
    await _pumpDemo(tester);

    await _openCreate(tester);
    final firstId = _fieldText(tester, 'deployment-id-field');
    await _tapByKey(tester, 'cancel-deployment-button');
    await _finishNavigation(tester);

    await _openCreate(tester);
    final secondId = _fieldText(tester, 'deployment-id-field');

    expect(firstId, startsWith('DEP-'));
    expect(secondId, startsWith('DEP-'));
    expect(secondId, isNot(firstId));
  });

  testWidgets('creating a valid Draft refreshes the List immediately', (
    tester,
  ) async {
    await _pumpDemo(tester);
    await _openCreate(tester);
    await _enterValidDeployment(tester, routeName: 'Demo Draft Route');

    await _tapByKey(tester, 'save-draft-button');
    await _finishNavigation(tester);

    expect(find.byType(DeploymentListScreen), findsOneWidget);
    expect(_summaryValue(tester, 'deployment-total-count'), '2');
    await _revealDeployment(tester, 'DEP-TEST-001');
    expect(_deploymentCard('DEP-TEST-001'), findsOneWidget);
    expect(
      find.descendant(
        of: _deploymentCard('DEP-TEST-001'),
        matching: find.text('Demo Draft Route'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('explicit scheduling creates a Scheduled deployment', (
    tester,
  ) async {
    await _pumpDemo(tester);
    await _openCreate(tester);
    await _enterValidDeployment(tester, routeName: 'Scheduled Demo Route');

    await _tapByKey(tester, 'schedule-deployment-button');
    await _finishNavigation(tester);

    expect(_summaryValue(tester, 'deployment-scheduled-count'), '2');
    await _revealDeployment(tester, 'DEP-TEST-001');
    expect(_deploymentCard('DEP-TEST-001'), findsOneWidget);
    expect(
      find.descendant(
        of: _deploymentCard('DEP-TEST-001'),
        matching: find.text('Scheduled'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('editing a Draft refreshes both Details and List', (
    tester,
  ) async {
    await _pumpDemo(tester);
    await _createDraft(tester, routeName: 'Before Edit');
    await _openDetails(tester, 'DEP-TEST-001');

    await _tapByKey(tester, 'edit-deployment-button');
    await _finishNavigation(tester);
    await tester.enterText(
      find.byKey(const ValueKey('route-name-field')),
      'After Edit',
    );
    await _tapByKey(tester, 'save-changes-button');
    await _finishNavigation(tester);

    expect(find.byType(DeploymentDetailScreen), findsOneWidget);
    expect(find.text('After Edit'), findsOneWidget);
    expect(find.text('Before Edit'), findsNothing);

    await _tapByKey(tester, 'back-from-deployment-button');
    await _finishNavigation(tester);
    await _revealDeployment(tester, 'DEP-TEST-001');

    expect(
      find.descendant(
        of: _deploymentCard('DEP-TEST-001'),
        matching: find.text('After Edit'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a legal status action updates Details and List', (tester) async {
    await _pumpDemo(tester);
    await _openDetails(tester, 'DEP-120');

    await _tapByKey(tester, 'start-deployment-button');
    expect(find.text('Start deployment?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-status-active')));
    await _finishOperation(tester);

    expect(find.text('Active'), findsWidgets);
    expect(
      find.byKey(const ValueKey('complete-deployment-button')),
      findsOneWidget,
    );

    await _tapByKey(tester, 'back-from-deployment-button');
    await _finishNavigation(tester);
    await _revealDeployment(tester, 'DEP-120');

    expect(
      find.descendant(
        of: _deploymentCard('DEP-120'),
        matching: find.text('Active'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('deleting a Draft returns to List and removes the record', (
    tester,
  ) async {
    await _pumpDemo(tester);
    await _createDraft(tester, routeName: 'Delete Me');
    await _openDetails(tester, 'DEP-TEST-001');

    await _tapByKey(tester, 'delete-deployment-button');
    expect(find.text('Delete prototype record?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-delete-deployment')));
    await _finishNavigation(tester);

    expect(find.byType(DeploymentListScreen), findsOneWidget);
    expect(_deploymentCard('DEP-TEST-001'), findsNothing);
    expect(find.text('Deployment not found'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('deployment-total-count')),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(_summaryValue(tester, 'deployment-total-count'), '1');
  });

  testWidgets('validation failure remains on the Create form', (tester) async {
    await _pumpDemo(tester);
    await _openCreate(tester);

    await _tapByKey(tester, 'save-draft-button');
    await _finishOperation(tester);

    expect(find.byType(DeploymentFormScreen), findsOneWidget);
    expect(find.text('Route ID is required.'), findsOneWidget);
  });

  testWidgets('CRUD changes reset after the whole demo app restarts', (
    tester,
  ) async {
    await _pumpDemo(tester);
    await _createDraft(tester, routeName: 'Temporary Session Route');
    expect(_deploymentCard('DEP-TEST-001'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    await _pumpDemo(tester);

    expect(find.byType(DeploymentListScreen), findsOneWidget);
    expect(_deploymentCard('DEP-TEST-001'), findsNothing);
    expect(_summaryValue(tester, 'deployment-total-count'), '1');
  });

  testWidgets('disposing the demo disposes owned state without throwing', (
    tester,
  ) async {
    await _pumpDemo(tester);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders at 320px without horizontal overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpDemo(tester);

    expect(find.text('Module 3 Prototype'), findsOneWidget);
    expect(find.byType(DeploymentListScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _testClock = DateTime(2026, 8, 27, 12);

Future<void> _pumpDemo(WidgetTester tester) async {
  await tester.pumpWidget(
    DeploymentDemoApp(
      clock: () => _testClock,
      deploymentIdGenerator: (sequence) =>
          'DEP-TEST-${sequence.toString().padLeft(3, '0')}',
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _openCreate(WidgetTester tester) async {
  await _tapByKey(tester, 'new-deployment-button');
  await _finishNavigation(tester);
}

Future<void> _openDetails(WidgetTester tester, String deploymentId) async {
  final card = _deploymentCard(deploymentId);
  await tester.scrollUntilVisible(
    card,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.tap(card);
  await _finishNavigation(tester);
  await tester.pump();
}

Future<void> _enterValidDeployment(
  WidgetTester tester, {
  required String routeName,
}) async {
  await tester.enterText(find.byKey(const ValueKey('route-id-field')), 'D300');
  await tester.enterText(
    find.byKey(const ValueKey('route-name-field')),
    routeName,
  );
  await tester.enterText(
    find.byKey(const ValueKey('vehicle-ids-field')),
    'DEMO-BUS-1, DEMO-BUS-2',
  );
  await tester.enterText(
    find.byKey(const ValueKey('purpose-field')),
    'Staff-confirmed prototype deployment',
  );
}

Future<void> _createDraft(
  WidgetTester tester, {
  required String routeName,
}) async {
  await _openCreate(tester);
  await _enterValidDeployment(tester, routeName: routeName);
  await _tapByKey(tester, 'save-draft-button');
  await _finishNavigation(tester);
  await _revealDeployment(tester, 'DEP-TEST-001');
  expect(_deploymentCard('DEP-TEST-001'), findsOneWidget);
}

Future<void> _revealDeployment(WidgetTester tester, String deploymentId) async {
  await tester.scrollUntilVisible(
    _deploymentCard(deploymentId),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

Future<void> _tapByKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pump();
  final owningScrollable = find.ancestor(
    of: finder,
    matching: find.byType(Scrollable),
  );
  if (owningScrollable.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: owningScrollable.last,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _finishNavigation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
  await tester.pump();
}

Future<void> _finishOperation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Finder _deploymentCard(String deploymentId) {
  return find.byKey(ValueKey('deployment-card-$deploymentId'));
}

String _fieldText(WidgetTester tester, String key) {
  return tester
      .widget<TextFormField>(find.byKey(ValueKey(key)))
      .controller!
      .text;
}

String _summaryValue(WidgetTester tester, String key) {
  return tester.widget<Text>(find.byKey(ValueKey(key))).data!;
}
