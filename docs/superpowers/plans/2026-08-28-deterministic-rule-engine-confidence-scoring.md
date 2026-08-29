# Deterministic Rule Engine and Explainable Confidence Scoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Module 4’s owner-approved deterministic recommendation rules, explainable operational-priority scoring, independent confidence calculation, and pending-review recommendation generation.

**Architecture:** Use immutable module-local domain types, an explicitly injected RecommendationRulePolicy, a pure deterministic engine, an independent confidence scorer, and a generator that maps valid evaluations into OperationsRecommendation. Score and confidence remain separate, and no action is executed automatically.

**Tech Stack:** Flutter, Dart, flutter_test; no new dependencies.

**Spec:** `docs/superpowers/specs/2026-08-28-deterministic-rule-engine-confidence-scoring-design.md`

## Global Constraints

- Module 4 only.
- “AI recommends. Staff decides.”
- No automatic work-order, deployment, or incident mutation.
- No SQLite migration v5.
- No Supabase migration.
- No UI or persistence.
- No Modules 1, 2, or 3 changes.
- No shared, database, registry, or dependency changes.
- No government-data-contract changes.
- No GTFS adapter implementation.
- No trained ML, probability, or autonomous-control claim.
- No occupancy, realtime demand, trip updates, service alerts, or rail realtime.
- No hidden thresholds.
- Peak/off-peak is normalized caller input.
- Caller supplies identifiers and timestamps.
- All `DateTime` storage described by this plan uses `toUtc()`.
- No `DateTime.now()` in the engine or generator.
- `cachedData` is not inferred from cache/read state.
- Origin classification is preserved, not upgraded or downgraded by the engine.
- Stale penalty 0.10 is outside this milestone.
- No global minimum recommendation score.
- Every future task follows TDD.

## Locked file map

Create production files:

- `lib/features/recommendations/domain/recommendation_rule_input.dart`
- `lib/features/recommendations/domain/recommendation_rule_policy.dart`
- `lib/features/recommendations/domain/recommendation_confidence.dart`
- `lib/features/recommendations/domain/recommendation_rule_evaluation.dart`
- `lib/features/recommendations/services/explainable_confidence_scorer.dart`
- `lib/features/recommendations/services/deterministic_recommendation_rule_engine.dart`
- `lib/features/recommendations/services/recommendation_generator.dart`

Modify production file:

- `lib/features/recommendations/domain/recommendation.dart`

Create test files:

- `test/features/recommendations/domain/recommendation_rule_input_test.dart`
- `test/features/recommendations/domain/recommendation_rule_policy_test.dart`
- `test/features/recommendations/domain/recommendation_confidence_test.dart`
- `test/features/recommendations/domain/recommendation_rule_evaluation_test.dart`
- `test/features/recommendations/services/explainable_confidence_scorer_test.dart`
- `test/features/recommendations/services/deterministic_recommendation_rule_engine_test.dart`
- `test/features/recommendations/services/recommendation_generator_test.dart`

Modify test file:

- `test/features/recommendations/domain/recommendation_test.dart`

Do not add barrel files, fixtures under `lib/`, repositories, controllers,
adapters, or dependencies. Read-only search at plan creation found
`OperationsRecommendation` constructor calls only in
`test/features/recommendations/domain/recommendation_test.dart`; there are no
non-Module-4 call sites to migrate.

---

## Implementation preflight

Before Task 1, run:

```bash
git status --short --branch
git log -3 --oneline --decorate
git rev-parse HEAD
```

Also confirm both approved documents are present:

```powershell
Test-Path 'docs/superpowers/specs/2026-08-28-deterministic-rule-engine-confidence-scoring-design.md'
Test-Path 'docs/superpowers/plans/2026-08-28-deterministic-rule-engine-confidence-scoring.md'
```

Continue only when the branch is a clean `feature/ai-recommendation`, it is
synchronized with `origin/feature/ai-recommendation`, and both commands return
`True`. Record the exact hash printed by `git rev-parse HEAD` in the execution
notes as the implementation-start commit. Task 9 substitutes that recorded
hash into its final scope command. Do not write a symbolic token into a source,
test, or configuration file.

### Task 1: Recommendation rule input

**Files:**

- Create: `lib/features/recommendations/domain/recommendation_rule_input.dart`
- Test: `test/features/recommendations/domain/recommendation_rule_input_test.dart`

**Interfaces:**

- Consumes: `EvidenceDataClassification` from
  `recommendation_evidence.dart`.
- Produces: `VehicleCondition`, `OperatingPeriod`, and
  `RecommendationRuleInput` with immutable normalized IDs and UTC
  `evaluatedAt`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_input.dart';

void main() {
  test('stores normalized facts, classifications, and UTC evaluation time', () {
    final input = RecommendationRuleInput(
      incidentId: ' incident-1 ',
      vehicleId: ' B1023 ',
      routeId: ' 300 ',
      vehicleCondition: VehicleCondition.breakdownConfirmed,
      operatingPeriod: OperatingPeriod.peak,
      vehicleConditionDataClassification:
          EvidenceDataClassification.demonstrationData,
      operatingPeriodDataClassification:
          EvidenceDataClassification.staticGovernmentData,
      evaluatedAt: DateTime(2026, 8, 28, 10),
    );

    expect(input.incidentId, 'incident-1');
    expect(input.vehicleId, 'B1023');
    expect(input.routeId, '300');
    expect(input.vehicleCondition, VehicleCondition.breakdownConfirmed);
    expect(input.operatingPeriod, OperatingPeriod.peak);
    expect(input.vehicleConditionDataClassification,
        EvidenceDataClassification.demonstrationData);
    expect(input.operatingPeriodDataClassification,
        EvidenceDataClassification.staticGovernmentData);
    expect(input.evaluatedAt.isUtc, isTrue);
  });

  test('rejects blank identifiers', () {
    RecommendationRuleInput build({
      String incidentId = 'incident-1',
      String vehicleId = 'B1023',
      String routeId = '300',
    }) => RecommendationRuleInput(
      incidentId: incidentId,
      vehicleId: vehicleId,
      routeId: routeId,
      vehicleCondition: VehicleCondition.unknown,
      operatingPeriod: OperatingPeriod.unknown,
      vehicleConditionDataClassification:
          EvidenceDataClassification.internalOperationalData,
      operatingPeriodDataClassification:
          EvidenceDataClassification.internalOperationalData,
      evaluatedAt: DateTime.utc(2026, 8, 28),
    );

    expect(() => build(incidentId: ' '), throwsArgumentError);
    expect(() => build(vehicleId: ''), throwsArgumentError);
    expect(() => build(routeId: '\t'), throwsArgumentError);
  });
}
```

- [ ] **Step 2: Prove the tests fail**

Run:

```bash
flutter test test/features/recommendations/domain/recommendation_rule_input_test.dart
```

Expected: FAIL because `recommendation_rule_input.dart` and its types do not
exist.

- [ ] **Step 3: Implement the minimal input types**

```dart
import 'recommendation_evidence.dart';

enum VehicleCondition { breakdownConfirmed, operational, unknown }

enum OperatingPeriod { peak, offPeak, unknown }

