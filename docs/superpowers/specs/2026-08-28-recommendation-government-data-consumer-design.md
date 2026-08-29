# Recommendation Government-Data Consumer Design

## 1. Status and scope

- Stage: 1C.
- Architectural design approved on 2026-08-28.
- This design defines a provider-neutral Module 4 consumer boundary.
- This stage does not integrate a rule engine.
- This stage does not add UI.
- This stage does not implement HTTP, GTFS downloading or parsing, or protobuf handling.
- This stage does not import from or modify Module 3.

The purpose of Stage 1C is to define how Module 4 can consume a verified,
immutable route context without taking ownership of government-data ingestion.
All production types described below are planned work and are not implemented by
this documentation commit.

## 2. Confirmed upstream government data

PR #4 merged Module 3's bundled Rapid Bus KL route catalogue into the current
baseline. The catalogue is cached government static data derived from a verified
Prasarana GTFS Static feed. Runtime code does not download or parse the feed.

The bundled snapshot confirms the following Route 300 record:

| Field | Confirmed value |
| --- | --- |
| `gtfsRouteId` | `U3000` |
| `routeShortName` | `300` |
| `routeLongName` | `Terminal Maluri ~ Lebuh Ampang` |
| `routeType` | `3` |
| `agencyId` | `rapidkl` |
| `serviceIds` | `weekday`, `weekend` |
| `serviceDays` | Monday through Sunday |
| `serviceValidFrom` | `2020-04-01` |
| `serviceValidUntil` | `2027-03-31` |
| `publishedServiceStart` | `05:00` |
| `publishedServiceEnd` | `23:45` |

The confirmed snapshot provenance is:

| Field | Confirmed value |
| --- | --- |
| `sourceUrl` | `https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-kl` |
| `feedName` | `data.gov.my GTFS Static — Prasarana Rapid Bus KL` |
| `attribution` | `Government of Malaysia data.gov.my; Prasarana Malaysia; Rapid KL` |
| `retrievedAtUtc` | `2026-08-27T22:32:48.624Z` |
| `providerLastModifiedUtc` | `2026-08-27T19:18:06Z` |
| `providerEtag` | `"105f907dedcc2f6977230088ac8873fb"` |
| `sourceArchiveSha256` | `977b748d479616ef683afcc8c9857ec01374b6d7f0ff3b371ed16868327ed4f1` |
| Source classification | Cached government static |
| `agencyName` | `Rapid KL` |
| `agencyUrl` | `http://www.myrapid.com.my` |
| `agencyTimezone` | `Asia/Kuala_Lumpur` |

These are confirmed upstream values already compiled into Module 3. They are
not a new Module 4 copy of the feed, and they must not be described as realtime
operational data.

## 3. Ownership boundary

Module 3 owns:

- The static route snapshot.
- Route catalogue models.
- The static repository implementation.
- Static feed provenance.
- The mapping of the bundled feed record to Route 300.

Module 4 owns:

- A provider-neutral consumer interface.
- An immutable recommendation route input snapshot.
- A test fixture and fake provider under `test/`.
- The recommendation-specific freshness policy.
- Mapping route context and freshness into recommendation evidence.

The coordinator later owns the narrow mapping from the Module 3 route catalogue
to the Module 4 consumer boundary.

Module 4 must not directly import:

- Deployment controllers.
- Deployment widgets.
- `BundledRouteCatalogRepository`.
- `rapidBusKlRouteSnapshot`.
- Deployment-specific enums or models.

This boundary preserves individual module ownership and prevents the
recommendation domain from depending on Module 3 storage or UI implementation
details.

## 4. Selected architecture

The selected architecture is a flat provider-neutral context:

- One immutable `RecommendationRouteContext`.
- One `RecommendationRouteContextProvider`.
- One `RecommendationRouteFreshnessPolicy`.
- One `RecommendationRouteEvidenceMapper`.
- A Route 300 fixture only under `test/`.

Rejected alternatives:

- A nested value-object hierarchy is rejected for Stage 1C because it adds
  structure that current consumers do not need.
- Direct Module 3 imports are rejected because they create cross-module
  coupling and transfer implementation assumptions into Module 4.
- A shared GTFS foundation is rejected because Module 3 already owns static
  ingestion and its verified bundled snapshot.
- A GTFS Realtime adapter is rejected from this stage because it requires a
  separate reviewed proposal, ownership decision, and verified feed contract.

## 5. Planned production files

The following production files are planned but are not created by this
documentation commit:

- `lib/features/recommendations/domain/recommendation_route_context.dart`
- `lib/features/recommendations/domain/recommendation_route_context_provider.dart`
- `lib/features/recommendations/domain/recommendation_route_freshness.dart`
- `lib/features/recommendations/domain/recommendation_route_evidence_mapper.dart`

## 6. RecommendationRouteContext fields

The flat context contains these conceptual fields.

Route identity:

- `sourceRouteId`
- `routeShortName`
- `routeLongName`
- `routeType`

Agency:

- `agencyId`
- `agencyName`
- `agencyUrl`
- `agencyTimezone`

Published schedule context:

- `serviceIds`
- `serviceDays`
- `serviceValidFrom`
- `serviceValidUntil`
- `publishedServiceStart`
- `publishedServiceEnd`

Provenance:

- `sourceUrl`
- `feedName`
- `attribution`
- `retrievedAt`
- `providerLastModifiedAt`
- `providerEtag`
- `sourceArchiveSha256`
- `dataClassification`
- `sourceLimitations`

The Module 3 names `gtfsRouteId`, `retrievedAtUtc`, and
`providerLastModifiedUtc` are mapped at the future coordinator adapter boundary.
No Module 3 type crosses into Module 4.

