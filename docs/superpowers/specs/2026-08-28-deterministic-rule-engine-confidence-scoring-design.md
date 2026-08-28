# Deterministic Rule Engine and Confidence Scoring Design

## 1. Status and scope

- Owner: Kiang Min Wei, Module 4 — AI Operations Recommendation.
- Status: architectural design approved on 2026-08-28.
- This document specifies future production behavior; it does not implement it.
- The existing recommendation domain models, status workflow, and model
  validation are complete.
- The deterministic rule engine, confidence-scoring algorithm, recommendation
  generator, UI, and persistence remain pending.

This milestone designs:

- An explicit `RecommendationRulePolicy`.
- A provider-neutral `RecommendationRuleInput`.
- Pure deterministic rule evaluation.
- Explainable evidence contributions.
- Operational-priority score calculation.
- Independent confidence calculation.
- Recommendation generation.
- The approved Bus B1023 and Route 300 behavior.
- Module-local unit tests.

This documentation milestone creates no Dart production or test code.

## 2. Selected architecture

The selected architecture consists of four cooperating parts:

1. An explicit policy containing every owner-approved heuristic.
2. A pure deterministic rule engine that evaluates normalized input in a
   stable order.
3. An independent explainable confidence scorer.
4. A recommendation generator that maps a valid evaluation into the existing
   `OperationsRecommendation` model.

Score and confidence represent different concepts:

- Score represents operational priority produced by matched rule
  contributions.
- Confidence represents the completeness and limitations of the evidence used
  by the evaluation.
- Neither value is a trained-machine-learning probability.
- Confidence is never derived from score.

The design rejects:

- Hidden hard-coded thresholds outside the explicit policy.
- Score-derived confidence.
- Trained-machine-learning or probability claims.
- Autonomous operational control.
- Direct imports from Modules 1, 2, or 3.

## 3. Planned module-local files

Future production work is limited to Module 4.

Files planned for addition:

- `lib/features/recommendations/domain/recommendation_rule_input.dart`
- `lib/features/recommendations/domain/recommendation_rule_policy.dart`
- `lib/features/recommendations/domain/recommendation_confidence.dart`
- `lib/features/recommendations/domain/recommendation_rule_evaluation.dart`
- `lib/features/recommendations/services/deterministic_recommendation_rule_engine.dart`
- `lib/features/recommendations/services/explainable_confidence_scorer.dart`
- `lib/features/recommendations/services/recommendation_generator.dart`

File planned for modification:

- `lib/features/recommendations/domain/recommendation.dart`

Corresponding module-local tests are planned as:

- `test/features/recommendations/domain/recommendation_rule_input_test.dart`
- `test/features/recommendations/domain/recommendation_rule_policy_test.dart`
- `test/features/recommendations/domain/recommendation_confidence_test.dart`
- `test/features/recommendations/domain/recommendation_rule_evaluation_test.dart`
- `test/features/recommendations/services/deterministic_recommendation_rule_engine_test.dart`
- `test/features/recommendations/services/explainable_confidence_scorer_test.dart`
- `test/features/recommendations/services/recommendation_generator_test.dart`
- Updates to `test/features/recommendations/domain/recommendation_test.dart` only
  where the existing model must expose the approved explanation safely.

No future change is planned outside `lib/features/recommendations/` and
`test/features/recommendations/` for this milestone.

## 4. Rule input

`RecommendationRuleInput` is an immutable, provider-neutral snapshot. It
conceptually contains:

- `incidentId`.
- `vehicleId`.
- `routeId`.
- `VehicleCondition`.
- `OperatingPeriod`.
- An evidence classification for the vehicle-condition fact.
- An evidence classification for the operating-period fact.
- An explicitly supplied `evaluatedAt` timestamp.

`VehicleCondition` has exactly these values:

- `breakdownConfirmed`
- `operational`
- `unknown`

`OperatingPeriod` has exactly these values:

- `peak`
- `offPeak`
- `unknown`

