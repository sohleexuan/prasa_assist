import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/work_orders/models/work_order.dart';
import 'package:prasa_assist/features/work_orders/widgets/work_order_priority_chip.dart';
import 'package:prasa_assist/shared/widgets/app_status_chip.dart';

void main() {
  testWidgets('maps every priority to the approved shared status tone', (
    tester,
  ) async {
    const expected = {
      WorkOrderPriority.low: AppStatusTone.neutral,
      WorkOrderPriority.medium: AppStatusTone.information,
      WorkOrderPriority.high: AppStatusTone.warning,
      WorkOrderPriority.urgent: AppStatusTone.error,
    };

    for (final entry in expected.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: WorkOrderPriorityChip(priority: entry.key)),
        ),
      );
      final chip = tester.widget<AppStatusChip>(find.byType(AppStatusChip));
      expect(chip.label, entry.key.label);
      expect(chip.tone, entry.value);
    }
  });
}
