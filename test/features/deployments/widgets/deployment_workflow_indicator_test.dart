import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/models/deployment_status.dart';
import 'package:prasa_assist/features/deployments/widgets/deployment_workflow_indicator.dart';

void main() {
  testWidgets('shows Draft as the current workflow stage', (tester) async {
    await _pumpIndicator(tester, DeploymentStatus.draft);

    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(_semanticsLabel('Draft, current workflow stage'), findsOneWidget);
  });

  testWidgets('shows Scheduled after the completed Draft stage', (
    tester,
  ) async {
    await _pumpIndicator(tester, DeploymentStatus.scheduled);

    expect(_semanticsLabel('Draft, completed workflow stage'), findsOneWidget);
    expect(
      _semanticsLabel('Scheduled, current workflow stage'),
      findsOneWidget,
    );
    expect(_semanticsLabel('Active, future workflow stage'), findsOneWidget);
  });

  testWidgets('shows Active after completed earlier stages', (tester) async {
    await _pumpIndicator(tester, DeploymentStatus.active);

    expect(_semanticsLabel('Draft, completed workflow stage'), findsOneWidget);
    expect(
      _semanticsLabel('Scheduled, completed workflow stage'),
      findsOneWidget,
    );
    expect(_semanticsLabel('Active, current workflow stage'), findsOneWidget);
    expect(_semanticsLabel('Completed, future workflow stage'), findsOneWidget);
  });

  testWidgets('shows Completed as the current terminal main stage', (
    tester,
  ) async {
    await _pumpIndicator(tester, DeploymentStatus.completed);

    expect(
      _semanticsLabel('Completed, current workflow stage'),
      findsOneWidget,
    );
    expect(
      find.text('Cancelled — alternative terminal outcome'),
      findsOneWidget,
    );
  });

  testWidgets('shows Cancelled as an alternative terminal outcome', (
    tester,
  ) async {
    await _pumpIndicator(tester, DeploymentStatus.cancelled);

    expect(find.text('Cancelled — workflow stopped'), findsOneWidget);
    expect(
      _semanticsLabel('Cancelled, current alternative terminal outcome'),
      findsOneWidget,
    );
    expect(
      _semanticsLabel('Draft, workflow stage, transition history unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('provides overall semantics without claiming audit history', (
    tester,
  ) async {
    await _pumpIndicator(tester, DeploymentStatus.active);

    expect(
      _semanticsLabel(
        'Deployment workflow. Current status: Active. This shows the '
        'configured workflow, not recorded transition history.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Workflow position only — no historical transition timestamps '
        'are recorded here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses a vertical layout without overflow at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpIndicator(tester, DeploymentStatus.cancelled);

    expect(tester.takeException(), isNull);
    final stagePositions = [
      tester.getTopLeft(find.text('Draft')).dx,
      tester.getTopLeft(find.text('Scheduled')).dx,
      tester.getTopLeft(find.text('Active')).dx,
      tester.getTopLeft(find.text('Completed')).dx,
    ];
    expect(stagePositions.toSet(), hasLength(1));
  });
}

Future<void> _pumpIndicator(
  WidgetTester tester,
  DeploymentStatus status,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: DeploymentWorkflowIndicator(currentStatus: status),
        ),
      ),
    ),
  );
}

Finder _semanticsLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
    description: 'Semantics with label "$label"',
  );
}