Peak or off-peak is supplied as an already normalized fact. Module 4 does not
silently define peak-hour clock ranges in this milestone. The rule input has no
occupancy, realtime passenger-demand, trip-update, service-alert, or rail
realtime field.

## 5. Approved rule policy

`RecommendationRulePolicy` makes the owner-approved Module 4 heuristics
explicit:

| Policy value | Approved value |
| --- | ---: |
| Confirmed-breakdown contribution | 50 |
| Peak-hour breakdown route-continuity contribution | 35 |
| Replacement-bus count | 2 |
| Breakdown confidence weight | 0.60 |
| Operating-period confidence weight | 0.40 |
| Demonstration-evidence penalty | 0.15 once per recommendation |
| Global minimum recommendation score | None |

For a confirmed off-peak breakdown, the engine recommends inspection or repair
only. It does not recommend replacement buses.

These values are Module 4 business heuristics. They are not claims made by
Prasarana, GTFS, or data.gov.my.

## 6. Deterministic rule flow

The engine uses this stable sequence:

1. Validate the input and policy.
2. Evaluate `confirmed-vehicle-breakdown`.
3. When it matches:
   - Create `InspectOrRepairVehicleAction` using the validated `vehicleId`.
   - Add understandable evidence.
   - Add the approved contribution of 50.
4. Evaluate `peak-breakdown-route-continuity`.
5. When the breakdown is confirmed and the operating period is peak:
   - Create `DeployReplacementBusesAction` using the validated `routeId`.
   - Set `busCount` to the policy value 2.
   - Add understandable evidence.
   - Add the approved contribution of 35.
6. Deduplicate actions by a stable action key.
7. Preserve stable action and evidence order.
8. Calculate operational-priority score.
9. Calculate confidence independently.
10. Return an immutable `RecommendationRuleEvaluation` with defensive,
    unmodifiable collections.
11. `RecommendationGenerator` creates an `OperationsRecommendation` only when
    the evaluation contains valid actions and evidence.
12. Every generated recommendation starts as `pendingReview`.

The stable action key includes the action type and its complete operational
payload: vehicle ID for inspection or repair, and route ID plus replacement-bus
count for deployment. Deduplication retains the first occurrence and therefore
does not disturb rule order.

## 7. Score calculation

The score is calculated only from matched evidence contributions:

```text
score = clamp(sum(matched evidence contributions), 0, 100)
```

For the approved B1023 peak-hour scenario:

```text
score = 50 + 35 = 85
```

Evidence contributions explain operational priority. They must never be
presented as probability, confidence, a trained-ML prediction, or government
data supplied by GTFS, Prasarana, or data.gov.my.

There is no global minimum recommendation score. Valid matched rules determine
whether actions and evidence exist; the generator does not apply an additional
hidden threshold.

## 8. Confidence calculation

Confidence is calculated from explicit evidence factors and penalties:

```text
baseConfidence =
  supportedEvidenceWeight / totalRequiredEvidenceWeight

finalConfidence =
  clamp(baseConfidence - sum(explicit penalties), 0.0, 1.0)
```

The required evidence factors are:

- Vehicle-condition fact, weighted 0.60.
- Operating-period fact, weighted 0.40.

A factor is supported when its normalized fact is known rather than `unknown`.
Its classification records the origin of that decision-critical fact.

For B1023 when both required facts are present:

```text
baseConfidence = (0.60 + 0.40) / 1.00 = 1.00
```

For the controlled demonstration fixture, the stable
`demonstration-evidence` penalty is applied once when one or more
decision-critical facts use `demonstrationData`:

```text
demonstration penalty = 0.15 once
finalConfidence = 1.00 - 0.15 = 0.85
```

It is not applied once per evidence item. The confidence result preserves:

- Base confidence.
- Each evidence factor, its weight, support state, and understandable
  description.
- Stable penalty IDs.
- Understandable penalty descriptions.
- Penalty amounts.
- Final confidence.

Confidence is never silently calculated from score.

### Approved confidence result types

The planned conceptual types are:

