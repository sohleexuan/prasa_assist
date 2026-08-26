import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/models/deployment_status.dart';
import 'package:prasa_assist/features/deployments/widgets/deployment_status_chip.dart';

void main() {
  testWidgets('displays every status label with accessibility semantics', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();

    for (final status in DeploymentStatus.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DeploymentStatusChip(status: status)),
        ),
      );

      expect(find.text(status.displayLabel), findsOneWidget);
      expect(
        find.bySemanticsLabel('Deployment status: ${status.displayLabel}'),
        findsOneWidget,
      );
    }

    semanticsHandle.dispose();
  });
}