class RecommendationRuleInput {
  RecommendationRuleInput({
    required String incidentId,
    required String vehicleId,
    required String routeId,
    required this.vehicleCondition,
    required this.operatingPeriod,
    required this.vehicleConditionDataClassification,
    required this.operatingPeriodDataClassification,
    required DateTime evaluatedAt,
  }) : incidentId = _requiredText(incidentId, 'incidentId'),
       vehicleId = _requiredText(vehicleId, 'vehicleId'),
       routeId = _requiredText(routeId, 'routeId'),
       evaluatedAt = evaluatedAt.toUtc();

  final String incidentId;
  final String vehicleId;
  final String routeId;
  final VehicleCondition vehicleCondition;
  final OperatingPeriod operatingPeriod;
  final EvidenceDataClassification vehicleConditionDataClassification;
  final EvidenceDataClassification operatingPeriodDataClassification;
  final DateTime evaluatedAt;
}

String _requiredText(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
  return normalized;
}
```

The type accepts normalized peak/off-peak and classifications exactly as
supplied. It has no cache/read-state field and parses no timestamp string.

- [ ] **Step 4: Format Task 1 files**

Run:

```bash
dart format lib/features/recommendations/domain/recommendation_rule_input.dart test/features/recommendations/domain/recommendation_rule_input_test.dart
```

Expected: both Task 1 files are formatted before testing and commit.

- [ ] **Step 5: Prove the focused tests pass**

Run:

```bash
flutter test test/features/recommendations/domain/recommendation_rule_input_test.dart
```

Expected: PASS; identifiers are validated, `evaluatedAt` is UTC, and supplied
classifications are unchanged.

- [ ] **Step 6: Commit Task 1 only**

```bash
git add -- lib/features/recommendations/domain/recommendation_rule_input.dart test/features/recommendations/domain/recommendation_rule_input_test.dart
git commit -m "feat(recommendations): add deterministic rule input"
```

### Task 2: Explicit rule policy

**Files:**

- Create: `lib/features/recommendations/domain/recommendation_rule_policy.dart`
- Test: `test/features/recommendations/domain/recommendation_rule_policy_test.dart`

**Interfaces:**

- Consumes: no other production type.
- Produces: `RecommendationRulePolicy(...)` for validation and
  `RecommendationRulePolicy.ownerApproved()` for the exact approved policy.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_policy.dart';

void main() {
  test('exposes the exact owner-approved policy', () {
    final policy = RecommendationRulePolicy.ownerApproved();
    expect(policy.confirmedBreakdownContribution, 50);
    expect(policy.peakBreakdownContribution, 35);
    expect(policy.replacementBusCount, 2);
    expect(policy.breakdownConfidenceWeight, 0.60);
    expect(policy.operatingPeriodConfidenceWeight, 0.40);
    expect(policy.demonstrationEvidencePenalty, 0.15);
  });

  test('rejects invalid contributions, weights, count, and penalty', () {
    RecommendationRulePolicy build({
      int breakdown = 50,
      int peak = 35,
      int buses = 2,
      double breakdownWeight = 0.60,
      double periodWeight = 0.40,
      double penalty = 0.15,
    }) => RecommendationRulePolicy(
      confirmedBreakdownContribution: breakdown,
      peakBreakdownContribution: peak,
      replacementBusCount: buses,
      breakdownConfidenceWeight: breakdownWeight,
      operatingPeriodConfidenceWeight: periodWeight,
      demonstrationEvidencePenalty: penalty,
    );

    expect(() => build(breakdown: -1), throwsArgumentError);
    expect(() => build(peak: 101), throwsArgumentError);
    expect(() => build(buses: 0), throwsArgumentError);
    expect(() => build(breakdownWeight: double.nan), throwsArgumentError);
    expect(() => build(breakdownWeight: double.infinity),
        throwsArgumentError);
    expect(() => build(periodWeight: -0.1), throwsArgumentError);
    expect(() => build(periodWeight: 1.01), throwsArgumentError);
    expect(() => build(breakdownWeight: 0, periodWeight: 0),
        throwsArgumentError);
    expect(() => build(penalty: double.infinity), throwsArgumentError);
    expect(() => build(penalty: 1.01), throwsArgumentError);
  });
}
```

- [ ] **Step 2: Prove the tests fail**

Run: `flutter test test/features/recommendations/domain/recommendation_rule_policy_test.dart`

Expected: FAIL because `RecommendationRulePolicy` does not exist.

- [ ] **Step 3: Implement the minimal explicit policy**

```dart
class RecommendationRulePolicy {
  RecommendationRulePolicy({
    required this.confirmedBreakdownContribution,
    required this.peakBreakdownContribution,
    required this.replacementBusCount,
    required this.breakdownConfidenceWeight,
    required this.operatingPeriodConfidenceWeight,
    required this.demonstrationEvidencePenalty,
  }) {
    _requireContribution(confirmedBreakdownContribution,
        'confirmedBreakdownContribution');
    _requireContribution(peakBreakdownContribution,
        'peakBreakdownContribution');
    if (replacementBusCount <= 0) {
      throw ArgumentError.value(replacementBusCount, 'replacementBusCount');
    }
    _requireWeight(breakdownConfidenceWeight, 'breakdownConfidenceWeight');
    _requireWeight(
        operatingPeriodConfidenceWeight, 'operatingPeriodConfidenceWeight');
    final total = breakdownConfidenceWeight + operatingPeriodConfidenceWeight;
    if (!total.isFinite || total <= 0) {
      throw ArgumentError.value(total, 'totalConfidenceWeight');
    }
    if (!demonstrationEvidencePenalty.isFinite ||
        demonstrationEvidencePenalty < 0 ||
        demonstrationEvidencePenalty > 1) {
      throw ArgumentError.value(
          demonstrationEvidencePenalty, 'demonstrationEvidencePenalty');
    }
  }

  factory RecommendationRulePolicy.ownerApproved() =>
      RecommendationRulePolicy(
        confirmedBreakdownContribution: 50,
        peakBreakdownContribution: 35,
        replacementBusCount: 2,
        breakdownConfidenceWeight: 0.60,
        operatingPeriodConfidenceWeight: 0.40,
        demonstrationEvidencePenalty: 0.15,
      );

  final int confirmedBreakdownContribution;
  final int peakBreakdownContribution;
  final int replacementBusCount;
  final double breakdownConfidenceWeight;
  final double operatingPeriodConfidenceWeight;
  final double demonstrationEvidencePenalty;
}

void _requireContribution(int value, String name) {
  if (value < 0 || value > 100) throw ArgumentError.value(value, name);
}

void _requireWeight(double value, String name) {
  if (!value.isFinite || value < 0 || value > 1) {
    throw ArgumentError.value(value, name);
  }
}
```

The policy has no final score, minimum score, or stale-penalty field.

- [ ] **Step 4: Format Task 2 files**

Run:

```bash
dart format lib/features/recommendations/domain/recommendation_rule_policy.dart test/features/recommendations/domain/recommendation_rule_policy_test.dart
```

Expected: both Task 2 files are formatted before testing and commit.

- [ ] **Step 5: Prove the focused tests pass**

Run: `flutter test test/features/recommendations/domain/recommendation_rule_policy_test.dart`

Expected: PASS with exact 50, 35, 2, 0.60, 0.40, and 0.15 values. Each
confidence weight accepts exactly the same finite 0.0–1.0 range as
`RecommendationConfidenceFactor`, and the total remains finite and positive.

