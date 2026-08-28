import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/local_sync_state.dart';
import 'package:prasa_assist/features/deployments/data/dto/local_deployment_draft.dart';
import 'package:prasa_assist/features/deployments/data/dto/local_deployment_record.dart';
import 'package:prasa_assist/features/deployments/widgets/local_deployment_work_card.dart';

void main() {
  testWidgets(
    'local draft is clearly unpublished and offers explicit actions',
    (tester) async {
      var edits = 0;
      var publishes = 0;
      var discards = 0;
      await _pump(
        tester,
        _record(LocalSyncState.localDraft),
        onEdit: () => edits++,
        onPublish: () => publishes++,
        onDiscard: () => discards++,
      );

      expect(find.text('Local draft — not published'), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);
      expect(find.text('Discard draft'), findsOneWidget);
      expect(find.textContaining('B1023'), findsNothing);

      await tester.tap(find.text('Edit'));
      await tester.tap(find.text('Publish'));
      await tester.tap(find.text('Discard draft'));
      expect((edits, publishes, discards), (1, 1, 1));
    },
  );

  testWidgets('failed publication offers a staff-controlled retry', (
    tester,
  ) async {
    await _pump(tester, _record(LocalSyncState.publicationFailed));

    expect(find.text('Publication failed'), findsOneWidget);
    expect(find.text('Retry publication'), findsOneWidget);
    expect(find.text('Publication was not confirmed.'), findsOneWidget);
    expect(find.text('Discard draft'), findsNothing);
  });

  testWidgets('pending publication disables duplicate actions', (tester) async {
    await _pump(tester, _record(LocalSyncState.pendingPublication));

    expect(find.text('Pending publication'), findsOneWidget);
    expect(find.text('Publish'), findsNothing);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('conflict requires review without offering silent retry', (
    tester,
  ) async {
    await _pump(tester, _record(LocalSyncState.conflict));

    expect(find.textContaining('staff review required'), findsOneWidget);
    expect(find.textContaining('Review and edit'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.textContaining('publication'), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester,
  LocalDeploymentRecord record, {
  VoidCallback? onEdit,
  VoidCallback? onPublish,
  VoidCallback? onDiscard,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LocalDeploymentWorkCard(
            record: record,
            onEdit: onEdit,
            onPublish: onPublish,
            onDiscard: onDiscard,
          ),
        ),
      ),
    ),
  );
}

LocalDeploymentRecord _record(LocalSyncState state) {
  final needsMessage =
      state == LocalSyncState.publicationFailed ||
      state == LocalSyncState.conflict;
  return LocalDeploymentRecord(
    localId: 'local-1',
    ownerUserId: '11111111-1111-4111-8111-111111111111',
    draft: LocalDeploymentDraft(
      routeId: '300',
      routeName: 'Terminal Maluri ~ Lebuh Ampang',
      vehicleIds: const ['REPLACEMENT-BUS-01', 'REPLACEMENT-BUS-02'],
      startTime: DateTime.utc(2026, 8, 27, 20, 40),
      endTime: DateTime.utc(2026, 8, 27, 21, 40),
      purpose: 'Replacement service',
    ),
    status: 'draft',
    syncState: state,
    localCreatedAt: DateTime.utc(2026, 8, 28),
    localModifiedAt: DateTime.utc(2026, 8, 28),
    safeErrorMessage: needsMessage
        ? state == LocalSyncState.conflict
              ? 'This deployment changed remotely.'
              : 'Publication was not confirmed.'
        : null,
  );
}
