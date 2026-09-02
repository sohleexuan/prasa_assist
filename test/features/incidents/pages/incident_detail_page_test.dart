import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/incidents/controllers/incident_controller.dart';
import 'package:prasa_assist/features/incidents/data/incident_demo_data.dart';
import 'package:prasa_assist/features/incidents/integration/m1_incident_recommendation_facts.dart';
import 'package:prasa_assist/features/incidents/models/incident.dart';
import 'package:prasa_assist/features/incidents/models/incident_enums.dart';
import 'package:prasa_assist/features/incidents/models/incident_query.dart';
import 'package:prasa_assist/features/incidents/pages/incident_detail_page.dart';
import 'package:prasa_assist/features/incidents/repositories/in_memory_incident_repository.dart';

void main() {
  testWidgets('loads complete operational, evidence, and audit details', (
    tester,
  ) async {
    await _pumpDetail(tester);

    expect(find.text('Incident Details'), findsOneWidget);
    expect(find.text('Bus B1023 breakdown'), findsOneWidget);
    expect(find.text('INC-20260828-001'), findsOneWidget);
    expect(find.text('Route 300'), findsOneWidget);
    expect(find.text('B1023'), findsOneWidget);
    expect(find.text('2026-08-28 07:55 MYT'), findsOneWidget);
    expect(find.text('75 min'), findsOneWidget);
    expect(find.text('Mock / Demonstration Data'), findsWidgets);
    expect(
      find.textContaining('not an official Prasarana model'),
      findsOneWidget,
    );
    expect(find.text('Status History'), findsOneWidget);
    expect(find.text('Reported'), findsWidgets);
    expect(
      find.textContaining('PrasaAssist demonstration rules'),
      findsWidgets,
    );
  });

  testWidgets('shows loading while detail retrieval is waiting', (
    tester,
  ) async {
    final repository = _DelayedDetailRepository();
    final controller = IncidentController(repository: repository);
    addTearDown(controller.dispose);

    await _pumpDetail(tester, controller: controller, finishLoading: false);
    expect(find.text('Loading incident details...'), findsOneWidget);

    repository.complete(IncidentDemoData.busB1023());
    await tester.pump();
    await tester.pump();
    expect(find.text('Bus B1023 breakdown'), findsOneWidget);
  });

  testWidgets('shows a safe not-found state', (tester) async {
    await _pumpDetail(tester, incidentId: 'INC-MISSING');

    expect(find.text('Incident not found'), findsOneWidget);
    expect(find.text('Incident INC-MISSING does not exist.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('changes status only after confirmation and records the note', (
    tester,
  ) async {
    final repository = _repository();
    final controller = IncidentController(repository: repository);
    Incident? changedIncident;
    addTearDown(controller.dispose);
    await _pumpDetail(
      tester,
      controller: controller,
      onStatusChanged: (value) => changedIncident = value,
    );

    await _tapAction(tester, 'incident-status-action-underReview');
    expect(find.text('Mark incident Under Review?'), findsOneWidget);
    expect(find.text('AI recommends. Staff decides.'), findsOneWidget);
    expect(
      (await repository.getById('INC-20260828-001'))?.status,
      IncidentStatus.reported,
    );

    await tester.enterText(
      find.byKey(const ValueKey('incident-status-note-field')),
      'Supervisor reviewed the initial report.',
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-incident-status-underReview')),
    );
    await tester.pump();
    await tester.pump();

    expect(changedIncident?.status, IncidentStatus.underReview);
    expect(changedIncident?.statusHistory, hasLength(2));
    expect(
      changedIncident?.statusHistory.last.note,
      'Supervisor reviewed the initial report.',
    );
    expect(find.text('Reported → Under Review'), findsOneWidget);
    expect(find.textContaining('staff-001'), findsWidgets);
  });

  testWidgets('dismisses a status dialog without changing data', (
    tester,
  ) async {
    final repository = _repository();
    await _pumpDetail(tester, repository: repository);

    await _tapAction(tester, 'incident-status-action-cancelled');
    expect(find.textContaining('remain for audit'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('dismiss-incident-status-dialog')),
    );
    await tester.pump();

    expect(
      (await repository.getById('INC-20260828-001'))?.status,
      IncidentStatus.reported,
    );
  });

  testWidgets('requires staff identity before a status change', (tester) async {
    await _pumpDetail(tester, currentStaffId: '   ');

    await _tapAction(tester, 'incident-status-action-underReview');
    await tester.tap(
      find.byKey(const ValueKey('confirm-incident-status-underReview')),
    );
    await tester.pump();

    expect(find.text('Incident action failed'), findsOneWidget);
    expect(find.textContaining('staff identity is required'), findsOneWidget);
  });

  testWidgets('terminal incidents are read-only and expose no status actions', (
    tester,
  ) async {
    final repository = await _repositoryAtStatus(IncidentStatus.resolved);
    var editCount = 0;
    await _pumpDetail(
      tester,
      repository: repository,
      onEdit: (_) => editCount++,
    );

    expect(find.text('Resolved Incident'), findsOneWidget);
    expect(find.textContaining('status is terminal'), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-incident-action')), findsNothing);
    expect(
      find.byKey(const ValueKey('incident-status-action-cancelled')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('delete-incident-button')), findsNothing);
    expect(editCount, 0);
  });

  testWidgets('invokes Edit only for a non-terminal incident', (tester) async {
    Incident? edited;
    await _pumpDetail(tester, onEdit: (value) => edited = value);

    await tester.tap(find.byKey(const ValueKey('edit-incident-action')));
    await tester.pump();

    expect(edited?.incidentId, 'INC-20260828-001');
  });

  testWidgets(
    'shows the recommendation CTA for an eligible vehicle breakdown',
    (tester) async {
      await _pumpDetail(tester, onPrepareIncidentRecommendation: (_) {});

      expect(
        find.byKey(const ValueKey('prepare-ai-recommendation-action')),
        findsOneWidget,
      );
      expect(find.text('Prepare AI Recommendation'), findsOneWidget);
    },
  );

  testWidgets('hides the recommendation CTA for missing or blank vehicle IDs', (
    tester,
  ) async {
    for (final vehicleId in <String?>[null, '   ']) {
      final repository = _FixedDetailRepository(
        IncidentDemoData.busB1023().copyWith(vehicleId: vehicleId),
      );
      await _pumpDetail(
        tester,
        repository: repository,
        onPrepareIncidentRecommendation: (_) {},
      );

      expect(
        find.byKey(const ValueKey('prepare-ai-recommendation-action')),
        findsNothing,
      );
    }
  });

  testWidgets('hides the recommendation CTA for a non-breakdown incident', (
    tester,
  ) async {
    final repository = InMemoryIncidentRepository(
      seedData: [
        IncidentDemoData.busB1023().copyWith(
          incidentType: IncidentType.serviceDisruption,
        ),
      ],
      clock: _clock,
    );
    await _pumpDetail(
      tester,
      repository: repository,
      onPrepareIncidentRecommendation: (_) {},
    );

    expect(
      find.byKey(const ValueKey('prepare-ai-recommendation-action')),
      findsNothing,
    );
  });

  testWidgets(
    'hides the recommendation CTA for resolved and cancelled incidents',
    (tester) async {
      for (final status in <IncidentStatus>[
        IncidentStatus.resolved,
        IncidentStatus.cancelled,
      ]) {
        final repository = await _repositoryAtStatus(status);
        await _pumpDetail(
          tester,
          repository: repository,
          onPrepareIncidentRecommendation: (_) {},
        );

        expect(
          find.byKey(const ValueKey('prepare-ai-recommendation-action')),
          findsNothing,
        );
      }
    },
  );

  testWidgets('exports immutable facts once without modifying the incident', (
    tester,
  ) async {
    final repository = _repository();
    final before = await repository.getById('INC-20260828-001');
    M1IncidentRecommendationFacts? receivedFacts;
    var callbackCount = 0;

    await _pumpDetail(
      tester,
      repository: repository,
      clock: () => DateTime(2026, 8, 30, 17, 30),
      onPrepareIncidentRecommendation: (facts) {
        callbackCount++;
        receivedFacts = facts;
      },
    );

    await _tapAction(tester, 'prepare-ai-recommendation-action');

    expect(callbackCount, 1);
    expect(receivedFacts?.incidentId, 'INC-20260828-001');
    expect(receivedFacts?.vehicleId, 'B1023');
    expect(receivedFacts?.routeId, '300');
    expect(receivedFacts?.incidentDataClassification, 'mock_demonstration');
    expect(receivedFacts?.delayEstimateClassification, 'demonstration_rule');
    expect(receivedFacts?.generatedAtUtc, DateTime.utc(2026, 8, 30, 9, 30));
    expect(await repository.getById('INC-20260828-001'), before);
  });

  testWidgets('warns, allows dismissal, then permanently deletes', (
    tester,
  ) async {
    final repository = _repository();
    var deletedCount = 0;
    await _pumpDetail(
      tester,
      repository: repository,
      onDeleted: () => deletedCount++,
    );

    await _tapAction(tester, 'delete-incident-button');
    expect(find.text('Delete Incident permanently?'), findsOneWidget);
    expect(find.textContaining('cannot be recovered'), findsOneWidget);
    expect(find.textContaining('Cancelled instead'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('dismiss-delete-incident-dialog')),
    );
    await tester.pump();
    expect(await repository.getById('INC-20260828-001'), isNotNull);

    await _tapAction(tester, 'delete-incident-button');
    await tester.tap(find.byKey(const ValueKey('confirm-delete-incident')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Incident deleted'), findsOneWidget);
    expect(await repository.getById('INC-20260828-001'), isNull);
    expect(deletedCount, 1);
  });

  testWidgets('Active incidents cannot be permanently deleted', (tester) async {
    final repository = await _repositoryAtStatus(IncidentStatus.active);
    await _pumpDetail(tester, repository: repository);

    expect(find.byKey(const ValueKey('delete-incident-button')), findsNothing);
    expect(
      find.byKey(const ValueKey('incident-status-action-resolved')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('incident-status-action-cancelled')),
      findsOneWidget,
    );
  });

  testWidgets('remains overflow-free at 320px width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpDetail(tester);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1500),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  IncidentController? controller,
  InMemoryIncidentRepository? repository,
  String incidentId = 'INC-20260828-001',
  String currentStaffId = 'staff-001',
  ValueChanged<Incident>? onEdit,
  ValueChanged<Incident>? onStatusChanged,
  VoidCallback? onDeleted,
  PrepareIncidentRecommendationCallback? onPrepareIncidentRecommendation,
  DateTime Function()? clock,
  bool finishLoading = true,
}) async {
  final effectiveController =
      controller ?? IncidentController(repository: repository ?? _repository());
  if (controller == null) {
    addTearDown(effectiveController.dispose);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: IncidentDetailPage(
        controller: effectiveController,
        incidentId: incidentId,
        currentStaffId: currentStaffId,
        onEdit: onEdit,
        onStatusChanged: onStatusChanged,
        onDeleted: onDeleted,
        onPrepareIncidentRecommendation: onPrepareIncidentRecommendation,
        clock: clock,
      ),
    ),
  );
  await tester.pump();
  if (finishLoading) {
    await tester.pump();
  }
}

Future<void> _tapAction(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await Scrollable.ensureVisible(
    tester.element(finder),
    alignment: 0.5,
    duration: Duration.zero,
  );
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

InMemoryIncidentRepository _repository() {
  return InMemoryIncidentRepository(
    seedData: [IncidentDemoData.busB1023()],
    clock: _clock,
  );
}

Future<InMemoryIncidentRepository> _repositoryAtStatus(
  IncidentStatus target,
) async {
  final repository = _repository();
  if (target == IncidentStatus.reported) {
    return repository;
  }
  await repository.transitionStatus(
    'INC-20260828-001',
    IncidentStatus.underReview,
    changedBy: 'staff-001',
  );
  if (target == IncidentStatus.underReview) {
    return repository;
  }
  if (target == IncidentStatus.cancelled) {
    await repository.transitionStatus(
      'INC-20260828-001',
      IncidentStatus.cancelled,
      changedBy: 'staff-001',
    );
    return repository;
  }
  await repository.transitionStatus(
    'INC-20260828-001',
    IncidentStatus.active,
    changedBy: 'staff-001',
  );
  if (target == IncidentStatus.active) {
    return repository;
  }
  await repository.transitionStatus(
    'INC-20260828-001',
    IncidentStatus.resolved,
    changedBy: 'staff-001',
  );
  return repository;
}

DateTime _clock() => DateTime(2026, 8, 28, 12);

class _DelayedDetailRepository extends InMemoryIncidentRepository {
  final Completer<Incident?> _completer = Completer<Incident?>();

  @override
  Future<Incident?> getById(String incidentId) => _completer.future;

  void complete(Incident incident) => _completer.complete(incident);

  @override
  Future<List<Incident>> getAll({IncidentQuery? query}) async => const [];
}

class _FixedDetailRepository extends InMemoryIncidentRepository {
  _FixedDetailRepository(this.incident)
    : super(seedData: [IncidentDemoData.busB1023()], clock: _clock);

  final Incident incident;

  @override
  Future<Incident?> getById(String incidentId) async =>
      incidentId == incident.incidentId ? incident : null;
}