- [ ] **Step 6: Commit Task 2 only**

```bash
git add -- lib/features/recommendations/domain/recommendation_rule_policy.dart test/features/recommendations/domain/recommendation_rule_policy_test.dart
git commit -m "feat(recommendations): add explicit rule policy"
```

### Task 3: Explainable confidence domain types

**Files:**

- Create: `lib/features/recommendations/domain/recommendation_confidence.dart`
- Test: `test/features/recommendations/domain/recommendation_confidence_test.dart`

**Interfaces:**

- Consumes: lists of `RecommendationConfidenceFactor` and
  `RecommendationConfidencePenalty`.
- Produces: immutable `RecommendationConfidence` with computed
  `baseConfidence` and `finalConfidence`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';

void main() {
  final vehicle = RecommendationConfidenceFactor(
    factorId: 'vehicle-condition', description: 'Vehicle condition known.',
    weight: 0.60, isSupported: true,
  );
  final period = RecommendationConfidenceFactor(
    factorId: 'operating-period', description: 'Operating period known.',
    weight: 0.40, isSupported: true,
  );
  final demo = RecommendationConfidencePenalty(
    penaltyId: 'demonstration-evidence',
    description: 'Demonstration evidence limits confidence.', amount: 0.15,
  );

  test('calculates and preserves the complete confidence explanation', () {
    final factors = [vehicle, period];
    final penalties = [demo];
    final result = RecommendationConfidence(
        factors: factors, penalties: penalties);
    expect(result.baseConfidence, 1.0);
    expect(result.finalConfidence, 0.85);
    expect(() => result.factors.clear(), throwsUnsupportedError);
    expect(() => result.penalties.clear(), throwsUnsupportedError);
    factors.clear(); penalties.clear();
    expect(result.factors, hasLength(2));
    expect(result.penalties, hasLength(1));
  });

  test('requires unique factor and penalty IDs', () {
    expect(() => RecommendationConfidence(
      factors: [vehicle, vehicle], penalties: const []),
      throwsArgumentError);
    expect(() => RecommendationConfidence(
      factors: [vehicle], penalties: [demo, demo]),
      throwsArgumentError);
  });

  test('validates labels, weights, amounts, and total weight', () {
    expect(() => RecommendationConfidenceFactor(
      factorId: ' ', description: 'Known.', weight: .5, isSupported: true),
      throwsArgumentError);
    expect(() => RecommendationConfidenceFactor(
      factorId: 'x', description: 'Known.', weight: double.nan,
      isSupported: true), throwsArgumentError);
    expect(() => RecommendationConfidencePenalty(
      penaltyId: 'x', description: ' ', amount: .1), throwsArgumentError);
    expect(() => RecommendationConfidencePenalty(
      penaltyId: 'x', description: 'Penalty.', amount: 1.1),
      throwsArgumentError);
    expect(() => RecommendationConfidence(
      factors: [RecommendationConfidenceFactor(
        factorId: 'x', description: 'Known.', weight: 0,
        isSupported: false)], penalties: const []), throwsArgumentError);
  });
}
```

- [ ] **Step 2: Prove the tests fail**

Run: `flutter test test/features/recommendations/domain/recommendation_confidence_test.dart`

Expected: FAIL because the confidence types do not exist.

- [ ] **Step 3: Implement the minimal confidence types**

```dart
class RecommendationConfidenceFactor {
  RecommendationConfidenceFactor({
    required String factorId, required String description,
    required this.weight, required this.isSupported,
  }) : factorId = _requiredConfidenceText(factorId, 'factorId'),
       description = _requiredConfidenceText(description, 'description') {
    _requireUnitValue(weight, 'weight');
  }

  final String factorId;
  final String description;
  final double weight;
  final bool isSupported;
}

class RecommendationConfidencePenalty {
  RecommendationConfidencePenalty({
    required String penaltyId, required String description,
    required this.amount,
  }) : penaltyId = _requiredConfidenceText(penaltyId, 'penaltyId'),
       description = _requiredConfidenceText(description, 'description') {
    _requireUnitValue(amount, 'amount');
  }

  final String penaltyId;
  final String description;
  final double amount;
}

class RecommendationConfidence {
  factory RecommendationConfidence({
    required List<RecommendationConfidenceFactor> factors,
    required List<RecommendationConfidencePenalty> penalties,
  }) {
    final factorCopy = List<RecommendationConfidenceFactor>.unmodifiable(factors);
    final penaltyCopy = List<RecommendationConfidencePenalty>.unmodifiable(penalties);
    _validateFactors(factorCopy);
    _validatePenalties(penaltyCopy);
    final total = factorCopy.fold<double>(0, (sum, item) => sum + item.weight);
    if (!total.isFinite || total <= 0) {
      throw ArgumentError.value(total, 'totalFactorWeight');
    }
    final supported = factorCopy.where((item) => item.isSupported)
        .fold<double>(0, (sum, item) => sum + item.weight);
    final base = (supported / total).clamp(0.0, 1.0).toDouble();
    final deductions = penaltyCopy.fold<double>(0, (sum, item) => sum + item.amount);
    return RecommendationConfidence._(
      factors: factorCopy, penalties: penaltyCopy, baseConfidence: base,
      finalConfidence: (base - deductions).clamp(0.0, 1.0).toDouble(),
    );
  }

  const RecommendationConfidence._({
    required this.factors, required this.penalties,
    required this.baseConfidence, required this.finalConfidence,
  });
  final List<RecommendationConfidenceFactor> factors;
  final List<RecommendationConfidencePenalty> penalties;
  final double baseConfidence;
  final double finalConfidence;
}

void _validateFactors(List<RecommendationConfidenceFactor> values) {
  final ids = <String>{};
  for (final item in values) {
    if (!ids.add(item.factorId)) {
      throw ArgumentError.value(item, 'factors');
    }
  }
}

void _validatePenalties(List<RecommendationConfidencePenalty> values) {
  final ids = <String>{};
  for (final item in values) {
    if (!ids.add(item.penaltyId)) {
      throw ArgumentError.value(item, 'penalties');
    }
  }
}

String _requiredConfidenceText(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) throw ArgumentError.value(value, name);
  return normalized;
}

void _requireUnitValue(double value, String name) {
  if (!value.isFinite || value < 0 || value > 1) {
    throw ArgumentError.value(value, name);
  }
}
```

- [ ] **Step 4: Format Task 3 files**

Run:

```bash
dart format lib/features/recommendations/domain/recommendation_confidence.dart test/features/recommendations/domain/recommendation_confidence_test.dart
```

Expected: both Task 3 files are formatted before testing and commit.

- [ ] **Step 5: Prove the focused tests pass**

Run: `flutter test test/features/recommendations/domain/recommendation_confidence_test.dart`

Expected: PASS; calculation is 1.00 minus 0.15 equals 0.85, IDs are unique,
and both lists are defensive and unmodifiable.

- [ ] **Step 6: Commit Task 3 only**

```bash
git add -- lib/features/recommendations/domain/recommendation_confidence.dart test/features/recommendations/domain/recommendation_confidence_test.dart
git commit -m "feat(recommendations): add explainable confidence model"
```

### Task 4: Independent confidence scorer

**Files:**

- Create: `lib/features/recommendations/services/explainable_confidence_scorer.dart`
- Test: `test/features/recommendations/services/explainable_confidence_scorer_test.dart`

**Interfaces:**

- Consumes: `RecommendationRuleInput` and `RecommendationRulePolicy`.
- Produces:

```dart
class ExplainableConfidenceScorer {
  const ExplainableConfidenceScorer();

