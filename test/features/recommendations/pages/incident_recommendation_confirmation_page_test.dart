import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/theme/app_theme.dart';
import 'package:prasa_assist/features/incidents/incident_module.dart'
    hide VehicleCondition;
import 'package:prasa_assist/features/recommendations/data/dto/recommendation_record_dto.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_policy.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_status.dart';
import 'package:prasa_assist/features/recommendations/pages/incident_recommendation_confirmation_page.dart';
import 'package:prasa_assist/features/recommendations/repositories/recommendation_data_exception.dart';
import 'package:prasa_assist/features/recommendations/repositories/recommendation_repository.dart';
import 'package:prasa_assist/features/recommendations/services/deterministic_recommendation_rule_engine.dart';
import 'package:prasa_assist/features/recommendations/services/explainable_confidence_scorer.dart';
import 'package:prasa_assist/features/recommendations/services/incident_recommendation_submission_service.dart';

void main() {
  testWidgets('opening the page creates zero recommendations', (tester) async {
    await _prepare(tester);
    final repository = _Repository();

    await tester.pumpWidget(_page(repository: repository));

    expect(repository.createCalls, 0);
  });

  testWidgets('displays the supplied incident facts', (tester) async {
    await _prepare(tester);
    await tester.pumpWidget(_page());
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Incident ID: INC-20260828-001'), findsOneWidget);
    expect(find.text('Vehicle ID: B1023'), findsOneWidget);
    expect(find.text('Route ID: 300'), findsOneWidget);
    expect(find.text('Incident type: vehicle_breakdown'), findsOneWidget);
  });

  testWidgets('demo peak is a prefill only and is labelled', (tester) async {
    await _prepare(tester);
    final repository = _Repository();

    await tester.pumpWidget(_page(repository: repository));

    expect(find.text('Peak'), findsOneWidget);
    expect(find.textContaining('Demonstration data'), findsOneWidget);
    await tester.tap(find.byKey(const Key('submit-incident-recommendation')));
    await tester.pump();

    expect(repository.createCalls, 0);
    expect(
      find.text('Staff must explicitly confirm the breakdown.'),
      findsOneWidget,
    );
  });

  testWidgets('missing confirmations block submission', (tester) async {
    await _prepare(tester);
    final repository = _Repository();
    await tester.pumpWidget(_page(repository: repository));

    await tester.tap(find.byKey(const Key('breakdown-confirmation-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit-incident-recommendation')));
    await tester.pump();

    expect(repository.createCalls, 0);
    expect(
      find.text('Staff must explicitly confirm the operating period.'),
      findsOneWidget,
    );
  });

  testWidgets('unknown operating period is blocked', (tester) async {
    await _prepare(tester);
    final repository = _Repository();
    await tester.pumpWidget(_page(repository: repository));

    await tester.tap(find.byKey(const Key('operating-period-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unknown').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('breakdown-confirmation-checkbox')));
    await tester.tap(
      find.byKey(const Key('operating-period-confirmation-checkbox')),
    );
    await tester.tap(find.byKey(const Key('submit-incident-recommendation')));
    await tester.pump();

    expect(repository.createCalls, 0);
    expect(
      find.text('Select and explicitly confirm an operating period.'),
      findsOneWidget,
    );
  });

  testWidgets('invalid and non-breakdown facts are handled safely', (
    tester,
  ) async {
    await _prepare(tester);
    final repository = _Repository();
    final facts = M1IncidentRecommendationFacts.fromIncident(
      IncidentDemoData.busB1023().copyWith(incidentType: IncidentType.accident),
      generatedAt: DateTime.utc(2026, 8, 30),
    );
    await tester.pumpWidget(_page(facts: facts, repository: repository));
    await _confirmValidSelections(tester);

    expect(repository.createCalls, 0);
    expect(
      find.text(
        'Only a vehicle breakdown can be converted to this recommendation input.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('missing vehicle ID is handled safely', (tester) async {
    await _prepare(tester);
    final repository = _Repository();
    final facts = M1IncidentRecommendationFacts.fromIncident(
      IncidentDemoData.busB1023().copyWith(vehicleId: null),
      generatedAt: DateTime.utc(2026, 8, 30),
    );
    await tester.pumpWidget(_page(facts: facts, repository: repository));
    await _selectPeak(tester);
    await _confirmValidSelections(tester, selectPeriod: false);

    expect(repository.createCalls, 0);
    expect(
      find.text('A vehicle-based recommendation requires a vehicle ID.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'valid explicit submission creates one pending record and returns it',
    (tester) async {
      await _prepare(tester);
      final repository = _Repository();
      RecommendationRecordDto? submitted;
      await tester.pumpWidget(
        _page(
          repository: repository,
          onSubmitted: (record) => submitted = record,
        ),
      );
      await _confirmValidSelections(tester);

      expect(repository.createCalls, 1);
      expect(
        submitted?.recommendation.status,
        RecommendationStatus.pendingReview,
      );
    },
  );

  testWidgets('double taps while submitting create only one recommendation', (
    tester,
  ) async {
    await _prepare(tester);
    final completer = Completer<RecommendationRecordDto>();
    final repository = _Repository(createCompleter: completer);
    await tester.pumpWidget(_page(repository: repository));
    await _selectPeak(tester);
    await tester.tap(find.byKey(const Key('breakdown-confirmation-checkbox')));
    await tester.tap(
      find.byKey(const Key('operating-period-confirmation-checkbox')),
    );
    await tester.tap(find.byKey(const Key('submit-incident-recommendation')));
    await tester.tap(find.byKey(const Key('submit-incident-recommendation')));
    await tester.pump();

    expect(repository.createCalls, 1);
    completer.complete(repository.pendingRecord!);
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
  });

  testWidgets('submission errors are shown safely', (tester) async {
    await _prepare(tester);
    final repository = _Repository(
      createError: const RecommendationOfflineException(
        'Recommendation service is unavailable.',
      ),
    );
    await tester.pumpWidget(_page(repository: repository));
    await _confirmValidSelections(tester);

    expect(repository.createCalls, 1);
    expect(find.text('Recommendation service is unavailable.'), findsOneWidget);
  });
}

Future<void> _prepare(WidgetTester tester) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(800, 1000));
}

Widget _page({
  M1IncidentRecommendationFacts? facts,
  _Repository? repository,
  ValueChanged<RecommendationRecordDto>? onSubmitted,
}) {
  final effectiveRepository = repository ?? _Repository();
  return MaterialApp(
    theme: AppTheme.light,
    home: IncidentRecommendationConfirmationPage(
      facts: facts ?? _facts(),
      ownerUserId: '11111111-1111-4111-8111-111111111111',
      recommendationIdGenerator: () => '22222222-2222-4222-8222-222222222222',
      submissionService: IncidentRecommendationSubmissionService(
        repository: effectiveRepository,
        ruleEngine: DeterministicRecommendationRuleEngine(
          policy: RecommendationRulePolicy.ownerApproved(),
          confidenceScorer: const ExplainableConfidenceScorer(),
        ),
      ),
      clock: () => DateTime.utc(2026, 8, 30, 9),
      onSubmitted: onSubmitted,
    ),
  );
}

M1IncidentRecommendationFacts _facts() =>
    M1IncidentRecommendationFacts.fromIncident(
      IncidentDemoData.busB1023(),
      generatedAt: DateTime.utc(2026, 8, 30),
    );

Future<void> _selectPeak(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('operating-period-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Peak').last);
  await tester.pumpAndSettle();
}

Future<void> _confirmValidSelections(
  WidgetTester tester, {
  bool selectPeriod = true,
}) async {
  if (selectPeriod) await _selectPeak(tester);
  await tester.tap(find.byKey(const Key('breakdown-confirmation-checkbox')));
  await tester.tap(
    find.byKey(const Key('operating-period-confirmation-checkbox')),
  );
  await tester.tap(find.byKey(const Key('submit-incident-recommendation')));
  await tester.pumpAndSettle();
}

class _Repository implements RecommendationRepository {
  _Repository({this.createCompleter, this.createError});

  final Completer<RecommendationRecordDto>? createCompleter;
  final Object? createError;
  final records = <String, RecommendationRecordDto>{};
  var createCalls = 0;
  RecommendationRecordDto? pendingRecord;

  @override
  Future<RecommendationRecordDto> createPending(
    RecommendationRecordDto record,
  ) async {
    createCalls++;
    pendingRecord = record;
    if (createError != null) throw createError!;
    final completer = createCompleter;
    if (completer != null) return completer.future;
    records[record.recommendation.id] = record;
    return record;
  }

  @override
  Future<RecommendationRecordDto> decide(
    String id, {
    required String decision,
    String? note,
    required int expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<RecommendationRecordDto> generateAnalysis(String id) =>
      throw UnimplementedError();

  @override
  Future<List<RecommendationRecordDto>> readAll() async =>
      records.values.toList(growable: false);

  @override
  Future<RecommendationRecordDto?> readById(String id) async => records[id];
}
