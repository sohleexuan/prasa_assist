import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/incidents/pages/incident_detail_page.dart';
import 'package:prasa_assist/features/incidents/pages/incident_edit_page.dart';
import 'package:prasa_assist/features/incidents/pages/incident_list_page.dart';
import 'package:prasa_assist/features/incidents/pages/incident_report_page.dart';
import 'package:prasa_assist/features/incidents/repositories/in_memory_incident_repository.dart';

void main() {
  testWidgets('completes create, read, edit, status, and delete navigation', (
    tester,
  ) async {
    final repository = InMemoryIncidentRepository.withDemonstrationData(
      clock: _clock,
    );
    await _pumpWorkflow(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('report-incident-button')));
    await tester.pumpAndSettle();
    expect(find.byType(IncidentReportPage), findsOneWidget);
    await _fillReport(tester);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('submit-incident-report-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IncidentListPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('incident-card-INC-E2E-001')),
      findsOneWidget,
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('incident-card-INC-E2E-001')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IncidentDetailPage), findsOneWidget);
    expect(find.text('End-to-end service disruption'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('edit-incident-action')));
    await tester.pumpAndSettle();
    expect(find.byType(IncidentEditPage), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('incident-title-field')),
      'Updated end-to-end disruption',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('submit-incident-edit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IncidentDetailPage), findsOneWidget);
    expect(find.text('Updated end-to-end disruption'), findsOneWidget);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('incident-status-action-underReview')),
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-incident-status-underReview')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reported → Under Review'), findsOneWidget);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('incident-status-action-cancelled')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('incident-status-note-field')),
      'Incident retained for audit; no further handling required.',
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-incident-status-cancelled')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Under Review → Cancelled'), findsOneWidget);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('delete-incident-button')),
    );
    expect(find.textContaining('cannot be recovered'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-delete-incident')));
    await tester.pumpAndSettle();

    expect(find.byType(IncidentListPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('incident-card-INC-E2E-001')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('incident-card-INC-20260828-001')),
      findsOneWidget,
    );
  });

  testWidgets('Report Cancel returns to the unchanged list', (tester) async {
    final repository = InMemoryIncidentRepository.withDemonstrationData(
      clock: _clock,
    );
    await _pumpWorkflow(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('report-incident-button')));
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('cancel-incident-report-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IncidentListPage), findsOneWidget);
    expect(await repository.getAll(), hasLength(1));
  });

  testWidgets('a new in-memory workflow resets earlier changes', (
    tester,
  ) async {
    final firstRepository = InMemoryIncidentRepository.withDemonstrationData(
      clock: _clock,
    );
    await _pumpWorkflow(tester, repository: firstRepository);
    await tester.tap(find.byKey(const ValueKey('report-incident-button')));
    await tester.pumpAndSettle();
    await _fillReport(tester);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('submit-incident-report-button')),
    );
    await tester.pumpAndSettle();
    expect(await firstRepository.getAll(), hasLength(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final restartedRepository =
        InMemoryIncidentRepository.withDemonstrationData(clock: _clock);
    await _pumpWorkflow(tester, repository: restartedRepository);

    expect(await restartedRepository.getAll(), hasLength(1));
    expect(
      find.byKey(const ValueKey('incident-card-INC-E2E-001')),
      findsNothing,
    );
    expect(
      find.textContaining('Changes reset when the app restarts'),
      findsOneWidget,
    );
  });

  testWidgets(
    'staff completes the Bus B1023 lifecycle without automatic action',
    (tester) async {
      final repository = InMemoryIncidentRepository.withDemonstrationData(
        clock: _clock,
      );
      await _pumpWorkflow(tester, repository: repository);

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('incident-card-INC-20260828-001')),
      );
      await tester.pumpAndSettle();

      for (final target in ['underReview', 'active', 'resolved']) {
        await _tapVisible(
          tester,
          find.byKey(ValueKey('incident-status-action-$target')),
        );
        await tester.tap(
          find.byKey(ValueKey('confirm-incident-status-$target')),
        );
        await tester.pumpAndSettle();
      }

      final resolved = await repository.getById('INC-20260828-001');
      expect(resolved, isNotNull);
      expect(resolved!.status.name, 'resolved');
      expect(resolved.statusHistory, hasLength(4));
      expect(find.textContaining('status is terminal'), findsOneWidget);
      expect(find.byKey(const ValueKey('edit-incident-action')), findsNothing);
      expect(
        find.byKey(const ValueKey('delete-incident-button')),
        findsNothing,
      );
    },
  );
}

Future<void> _pumpWorkflow(
  WidgetTester tester, {
  required InMemoryIncidentRepository repository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: IncidentListPage(
        currentStaffId: 'staff-e2e-001',
        repository: repository,
        clock: _clock,
        incidentIdGenerator: (_) => 'INC-E2E-001',
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _fillReport(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('incident-title-field')),
    'End-to-end service disruption',
  );
  await tester.enterText(
    find.byKey(const ValueKey('incident-description-field')),
    'Staff observed a service disruption affecting Route 300.',
  );
  await tester.enterText(
    find.byKey(const ValueKey('incident-route-id-field')),
    '300',
  );
  await tester.enterText(
    find.byKey(const ValueKey('incident-route-name-field')),
    'Route 300',
  );
  await tester.enterText(
    find.byKey(const ValueKey('incident-vehicle-id-field')),
    'B2048',
  );
  await tester.enterText(
    find.byKey(const ValueKey('incident-location-field')),
    'Jalan Ampang',
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  tester.binding.focusManager.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(
    tester.element(finder),
    alignment: 0.4,
    duration: Duration.zero,
  );
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

DateTime _clock() => DateTime(2026, 8, 28, 12);