  RecommendationConfidence score({
    required RecommendationRuleInput input,
    required RecommendationRulePolicy policy,
  });
}
```

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_input.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_policy.dart';
import 'package:prasa_assist/features/recommendations/services/explainable_confidence_scorer.dart';

void main() {
  RecommendationRuleInput input({
    VehicleCondition condition = VehicleCondition.breakdownConfirmed,
    OperatingPeriod period = OperatingPeriod.peak,
    EvidenceDataClassification vehicleClass =
        EvidenceDataClassification.demonstrationData,
    EvidenceDataClassification periodClass =
        EvidenceDataClassification.demonstrationData,
  }) => RecommendationRuleInput(
    incidentId: 'incident-1', vehicleId: 'B1023', routeId: '300',
    vehicleCondition: condition, operatingPeriod: period,
    vehicleConditionDataClassification: vehicleClass,
    operatingPeriodDataClassification: periodClass,
    evaluatedAt: DateTime.utc(2026, 8, 28),
  );

  test('calculates both factors and one demonstration penalty', () {
    final result = const ExplainableConfidenceScorer().score(
      input: input(), policy: RecommendationRulePolicy.ownerApproved());
    expect(result.baseConfidence, 1.0);
    expect(result.finalConfidence, 0.85);
    expect(result.factors.map((item) => item.factorId),
        ['vehicle-condition', 'operating-period']);
    expect(result.penalties.single.penaltyId, 'demonstration-evidence');
    expect(result.penalties.single.amount, 0.15);
  });

  test('unknown period leaves only vehicle weight supported', () {
    final result = const ExplainableConfidenceScorer().score(
      input: input(period: OperatingPeriod.unknown,
        vehicleClass: EvidenceDataClassification.staticGovernmentData,
        periodClass: EvidenceDataClassification.cachedData),
      policy: RecommendationRulePolicy.ownerApproved());
    expect(result.baseConfidence, 0.60);
    expect(result.penalties, isEmpty);
    expect(input(vehicleClass: EvidenceDataClassification.staticGovernmentData)
        .vehicleConditionDataClassification,
        EvidenceDataClassification.staticGovernmentData);
  });
}
```

- [ ] **Step 2: Prove the tests fail**

Run: `flutter test test/features/recommendations/services/explainable_confidence_scorer_test.dart`

Expected: FAIL because `ExplainableConfidenceScorer` does not exist.

- [ ] **Step 3: Implement the minimal scorer**

```dart
import '../domain/recommendation_confidence.dart';
import '../domain/recommendation_evidence.dart';
import '../domain/recommendation_rule_input.dart';
import '../domain/recommendation_rule_policy.dart';

class ExplainableConfidenceScorer {
  const ExplainableConfidenceScorer();

  RecommendationConfidence score({
    required RecommendationRuleInput input,
    required RecommendationRulePolicy policy,
  }) {
    final hasDemonstrationEvidence =
        input.vehicleConditionDataClassification ==
            EvidenceDataClassification.demonstrationData ||
        input.operatingPeriodDataClassification ==
            EvidenceDataClassification.demonstrationData;
    return RecommendationConfidence(
      factors: [
        RecommendationConfidenceFactor(
          factorId: 'vehicle-condition',
          description: 'Vehicle condition is supplied as a normalized fact.',
          weight: policy.breakdownConfidenceWeight,
          isSupported: input.vehicleCondition != VehicleCondition.unknown,
        ),
        RecommendationConfidenceFactor(
          factorId: 'operating-period',
          description: 'Operating period is supplied as a normalized fact.',
          weight: policy.operatingPeriodConfidenceWeight,
          isSupported: input.operatingPeriod != OperatingPeriod.unknown,
        ),
      ],
      penalties: hasDemonstrationEvidence
          ? [RecommendationConfidencePenalty(
              penaltyId: 'demonstration-evidence',
              description: 'Demonstration evidence limits confidence.',
              amount: policy.demonstrationEvidencePenalty,
            )]
          : const [],
    );
  }
}
```

The scorer reads classifications only to detect explicit
`demonstrationData`. It does not infer `cachedData`, modify
`staticGovernmentData`, or claim that provenance was independently verified.

- [ ] **Step 4: Format Task 4 files**

Run:

```bash
dart format lib/features/recommendations/services/explainable_confidence_scorer.dart test/features/recommendations/services/explainable_confidence_scorer_test.dart
```

Expected: both Task 4 files are formatted before testing and commit.

- [ ] **Step 5: Prove the focused tests pass**

Run: `flutter test test/features/recommendations/services/explainable_confidence_scorer_test.dart`

Expected: PASS; both demonstration classifications still create exactly one
penalty and score is not an input.

- [ ] **Step 6: Commit Task 4 only**

```bash
git add -- lib/features/recommendations/services/explainable_confidence_scorer.dart test/features/recommendations/services/explainable_confidence_scorer_test.dart
git commit -m "feat(recommendations): add explainable confidence scorer"
```

### Task 5: Immutable evaluation result

**Files:**

- Create: `lib/features/recommendations/domain/recommendation_rule_evaluation.dart`
- Test: `test/features/recommendations/domain/recommendation_rule_evaluation_test.dart`

**Interfaces:**

- Consumes: `RecommendationRuleInput`, `RecommendationAction`,
  `RecommendationEvidence`, and `RecommendationConfidence`.
- Produces: immutable `RecommendationRuleEvaluation` with
  `hasRecommendation`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_evaluation.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_input.dart';

