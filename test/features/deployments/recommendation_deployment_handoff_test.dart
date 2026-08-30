import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/repositories/in_memory_deployment_repository.dart';
import 'package:prasa_assist/features/deployments/screens/deployment_form_screen.dart';
import 'package:prasa_assist/features/deployments/service_deployment_page.dart';
import 'package:prasa_assist/features/recommendations/data/dto/recommendation_record_dto.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_status.dart';
import 'package:prasa_assist/features/recommendations/services/recommendation_deployment_prefill_factory.dart';

void main() {
  testWidgets(
    'accepted replacement-bus recommendation opens an editable deployment prefill',
    (tester) async {
      final repository = InMemoryDeploymentRepository.withDemonstrationData();
      final prefill = const RecommendationDeploymentPrefillFactory().create(
        RecommendationRecordDto(recommendation: _acceptedRecommendation()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ServiceDeploymentPage(
            repository: repository,
            initialCreatePrefill: prefill,
            currentUserId: 'Operations Staff',
            deploymentIdGenerator: (_) => 'DEP-REC-300',
            clock: () => DateTime(2026, 8, 30, 9),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(DeploymentFormScreen), findsOneWidget);
      expect(_fieldText(tester, 'route-id-field'), '300');
      expect(_fieldText(tester, 'incident-id-field'), 'INC-B1023-300');
      expect(_fieldText(tester, 'recommendation-id-field'), 'REC-B1023-300');
      expect(
        _fieldText(tester, 'purpose-field'),
        'Provide 2 replacement buses for Route 300. '
        'Staff must review and save the draft.',
      );
      expect(
        find.text(
          'Recommendation suggests 2 vehicles. '
          'Staff must select the actual vehicles.',
        ),
        findsOneWidget,
      );
      expect(_fieldText(tester, 'vehicle-ids-field'), isEmpty);
      expect((await repository.getAll()), hasLength(1));

      await tester.enterText(
        find.byKey(const ValueKey('route-name-field')),
        'Terminal Maluri ~ Lebuh Ampang',
      );
      await tester.enterText(
        find.byKey(const ValueKey('vehicle-ids-field')),
        'REPLACEMENT-BUS-01, REPLACEMENT-BUS-02',
      );
      await _tap(tester, const ValueKey('save-draft-button'));
      await tester.pump();
      await tester.pump();

      final deployments = await repository.getAll();
      final saved = deployments.singleWhere(
        (deployment) => deployment.deploymentId == 'DEP-REC-300',
      );
      expect(saved.incidentId, 'INC-B1023-300');
      expect(saved.sourceRecommendationId, 'REC-B1023-300');
      expect(saved.routeId, '300');
      expect(saved.vehicleIds, ['REPLACEMENT-BUS-01', 'REPLACEMENT-BUS-02']);
      expect(saved.vehicleIds, isNot(contains('B1023')));
      expect(saved.status.name, 'draft');
    },
  );
}

OperationsRecommendation _acceptedRecommendation() {
  final pending = OperationsRecommendation(
    id: 'REC-B1023-300',
    incidentId: 'INC-B1023-300',
    vehicleId: 'B1023',
    routeId: '300',
    actions: [
      InspectOrRepairVehicleAction(vehicleId: 'B1023'),
      DeployReplacementBusesAction(routeId: '300', busCount: 2),
    ],
    evidence: [
      RecommendationEvidence(
        ruleId: 'confirmed-breakdown',
        description: 'Bus B1023 breakdown confirmed during peak operations.',
        dataClassification: EvidenceDataClassification.internalOperationalData,
        contribution: 50,
      ),
    ],
    status: RecommendationStatus.pendingReview,
    score: 85,
    confidenceDetails: RecommendationConfidence(
      factors: [
        RecommendationConfidenceFactor(
          factorId: 'confirmed-breakdown',
          description: 'Breakdown confirmed.',
          weight: 1,
          isSupported: true,
        ),
      ],
      penalties: const [],
    ),
    createdAt: DateTime.utc(2026, 8, 30, 1),
  );
  return pending.decide(
    status: RecommendationStatus.accepted,
    decisionUserId: '11111111-1111-4111-8111-111111111111',
    decidedAt: DateTime.utc(2026, 8, 30, 2),
    remoteVersion: 2,
  );
}

String _fieldText(WidgetTester tester, String key) {
  return tester
      .widget<TextFormField>(find.byKey(ValueKey(key)))
      .controller!
      .text;
}

Future<void> _tap(WidgetTester tester, ValueKey<String> key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}
