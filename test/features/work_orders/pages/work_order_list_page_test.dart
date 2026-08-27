import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/work_orders/controllers/work_orders_controller.dart';
import 'package:prasa_assist/features/work_orders/data/in_memory_work_order_repository.dart';
import 'package:prasa_assist/features/work_orders/pages/work_order_list_page.dart';

void main() {
  testWidgets('shows labelled mock scenario and opens its details', (
    tester,
  ) async {
    await tester.pumpWidget(const _TestHost(child: WorkOrderListPage()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Local demonstration data only'),
      findsOneWidget,
    );
    expect(
      find.textContaining('not government, live, or real-time'),
      findsOneWidget,
    );
    expect(find.text('B1023 · Vehicle inspection'), findsOneWidget);
    expect(find.textContaining('Route 300'), findsOneWidget);
    expect(
      find.textContaining('AI recommends. Staff decides.'),
      findsOneWidget,
    );

    await tester.tap(find.text('B1023 · Vehicle inspection'));
    await tester.pumpAndSettle();
    expect(find.text('Work order details'), findsOneWidget);
    expect(find.text('WO-DEMO-001'), findsOneWidget);
  });

  testWidgets('shows the shared empty state for an empty repository', (
    tester,
  ) async {
    final controller = WorkOrdersController(
      InMemoryWorkOrderRepository(initialWorkOrders: []),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _TestHost(child: WorkOrderListPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No work orders'), findsOneWidget);
    expect(find.text('Create work order'), findsOneWidget);
  });

  testWidgets('remains overflow-free on a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const _TestHost(child: WorkOrderListPage()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(theme: AppTheme.light, home: child);
  }
}