void main() {
  final input = RecommendationRuleInput(
    incidentId: 'incident-1', vehicleId: 'B1023', routeId: '300',
    vehicleCondition: VehicleCondition.breakdownConfirmed,
    operatingPeriod: OperatingPeriod.offPeak,
    vehicleConditionDataClassification:
        EvidenceDataClassification.internalOperationalData,
    operatingPeriodDataClassification:
        EvidenceDataClassification.internalOperationalData,
    evaluatedAt: DateTime.utc(2026, 8, 28));
  final confidence = RecommendationConfidence(factors: [
    RecommendationConfidenceFactor(factorId: 'vehicle-condition',
      description: 'Known.', weight: 1, isSupported: true),
  ], penalties: const []);

  test('defensively stores a valid recommendation evaluation', () {
    final actions = <RecommendationAction>[
      InspectOrRepairVehicleAction(vehicleId: 'B1023')];
    final evidence = [RecommendationEvidence(ruleId: 'breakdown',
      description: 'Confirmed breakdown.',
      dataClassification: EvidenceDataClassification.internalOperationalData,
      contribution: 50)];
    final result = RecommendationRuleEvaluation(input: input, actions: actions,
      evidence: evidence, score: 50, confidenceDetails: confidence);
    actions.clear(); evidence.clear();
    expect(result.hasRecommendation, isTrue);
    expect(result.actions, hasLength(1));
    expect(result.evidence, hasLength(1));
    expect(() => result.actions.clear(), throwsUnsupportedError);
  });

  test('allows explicit no recommendation and rejects mixed states', () {
    final none = RecommendationRuleEvaluation(input: input, actions: const [],
      evidence: const [], score: 0, confidenceDetails: confidence);
    expect(none.hasRecommendation, isFalse);
    expect(() => RecommendationRuleEvaluation(input: input, actions: const [],
      evidence: const [], score: 1, confidenceDetails: confidence),
      throwsArgumentError);
    expect(() => RecommendationRuleEvaluation(input: input,
      actions: [InspectOrRepairVehicleAction(vehicleId: 'B1023')],
      evidence: const [], score: 50, confidenceDetails: confidence),
      throwsArgumentError);
    expect(() => RecommendationRuleEvaluation(input: input,
      actions: [InspectOrRepairVehicleAction(vehicleId: 'B1023')],
      evidence: [RecommendationEvidence(ruleId: 'breakdown',
        description: 'Confirmed breakdown.',
        dataClassification:
            EvidenceDataClassification.internalOperationalData,
        contribution: 50)],
      score: 49, confidenceDetails: confidence), throwsArgumentError);
    expect(() => RecommendationRuleEvaluation(input: input, actions: const [],
      evidence: const [], score: 101, confidenceDetails: confidence),
      throwsArgumentError);
  });
}
```

- [ ] **Step 2: Prove the tests fail**

Run: `flutter test test/features/recommendations/domain/recommendation_rule_evaluation_test.dart`

Expected: FAIL because `RecommendationRuleEvaluation` does not exist.

- [ ] **Step 3: Implement the minimal evaluation type**

```dart
import 'recommendation_action.dart';
import 'recommendation_confidence.dart';
import 'recommendation_evidence.dart';
import 'recommendation_rule_input.dart';

class RecommendationRuleEvaluation {
  RecommendationRuleEvaluation({required this.input,
    required List<RecommendationAction> actions,
    required List<RecommendationEvidence> evidence,
    required this.score, required this.confidenceDetails})
      : actions = List.unmodifiable(actions),
        evidence = List.unmodifiable(evidence) {
    if (score < 0 || score > 100) throw ArgumentError.value(score, 'score');
    if (actions.isEmpty != evidence.isEmpty) {
      throw ArgumentError('Actions and evidence must both be empty or nonempty.');
    }
    final expectedScore = evidence
        .fold<int>(0, (sum, item) => sum + item.contribution)
        .clamp(0, 100)
        .toInt();
    if (score != expectedScore) {
      throw ArgumentError.value(score, 'score',
          'must equal the clamped evidence contribution sum $expectedScore');
    }
  }
  final RecommendationRuleInput input;
  final List<RecommendationAction> actions;
  final List<RecommendationEvidence> evidence;
  final int score;
  final RecommendationConfidence confidenceDetails;
  bool get hasRecommendation => actions.isNotEmpty;
}
```

- [ ] **Step 4: Format Task 5 files**

Run:

```bash
dart format lib/features/recommendations/domain/recommendation_rule_evaluation.dart test/features/recommendations/domain/recommendation_rule_evaluation_test.dart
```

Expected: both Task 5 files are formatted before testing and commit.

- [ ] **Step 5: Prove the focused tests pass**

Run: `flutter test test/features/recommendations/domain/recommendation_rule_evaluation_test.dart`

Expected: PASS for valid, no-recommendation, immutable, mixed-state, and score
boundary behavior. Empty actions/evidence accept only score 0, while evidence
contribution 50 rejects supplied score 49. There is one score field and no
global threshold.

- [ ] **Step 6: Commit Task 5 only**

```bash
git add -- lib/features/recommendations/domain/recommendation_rule_evaluation.dart test/features/recommendations/domain/recommendation_rule_evaluation_test.dart
git commit -m "feat(recommendations): add immutable rule evaluation"
```

### Task 6: Deterministic rule engine

**Files:**

- Create: `lib/features/recommendations/services/deterministic_recommendation_rule_engine.dart`
- Test: `test/features/recommendations/services/deterministic_recommendation_rule_engine_test.dart`

**Interfaces:**

- Consumes: `RecommendationRulePolicy`, `ExplainableConfidenceScorer`, and
  `RecommendationRuleInput`.
- Produces:

```dart
class DeterministicRecommendationRuleEngine {
  const DeterministicRecommendationRuleEngine({
    required RecommendationRulePolicy policy,
    required ExplainableConfidenceScorer confidenceScorer,
  });

  RecommendationRuleEvaluation evaluate(RecommendationRuleInput input);
}
```

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_input.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_policy.dart';
import 'package:prasa_assist/features/recommendations/services/deterministic_recommendation_rule_engine.dart';
import 'package:prasa_assist/features/recommendations/services/explainable_confidence_scorer.dart';

void main() {
  final engine = DeterministicRecommendationRuleEngine(
    policy: RecommendationRulePolicy.ownerApproved(),
    confidenceScorer: const ExplainableConfidenceScorer());
  RecommendationRuleInput input(VehicleCondition condition,
      OperatingPeriod period) => RecommendationRuleInput(
    incidentId: 'incident-b1023', vehicleId: 'B1023', routeId: '300',
    vehicleCondition: condition, operatingPeriod: period,
    vehicleConditionDataClassification:
        EvidenceDataClassification.demonstrationData,
    operatingPeriodDataClassification:
        EvidenceDataClassification.demonstrationData,
    evaluatedAt: DateTime.utc(2026, 8, 28, 8));

  test('produces the exact B1023 peak recommendation in stable order', () {
    final result = engine.evaluate(input(
      VehicleCondition.breakdownConfirmed, OperatingPeriod.peak));
    expect(result.actions, hasLength(2));
    expect(result.actions[0], isA<InspectOrRepairVehicleAction>());
    expect((result.actions[0] as InspectOrRepairVehicleAction).vehicleId,
        'B1023');
    expect(result.actions[1], isA<DeployReplacementBusesAction>());
    final deploy = result.actions[1] as DeployReplacementBusesAction;
    expect(deploy.routeId, '300'); expect(deploy.busCount, 2);
    expect(result.evidence.map((item) => item.ruleId), [
      'confirmed-vehicle-breakdown', 'peak-breakdown-route-continuity']);
    expect(result.evidence.map((item) => item.contribution), [50, 35]);
    expect(result.score, 85);
    expect(result.confidenceDetails.baseConfidence, 1.0);
    expect(result.confidenceDetails.penalties, hasLength(1));
    expect(result.confidenceDetails.penalties.single.amount, 0.15);
    expect(result.confidenceDetails.finalConfidence, 0.85);
    expect(result.actions.whereType<InspectOrRepairVehicleAction>(),
        hasLength(1));
    expect(result.actions.whereType<DeployReplacementBusesAction>(),
        hasLength(1));
    final text = result.evidence.map((item) => item.description)
        .join(' ').toLowerCase();
    for (final unsupported in ['occupancy', 'realtime passenger demand',
      'trip updates', 'service alerts', 'rail realtime']) {
      expect(text, isNot(contains(unsupported)));
    }
  });

  test('off-peak and unknown period inspect only; other conditions do not match', () {
    for (final period in [OperatingPeriod.offPeak, OperatingPeriod.unknown]) {
      final result = engine.evaluate(
        input(VehicleCondition.breakdownConfirmed, period));
      expect(result.actions.single, isA<InspectOrRepairVehicleAction>());
      expect(result.score, 50);
    }
    expect(engine.evaluate(input(VehicleCondition.operational,
      OperatingPeriod.peak)).hasRecommendation, isFalse);
    expect(engine.evaluate(input(VehicleCondition.unknown,
      OperatingPeriod.peak)).hasRecommendation, isFalse);
  });

  test('clamps the deterministic contribution sum to 100', () {
    final highPolicyEngine = DeterministicRecommendationRuleEngine(
      policy: RecommendationRulePolicy(
        confirmedBreakdownContribution: 100, peakBreakdownContribution: 100,
        replacementBusCount: 2, breakdownConfidenceWeight: .6,
        operatingPeriodConfidenceWeight: .4,
        demonstrationEvidencePenalty: .15),
      confidenceScorer: const ExplainableConfidenceScorer());
    expect(highPolicyEngine.evaluate(input(VehicleCondition.breakdownConfirmed,
      OperatingPeriod.peak)).score, 100);
  });
}
```

