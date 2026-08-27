import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/shared/widgets/app_empty_state.dart';
import 'package:prasa_assist/shared/widgets/app_error_state.dart';
import 'package:prasa_assist/shared/widgets/app_loading_indicator.dart';
import 'package:prasa_assist/shared/widgets/app_status_chip.dart';

void main() {
  testWidgets('empty state renders content and invokes its action', (
    tester,
  ) async {
    var actionInvoked = false;

    await tester.pumpWidget(
      _TestHost(
        child: AppEmptyState(
          title: 'No records',
          message: 'There is nothing to display yet.',
          actionLabel: 'Create record',
          onAction: () => actionInvoked = true,
        ),
      ),
    );

    expect(find.text('No records'), findsOneWidget);
    expect(find.text('There is nothing to display yet.'), findsOneWidget);
    await tester.tap(find.text('Create record'));
    expect(actionInvoked, isTrue);
  });

  testWidgets('loading indicator renders progress and message', (tester) async {
    await tester.pumpWidget(
      const _TestHost(
        child: AppLoadingIndicator(message: 'Loading operations data'),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading operations data'), findsOneWidget);
  });

  testWidgets('status chips render all shared semantic tones', (tester) async {
    await tester.pumpWidget(
      const _TestHost(
        child: Wrap(
          children: [
            AppStatusChip(label: 'Neutral'),
            AppStatusChip(
              label: 'Information',
              tone: AppStatusTone.information,
            ),
            AppStatusChip(label: 'Success', tone: AppStatusTone.success),
            AppStatusChip(label: 'Warning', tone: AppStatusTone.warning),
            AppStatusChip(label: 'Error', tone: AppStatusTone.error),
          ],
        ),
      ),
    );

    expect(find.byType(Chip), findsNWidgets(5));
    expect(find.text('Success'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);
  });

  testWidgets('error state renders content and invokes retry', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      _TestHost(
        child: AppErrorState(
          title: 'Unable to load',
          message: 'Check the connection and try again.',
          actionLabel: 'Retry',
          onAction: () => retried = true,
        ),
      ),
    );

    expect(find.text('Unable to load'), findsOneWidget);
    expect(find.text('Check the connection and try again.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );
  }
}
