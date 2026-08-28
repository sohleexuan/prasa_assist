import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/models/deployment_read_result.dart';
import 'package:prasa_assist/features/deployments/widgets/deployment_data_notice.dart';

void main() {
  testWidgets('shows live Supabase provenance and cache warning', (
    tester,
  ) async {
    await _pump(
      tester,
      DeploymentReadProvenance(
        source: DeploymentReadSource.liveSupabase,
        retrievedAtUtc: DateTime.utc(2026, 8, 28, 3),
        warningMessage: 'Live Supabase data loaded, but the offline cache could not be refreshed.',
      ),
    );

    final sourceLabel = tester.widget<Text>(
      find.byKey(const ValueKey('deployment-data-source-label')),
    );
    expect(sourceLabel.data, contains('Live Supabase data'));
    expect(find.textContaining('28 Aug 2026, 03:00 UTC'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('deployment-provenance-warning')),
      findsOneWidget,
    );
  });

  testWidgets('labels cached SQLite records as offline and not live', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      DeploymentReadProvenance(
        source: DeploymentReadSource.cachedSqlite,
        retrievedAtUtc: DateTime.utc(2026, 8, 28, 2, 15),
        warningMessage:
            'Showing cached SQLite data because Supabase is unreachable.',
      ),
    );

    expect(find.textContaining('Cached/offline SQLite data'), findsOneWidget);
    expect(find.textContaining('28 Aug 2026, 02:15 UTC'), findsOneWidget);
    expect(
      find.textContaining('because Supabase is unreachable'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, DeploymentReadProvenance provenance) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeploymentDataNotice(isPersistent: true, provenance: provenance),
      ),
    ),
  );
}