- [ ] **Step 2: Prove the tests fail**

Run: `flutter test test/features/recommendations/services/deterministic_recommendation_rule_engine_test.dart`

Expected: FAIL because the deterministic engine does not exist.

- [ ] **Step 3: Implement the minimal engine**

```dart
import '../domain/recommendation_action.dart';
import '../domain/recommendation_evidence.dart';
import '../domain/recommendation_rule_evaluation.dart';
import '../domain/recommendation_rule_input.dart';
import '../domain/recommendation_rule_policy.dart';
import 'explainable_confidence_scorer.dart';

class DeterministicRecommendationRuleEngine {
  const DeterministicRecommendationRuleEngine({required this.policy,
    required this.confidenceScorer});
  final RecommendationRulePolicy policy;
  final ExplainableConfidenceScorer confidenceScorer;

  RecommendationRuleEvaluation evaluate(RecommendationRuleInput input) {
    final actions = <RecommendationAction>[];
    final evidence = <RecommendationEvidence>[];
    final actionKeys = <String>{};
    void addAction(String key, RecommendationAction action) {
      if (actionKeys.add(key)) actions.add(action);
    }
    if (input.vehicleCondition == VehicleCondition.breakdownConfirmed) {
      addAction('inspect:${input.vehicleId}',
          InspectOrRepairVehicleAction(vehicleId: input.vehicleId));
      evidence.add(RecommendationEvidence(
        ruleId: 'confirmed-vehicle-breakdown',
        description: 'Bus ${input.vehicleId} has a confirmed breakdown and '
            'requires staff inspection or repair.',
        dataClassification: input.vehicleConditionDataClassification,
        contribution: policy.confirmedBreakdownContribution));
      if (input.operatingPeriod == OperatingPeriod.peak) {
        addAction('deploy:${input.routeId}:${policy.replacementBusCount}',
            DeployReplacementBusesAction(routeId: input.routeId,
              busCount: policy.replacementBusCount));
        evidence.add(RecommendationEvidence(
          ruleId: 'peak-breakdown-route-continuity',
          description: 'Route ${input.routeId} requires staff review for '
              '${policy.replacementBusCount} replacement buses during the '
              'supplied peak operating period.',
          dataClassification: input.operatingPeriodDataClassification,
          contribution: policy.peakBreakdownContribution));
      }
    }
    final score = evidence.fold<int>(0, (sum, item) => sum + item.contribution)
        .clamp(0, 100).toInt();
    return RecommendationRuleEvaluation(input: input, actions: actions,
      evidence: evidence, score: score,
      confidenceDetails: confidenceScorer.score(input: input, policy: policy));
  }
}
```

The action keys include type and complete payload. First occurrence wins;
current-rule regression tests require exactly one action of each matched type
and stable evidence order.

- [ ] **Step 4: Format Task 6 files**

Run:

```bash
dart format lib/features/recommendations/services/deterministic_recommendation_rule_engine.dart test/features/recommendations/services/deterministic_recommendation_rule_engine_test.dart
```

Expected: both Task 6 files are formatted before testing and commit.

- [ ] **Step 5: Prove the focused tests pass**

Run: `flutter test test/features/recommendations/services/deterministic_recommendation_rule_engine_test.dart`

Expected: PASS with exact action order, rule IDs, 85 score, one 0.15 penalty,
0.85 confidence, inspect-only branches, no-match branches, and 100 clamp.

- [ ] **Step 6: Commit Task 6 only**

```bash
git add -- lib/features/recommendations/services/deterministic_recommendation_rule_engine.dart test/features/recommendations/services/deterministic_recommendation_rule_engine_test.dart
git commit -m "feat(recommendations): add deterministic rule engine"
```

### Task 7: OperationsRecommendation confidence migration

**Files:**

- Modify: `lib/features/recommendations/domain/recommendation.dart`
- Modify: `test/features/recommendations/domain/recommendation_test.dart`

**Interfaces:**

- Consumes: `RecommendationConfidence` from Task 3.
- Produces option A exactly:

```dart
final RecommendationConfidence confidenceDetails;

double get confidence => confidenceDetails.finalConfidence;
```

- [ ] **Step 1: Rewrite the existing tests to fail against the old API**

Add the confidence import and replace raw-double construction with:

```dart
RecommendationConfidence buildConfidence({double penalty = 0.15}) =>
    RecommendationConfidence(
      factors: [RecommendationConfidenceFactor(
        factorId: 'vehicle-condition', description: 'Known.',
        weight: 1, isSupported: true)],
      penalties: penalty == 0
          ? const []
          : [RecommendationConfidencePenalty(
              penaltyId: 'demonstration-evidence',
              description: 'Demonstration evidence.', amount: penalty)],
    );

test('confidence getter has confidenceDetails as its only stored source', () {
  final details = buildConfidence();
  final recommendation = buildRecommendation(confidenceDetails: details);
  expect(identical(recommendation.confidenceDetails, details), isTrue);
  expect(recommendation.confidence,
      recommendation.confidenceDetails.finalConfidence);
  expect(recommendation.confidence, 0.85);
});

test('normalizes createdAt to UTC', () {
  final recommendation = OperationsRecommendation(
    id: 'recommendation-1', incidentId: 'incident-1', vehicleId: 'B1023',
    routeId: '300',
    actions: [InspectOrRepairVehicleAction(vehicleId: 'B1023')],
    evidence: [RecommendationEvidence(ruleId: 'breakdown',
      description: 'Confirmed breakdown.',
      dataClassification: EvidenceDataClassification.demonstrationData,
      contribution: 50)],
    status: RecommendationStatus.pendingReview, score: 50,
    confidenceDetails: buildConfidence(),
    createdAt: DateTime(2026, 8, 28, 10));
  expect(recommendation.createdAt.isUtc, isTrue);
});
```

Update the helper signature to accept
`RecommendationConfidence? confidenceDetails` and pass
`confidenceDetails ?? buildConfidence()`; remove the obsolete raw-confidence
boundary tests because Task 3 owns confidence validation.

- [ ] **Step 2: Prove the migrated tests fail**

Run: `flutter test test/features/recommendations/domain/recommendation_test.dart`

Expected: FAIL because the existing constructor has `confidence:` and no
`confidenceDetails` field.