## 7. Validation and immutability

The planned context follows these rules:

- Required strings must not be empty or blank.
- `DateTime` fields are normalized to UTC.
- `providerLastModifiedAt` must not be after `retrievedAt`.
- `sourceArchiveSha256` must contain exactly 64 hexadecimal characters.
- `serviceIds`, `serviceDays`, and `sourceLimitations` use defensive
  unmodifiable copies.
- GTFS wall-clock schedule fields remain strings because GTFS service times may
  exceed `24:00`.
- Allowed classifications are `staticGovernmentData` and `cachedData`.
- `liveGovernmentData`, `internalOperationalData`, and `demonstrationData` are
  rejected for this static route context.

The context is an immutable input snapshot. It exposes no operation that
downloads data, changes deployment state, or mutates a recommendation.

## 8. Provider contract

The conceptual provider signature is:

```dart
Future<RecommendationRouteContext?> findByShortName(
  String routeShortName,
);
```

Contract behaviour:

- `null` means that the requested route was not found.
- The provider must not fabricate a demonstration route when a route is absent.
- No Module 3 type crosses the interface.
- A fake implementation remains under `test/`.
- The actual coordinator-owned Module 3 mapping is outside Stage 1C.

The signature is illustrative design documentation, not completed production
code.

## 9. Freshness policy

Freshness is evaluated deterministically against an explicitly supplied
`evaluatedAt` value. The domain policy does not call `DateTime.now()`.

Approved behaviour:

- If age is less than or equal to 24 hours, the context is fresh.
- If age is greater than 24 hours, the context is stale.
- If `evaluatedAt` is before `retrievedAt`, evaluation throws `ArgumentError`.
- Fresh data has `recommendedConfidencePenalty` equal to `0.0`.
- Stale data has `recommendedConfidencePenalty` equal to `0.10`.
- Stage 1C does not mutate `OperationsRecommendation.confidence`.

Stage 1D may later apply the following relationship:

```text
adjustedConfidence = max(0.0, baseConfidence - penalty)
```

The `0.10` stale-data penalty is a transparent Module 4 heuristic. It is not a
claim or recommendation made by GTFS, Prasarana, or data.gov.my.

## 10. Evidence mapping

`RecommendationRouteEvidenceMapper` will create the existing
`RecommendationEvidence` type with understandable evidence covering:

- A stable government-route-context rule ID.
- Route identity and published schedule context.
- Source and feed attribution.
- The retrieved timestamp.
- Cached or static classification.
- Fresh or stale status.
- Source limitations.
- An explicit statement that the published schedule is not realtime operation.

Evidence must never claim that the feed provides:

- Occupancy.
- Realtime passenger demand.
- Trip updates.
- Service alerts.
- Rail realtime.

## 11. Error behaviour

- A missing route returns `null`.
- Invalid constructor input throws `ArgumentError`.
- Invalid timestamp ordering throws `ArgumentError`.
- An invalid SHA-256 value throws `ArgumentError`.
- An invalid data classification throws `ArgumentError`.
- A retrieval timestamp in the future relative to `evaluatedAt` throws
  `ArgumentError`.
- Stale data remains usable, accompanied by a limitation and the transparent
  confidence penalty.
- Provider errors are not swallowed by this contract.
- Timeout handling and cache fallback belong to a later GTFS Realtime adapter
  proposal.

## 12. Data flow

1. A future coordinator adapter maps Module 3 route catalogue data into the
   provider-neutral context.
2. The provider returns `RecommendationRouteContext` or `null` when the route is
   absent.
3. The freshness policy assesses the context at the supplied `evaluatedAt`.
4. The evidence mapper creates `RecommendationEvidence`.
5. The Stage 1D rule engine may later apply the confidence penalty.
6. UI presentation remains outside Stage 1C.

No step automatically deploys a vehicle, creates a work order, closes an
incident, or changes operational state. AI recommends; staff decides.

## 13. Test strategy

The implementation stage will cover:

- Exact Route 300 fixture values and provenance.
- Immutability and defensive copying.
- All constructor validation rules.
- Provider success and unknown-route `null` behaviour.
- Freshness below, exactly at, and above 24 hours.
- Invalid future retrieval relative to `evaluatedAt`.
- Exact `0.0` and `0.10` confidence penalties.
- Evidence classification and understandable description.
- Stale-data limitation text.
- Absence of realtime, occupancy, and passenger-demand claims.
- Absence of direct Module 3 imports.
- Focused tests for each planned type.
- All Module 4 domain tests.
- `flutter analyze`.
- Complete `flutter test`.
- `git diff --check`.
- A final file-scope review.

Tests use real domain behaviour. The Route 300 fixture and fake provider remain
under `test/` and do not become production fallback data.

## 14. Explicit non-goals

Stage 1C includes none of the following:

- HTTP.
- Protobuf.
- Archive or CSV parsing.
- A GTFS Static downloader.
- A complete copy of the Module 3 snapshot.
- Module 3 changes.
- `pubspec.yaml` changes.
- Shared dependency injection.
- `module_registry.dart` changes.
- Supabase.
- A GTFS Realtime adapter.
- Rule-engine integration.
- UI.

## 15. Future stages

- Stage 1D may integrate the route context and freshness result into the rule
  engine after separate approval.
- A later UI stage may present evidence and freshness to staff.
- A GTFS Realtime vehicle-position adapter requires a separate reviewed
  proposal.
- Extraction to `lib/shared/` may be reconsidered only if another module needs
  Realtime vehicle positions and the coordinator approves shared ownership.

This design does not authorize implementation planning or production code. The
next action after this documentation commit is user review of the written spec.