```text
RecommendationConfidence
- baseConfidence
- factors
- penalties
- finalConfidence

RecommendationConfidenceFactor
- factorId
- description
- weight
- isSupported

RecommendationConfidencePenalty
- penaltyId
- description
- amount
```

The factor and penalty collections use defensive, unmodifiable copies. Factor
IDs must be unique within one `RecommendationConfidence` result, and penalty
IDs must also be unique within that result.

### Approved OperationsRecommendation confidence API

The owner approved option A: `OperationsRecommendation` has one stored source
of confidence truth.

```dart
final RecommendationConfidence confidenceDetails;

double get confidence => confidenceDetails.finalConfidence;
```

Its constructor requires `confidenceDetails` instead of accepting an
independent raw confidence value. `confidenceDetails` stores the complete
explainable result, while the `confidence` getter preserves convenient numeric
read access. There must not be a second independently supplied confidence
`double`; this prevents `finalConfidence` and
`OperationsRecommendation.confidence` from disagreeing.

Existing recommendation tests will be updated during implementation. No Dart
change occurs in this documentation commit.

## 9. Approved B1023 and Route 300 result

The approved input is a confirmed breakdown of Bus B1023 on Route 300 during a
normalized peak operating period. The controlled fixture classifies its
decision-critical facts as demonstration evidence.

It produces exactly, in this order:

1. `InspectOrRepairVehicleAction(vehicleId: 'B1023')`
2. `DeployReplacementBusesAction(routeId: '300', busCount: 2)`

The generated result has:

- Score 85.
- Confidence 0.85 for the demonstration fixture.
- Status `pendingReview`.

> AI recommends. Staff decides.

Generation does not create or modify a work order, service deployment,
incident, vehicle assignment, or other operational state.

## 10. Validation and safe failure

Invalid programmer or configuration input throws `ArgumentError`. This
includes:

- Blank incident, vehicle, route, recommendation, rule, factor, or penalty
  IDs where required.
- Non-finite, negative, or otherwise invalid confidence weights; total required
  evidence weight must be finite and greater than zero.
- Non-finite penalties or penalty amounts outside the inclusive 0.0–1.0
  range.
- Replacement-bus count less than or equal to zero.
- A configured rule contribution that is not an integer in the inclusive
  0–100 range.
- Duplicate penalty IDs.
- Duplicate factor IDs.

`RecommendationRulePolicy` does not contain a separately supplied final score.
The engine sums matched contributions in deterministic rule order and clamps
the computed sum to the inclusive 0–100 range. There is no global minimum score
threshold.

The timestamp contract is exact:

- `RecommendationRuleInput` requires a non-null `DateTime evaluatedAt` and its
  constructor stores `evaluatedAt.toUtc()`.
- `RecommendationGenerator` requires a non-null `DateTime createdAt`.
- The generated `OperationsRecommendation` stores `createdAt.toUtc()`.
- The engine and generator do not call `DateTime.now()`.
- String parsing, malformed timestamp text, and provider timestamp mapping
  belong to future adapters and are outside this milestone.
- This milestone invents no relationship between `evaluatedAt` and `createdAt`.

The pure engine also does not infer peak or off-peak from a timestamp.

Valid but insufficient facts fail safely:

- `unknown` or `operational` vehicle condition produces no breakdown
  recommendation.
- Confirmed breakdown plus unknown operating period produces inspection or
  repair only.
- Confirmed off-peak breakdown produces inspection or repair only.
- No matched rule returns an evaluation explicitly representing no
  recommendation.
- The generator returns `null` instead of fabricating actions or evidence.

Provider, database, and network errors are outside this pure domain milestone.
The engine neither catches nor disguises them.

## 11. Provenance correction

The model must keep these concepts separate:

- Evidence origin classification.
- Cache, offline, or current read state.
- Retrieval time.
- Age at evaluation or display.
- Limitations and availability notes.

Verified official GTFS Static evidence may remain
`staticGovernmentData` when it is read from a bundled cache. Reading an item
from cache does not erase or replace its verified origin classification.
Conversely, the read state must still disclose that the current value came from
a cache; it must not be presented as a live read.