- [ ] **Step 3: Implement the single-source confidence API**

```dart
import 'recommendation_action.dart';
import 'recommendation_confidence.dart';
import 'recommendation_evidence.dart';
import 'recommendation_status.dart';

class OperationsRecommendation {
  OperationsRecommendation({required this.id, required this.incidentId,
    required this.vehicleId, required this.routeId,
    required List<RecommendationAction> actions,
    required List<RecommendationEvidence> evidence, required this.status,
    required this.score, required this.confidenceDetails,
    required DateTime createdAt})
      : actions = List.unmodifiable(actions),
        evidence = List.unmodifiable(evidence),
        createdAt = createdAt.toUtc() {
    if (actions.isEmpty) throw ArgumentError.value(actions, 'actions');
    if (evidence.isEmpty) throw ArgumentError.value(evidence, 'evidence');
    if (score < 0 || score > 100) throw ArgumentError.value(score, 'score');
  }
  final String id;
  final String incidentId;
  final String vehicleId;
  final String routeId;
  final List<RecommendationAction> actions;
  final List<RecommendationEvidence> evidence;
  final RecommendationStatus status;
  final int score;
  final RecommendationConfidence confidenceDetails;
  double get confidence => confidenceDetails.finalConfidence;
  final DateTime createdAt;
}
```

Run the read-only API check:

```bash
rg -n "required this\.confidence\b|final double confidence\b|confidence:" lib/features/recommendations test/features/recommendations
```

Expected: no independent production field/constructor match; any remaining
`.confidence` use is getter read access. The plan-creation search found no
non-Module-4 call site; if a new one appears, stop for coordinator review
instead of editing it.

- [ ] **Step 4: Format Task 7 files**

Run:

```bash
dart format lib/features/recommendations/domain/recommendation.dart test/features/recommendations/domain/recommendation_test.dart
```

Expected: both Task 7 files are formatted before testing and commit.

- [ ] **Step 5: Prove the focused tests pass**

Run: `flutter test test/features/recommendations/domain/recommendation_test.dart`

Expected: PASS; `confidenceDetails` is stored once, getter equality holds, and
`createdAt` is UTC.

- [ ] **Step 6: Commit Task 7 only**

```bash
git add -- lib/features/recommendations/domain/recommendation.dart test/features/recommendations/domain/recommendation_test.dart
git commit -m "refactor(recommendations): store explainable confidence"
```

### Task 8: Recommendation generator

**Files:**

- Create: `lib/features/recommendations/services/recommendation_generator.dart`
- Test: `test/features/recommendations/services/recommendation_generator_test.dart`

**Interfaces:**

- Consumes: `RecommendationRuleEvaluation` and the existing recommendation
  domain types.
- Produces:

```dart
class RecommendationGenerator {
  const RecommendationGenerator();

  OperationsRecommendation? generate({
    required String recommendationId,
    required DateTime createdAt,
    required RecommendationRuleEvaluation evaluation,
  });
}
```

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_action.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_confidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_evidence.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_evaluation.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_input.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_rule_policy.dart';
import 'package:prasa_assist/features/recommendations/domain/recommendation_status.dart';
import 'package:prasa_assist/features/recommendations/services/deterministic_recommendation_rule_engine.dart';
import 'package:prasa_assist/features/recommendations/services/explainable_confidence_scorer.dart';
import 'package:prasa_assist/features/recommendations/services/recommendation_generator.dart';

void main() {
  final input = RecommendationRuleInput(incidentId: 'incident-1',
    vehicleId: 'B1023', routeId: '300',
    vehicleCondition: VehicleCondition.breakdownConfirmed,
    operatingPeriod: OperatingPeriod.offPeak,
    vehicleConditionDataClassification:
        EvidenceDataClassification.internalOperationalData,
    operatingPeriodDataClassification:
        EvidenceDataClassification.internalOperationalData,
    evaluatedAt: DateTime.utc(2026, 8, 28));
  final confidence = RecommendationConfidence(factors: [
    RecommendationConfidenceFactor(factorId: 'vehicle-condition',
      description: 'Known.', weight: 1, isSupported: true)],
    penalties: const []);
  final engine = DeterministicRecommendationRuleEngine(
    policy: RecommendationRulePolicy.ownerApproved(),
    confidenceScorer: const ExplainableConfidenceScorer());
  RecommendationRuleInput ruleInput({
    required VehicleCondition condition,
    required OperatingPeriod period,
    EvidenceDataClassification vehicleClass =
        EvidenceDataClassification.demonstrationData,
    EvidenceDataClassification periodClass =
        EvidenceDataClassification.demonstrationData,
  }) => RecommendationRuleInput(
    incidentId: 'incident-b1023', vehicleId: 'B1023', routeId: '300',
    vehicleCondition: condition, operatingPeriod: period,
    vehicleConditionDataClassification: vehicleClass,
    operatingPeriodDataClassification: periodClass,
    evaluatedAt: DateTime(2026, 8, 28, 8));

  test('maps a valid evaluation to pending review without side effects', () {
    final action = InspectOrRepairVehicleAction(vehicleId: 'B1023');
    final evidence = RecommendationEvidence(ruleId: 'breakdown',
      description: 'Confirmed breakdown.',
      dataClassification: EvidenceDataClassification.internalOperationalData,
      contribution: 50);
    final evaluation = RecommendationRuleEvaluation(input: input,
      actions: [action], evidence: [evidence], score: 50,
      confidenceDetails: confidence);
    final result = const RecommendationGenerator().generate(
      recommendationId: ' recommendation-1 ',
      createdAt: DateTime(2026, 8, 28, 10), evaluation: evaluation)!;
    expect(result.id, 'recommendation-1');
    expect(result.incidentId, input.incidentId);
    expect(result.vehicleId, input.vehicleId);
    expect(result.routeId, input.routeId);
    expect(identical(result.actions.single, action), isTrue);
    expect(identical(result.evidence.single, evidence), isTrue);
    expect(identical(result.confidenceDetails, confidence), isTrue);
    expect(result.score, 50);
    expect(result.status, RecommendationStatus.pendingReview);
    expect(result.createdAt.isUtc, isTrue);
  });

  test('returns null for no recommendation and rejects blank ID', () {
    final none = RecommendationRuleEvaluation(input: input, actions: const [],
      evidence: const [], score: 0, confidenceDetails: confidence);
    expect(const RecommendationGenerator().generate(
      recommendationId: 'recommendation-1',
      createdAt: DateTime.utc(2026, 8, 28), evaluation: none), isNull);
    expect(() => const RecommendationGenerator().generate(
      recommendationId: ' ', createdAt: DateTime.utc(2026, 8, 28),
      evaluation: none), throwsArgumentError);
  });

  test('generates the complete B1023 peak recommendation', () {
    final evaluation = engine.evaluate(ruleInput(
      condition: VehicleCondition.breakdownConfirmed,
      period: OperatingPeriod.peak));
    final result = const RecommendationGenerator().generate(
      recommendationId: 'recommendation-b1023-route-300',
      createdAt: DateTime(2026, 8, 28, 8), evaluation: evaluation)!;
    expect(result.actions[0], isA<InspectOrRepairVehicleAction>());
    expect((result.actions[0] as InspectOrRepairVehicleAction).vehicleId,
        'B1023');
    final deploy = result.actions[1] as DeployReplacementBusesAction;
    expect(deploy.routeId, '300');
    expect(deploy.busCount, 2);
    expect(result.score, 85);
    expect(result.confidenceDetails.baseConfidence, 1.0);
    expect(result.confidenceDetails.penalties, hasLength(1));
    expect(result.confidenceDetails.penalties.single.amount, 0.15);
    expect(result.confidence, 0.85);
    expect(result.status, RecommendationStatus.pendingReview);
    expect(result.evidence.map((item) => item.dataClassification),
        everyElement(EvidenceDataClassification.demonstrationData));
  });

  test('generates inspect only for a confirmed off-peak breakdown', () {
    final evaluation = engine.evaluate(ruleInput(
      condition: VehicleCondition.breakdownConfirmed,
      period: OperatingPeriod.offPeak));
    final result = const RecommendationGenerator().generate(
      recommendationId: 'recommendation-off-peak',
      createdAt: DateTime.utc(2026, 8, 28), evaluation: evaluation)!;
    expect(result.actions, hasLength(1));
    expect(result.actions.single, isA<InspectOrRepairVehicleAction>());
    expect(result.actions.whereType<DeployReplacementBusesAction>(), isEmpty);
    expect(result.score, 50);
  });

  test('returns null for operational and unknown vehicle conditions', () {
    for (final condition in [
      VehicleCondition.operational,
      VehicleCondition.unknown,
    ]) {
      final evaluation = engine.evaluate(ruleInput(
        condition: condition, period: OperatingPeriod.peak));
      expect(evaluation.hasRecommendation, isFalse);
      expect(const RecommendationGenerator().generate(
        recommendationId: 'recommendation-none',
        createdAt: DateTime.utc(2026, 8, 28), evaluation: evaluation), isNull);
    }
  });

  test('preserves supplied classifications without unsupported claims', () {
    final evaluation = engine.evaluate(ruleInput(
      condition: VehicleCondition.breakdownConfirmed,
      period: OperatingPeriod.peak,
      vehicleClass: EvidenceDataClassification.staticGovernmentData,
      periodClass: EvidenceDataClassification.demonstrationData));
    expect(evaluation.evidence.map((item) => item.dataClassification), [
      EvidenceDataClassification.staticGovernmentData,
      EvidenceDataClassification.demonstrationData,
    ]);
    final text = evaluation.evidence
        .map((item) => item.description).join(' ').toLowerCase();
    for (final unsupported in [
      'occupancy', 'realtime passenger demand', 'trip updates',
      'service alerts', 'rail realtime',
    ]) {
      expect(text, isNot(contains(unsupported)));
    }
  });
}
```

- [ ] **Step 2: Prove the tests fail**

Run: `flutter test test/features/recommendations/services/recommendation_generator_test.dart`

Expected: FAIL because `RecommendationGenerator` does not exist. The tests are
already complete before generator production code is created; they do not
claim to verify government provenance and only assert preservation of the
caller-supplied classification.

- [ ] **Step 3: Implement the minimal generator**

```dart
import '../domain/recommendation.dart';
import '../domain/recommendation_rule_evaluation.dart';
import '../domain/recommendation_status.dart';

class RecommendationGenerator {
  const RecommendationGenerator();

  OperationsRecommendation? generate({required String recommendationId,
    required DateTime createdAt,
    required RecommendationRuleEvaluation evaluation}) {
    final id = recommendationId.trim();
    if (id.isEmpty) throw ArgumentError.value(recommendationId, 'recommendationId');
    if (!evaluation.hasRecommendation) return null;
    return OperationsRecommendation(id: id,
      incidentId: evaluation.input.incidentId,
      vehicleId: evaluation.input.vehicleId,
      routeId: evaluation.input.routeId,
      actions: evaluation.actions, evidence: evaluation.evidence,
      status: RecommendationStatus.pendingReview, score: evaluation.score,
      confidenceDetails: evaluation.confidenceDetails,
      createdAt: createdAt.toUtc());
  }
}
```

The generator has no clock, accept/reject operation, work-order call,
deployment call, or incident mutation.

- [ ] **Step 4: Format Task 8 files**

Run:

```bash
dart format lib/features/recommendations/services/recommendation_generator.dart test/features/recommendations/services/recommendation_generator_test.dart
```

Expected: both Task 8 files are formatted before testing and commit.

- [ ] **Step 5: Prove the focused tests pass**

Run: `flutter test test/features/recommendations/services/recommendation_generator_test.dart`

Expected: PASS for explicit ID/time mapping, complete B1023 peak generation,
off-peak inspect-only behavior, operational/unknown `null`, UTC storage,
pending review, single confidence source, classification preservation, and no
unsupported realtime claim.

- [ ] **Step 6: Commit Task 8 only**

```bash
git add -- lib/features/recommendations/services/recommendation_generator.dart test/features/recommendations/services/recommendation_generator_test.dart
git commit -m "feat(recommendations): generate pending recommendations"
```

### Task 9: Final formatting, regression, and scope verification

**Files:**

- Modify: none.
- Verify only: all production and test files in the locked file map.

**Interfaces:**

- Consumes: the exact Task 1–8 constructors, methods, and integration tests.
- Produces: verification evidence only; no source, test, API, or commit.

- [ ] **Step 1: Run the existing focused integration tests**

```bash
flutter test test/features/recommendations/services/recommendation_generator_test.dart
flutter test test/features/recommendations/services/deterministic_recommendation_rule_engine_test.dart
```

Expected: PASS for B1023 peak generation, off-peak inspect-only behavior,
operational/unknown no-match behavior, score/confidence independence,
caller-supplied classification preservation, and absence of unsupported
realtime claims. These tests were created red-first in Tasks 6 and 8.

- [ ] **Step 2: Run all focused Module 4 tests**

```bash
flutter test test/features/recommendations
```

Expected: PASS with no predicted test count.

- [ ] **Step 3: Verify formatting without changing files**

```bash
dart format --output=none --set-exit-if-changed lib/features/recommendations test/features/recommendations
```

Expected: exit 0. Tasks 1–8 already formatted their owned files before each
commit; this is the final check, not a substitute for those formatting steps.

- [ ] **Step 4: Run full regression and repository checks**

```bash
flutter analyze
flutter test
git diff --check
git status --short --branch
```

Expected: every command exits 0; do not predict the full-test count. If Flutter
modifies generated plugin files, stop and report their exact paths without
restoring, staging, or committing them.

- [ ] **Step 5: Verify final implementation scope with the recorded hash**

Use this command shape:

```bash
git diff --name-only <recorded-implementation-start-hash>..HEAD
```

The executor must replace `<recorded-implementation-start-hash>` at execution
time with the exact hash printed and recorded by the implementation preflight;
the literal angle-bracket text must never be written to a committed source,
test, configuration, or script. Expected paths are only under:

- `lib/features/recommendations/`
- `test/features/recommendations/`

Any other path requires coordinator review before continuing. Task 9 stages
nothing, modifies nothing, and creates no commit.

## Implementation completion gate

After Task 9, stop before push or PR creation. Report each focused command,
complete verification result, implementation-start hash, final file list, and
all commits. Do not claim persistence, UI, trained ML, government-data
verification, or autonomous operational behavior.