Cache, offline, and fallback state must be exposed separately and must not
replace evidence origin classification. The existing `cachedData` enum value
remains unchanged only because government-data contract changes are outside
this milestone. The new rule engine, confidence scorer, and recommendation
generator must not assign or interpret `cachedData` merely because evidence was
read from cache or fallback storage.

If official origin cannot be demonstrated, the system must not claim
`staticGovernmentData`. Resolving or deprecating the existing `cachedData` enum
value requires a separate reviewed government-data-contract change. No Dart
enum is modified by this documentation milestone.

This milestone does not modify the existing government-data contract. The
previously documented stale-context confidence penalty of 0.10 is not
integrated into this design. Any stale-context penalty requires a separate
reviewed integration after this provenance correction.

## 12. Recommendation generation boundary

`RecommendationGenerator` accepts the immutable evaluation together with
caller-supplied recommendation identity and creation timestamp. It copies the
validated incident, vehicle, and route identities from the evaluated input,
preserves the engine's action and evidence order, and assigns:

- The evaluation score.
- The complete `confidenceDetails`, from which the numeric `confidence` getter
  derives `finalConfidence`.
- `RecommendationStatus.pendingReview`.

It returns `null` for an evaluation with no recommendation. It exposes no API
for accepting recommendations, creating work orders, deploying buses, closing
incidents, or changing other modules.

## 13. Testing strategy

Future focused unit tests cover:

- Rule-input validation and UTC normalization.
- Policy validation for contributions, weights, penalties, and replacement-bus
  count.
- Exact rule matching.
- Stable action and evidence ordering.
- Stable-key action deduplication.
- Immutable evaluation and confidence results.
- Score summation and clamping to 0–100.
- Confidence-factor calculation.
- Exactly one demonstration penalty per recommendation.
- Penalty subtraction and clamping to 0.0–1.0.
- Independence between score and confidence.
- `confidenceDetails` as the single stored confidence source.
- The `confidence` getter equalling
  `confidenceDetails.finalConfidence`.
- Absence of an independent raw confidence constructor argument.
- Unique factor IDs within one confidence result.
- Unique penalty IDs within one confidence result.
- Defensive, unmodifiable factor and penalty lists.
- The exact two-action B1023 and Route 300 result.
- The confirmed off-peak inspect-only result.
- Unknown condition and operating-period behavior.
- No-match evaluation and generator `null` behavior.
- Generator output with `pendingReview`.
- Caller-supplied recommendation IDs and timestamps.
- `evaluatedAt` normalization to UTC.
- `createdAt` normalization to UTC.
- `cachedData` not being assigned merely because evidence came from cache.
- Unverified origin not being labelled `staticGovernmentData`.
- No autonomous work-order, deployment, or incident-state creation.
- No unsupported realtime, occupancy, or passenger-demand claims.

Future implementation verification must run:

```powershell
dart format --output=none --set-exit-if-changed lib/features/recommendations test/features/recommendations
flutter test test/features/recommendations
flutter analyze
flutter test
git diff --check
git status --short --branch
```

This design does not predict future test counts.

## 14. Explicit non-goals

This milestone includes none of the following:

- SQLite migration v5.
- A Supabase migration.
- Persistence.
- UI.
- Module 1, 2, or 3 changes.
- Shared database changes.
- App registry changes.
- Dependency changes.
- Government-data contract changes.
- A GTFS adapter implementation.
- A trained-machine-learning claim.
- An LLM dependency.
- Autonomous operational control.
- Fabricated occupancy.
- Fabricated realtime passenger demand.
- Trip updates.
- Service alerts.
- Rail realtime.
- An implementation plan in this commit.
- Dart implementation.

## 15. Completion boundary

This document records the approved deterministic rule-engine and explainable
confidence policy only. It does not claim that the rule engine, confidence
scorer, or recommendation generator exists. Work stops after this design
document is reviewed and committed. An implementation plan and Dart
implementation require separate authorization.
