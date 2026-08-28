import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/models/route_catalog.dart';
import 'package:prasa_assist/features/deployments/repositories/bundled_route_catalog_repository.dart';

void main() {
  const repository = BundledRouteCatalogRepository();

  test('returns all verified cached government routes', () async {
    final snapshot = await repository.loadCatalog();

    expect(snapshot.routes, hasLength(137));
    expect(
      snapshot.metadata.dataClassification,
      RouteCatalogDataClassification.cachedGovernmentStatic,
    );
    expect(
      snapshot.metadata.sourceUrl,
      'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-kl',
    );
    expect(
      snapshot.metadata.feedName,
      'data.gov.my GTFS Static — Prasarana Rapid Bus KL',
    );
    expect(
      snapshot.metadata.retrievedAtUtc.toIso8601String(),
      '2026-08-27T22:32:48.624Z',
    );
    expect(
      snapshot.metadata.sourceArchiveSha256,
      '977b748d479616ef683afcc8c9857ec01374b6d7f0ff3b371ed16868327ed4f1',
    );
    expect(snapshot.routes.every((route) => route.routeType == 3), isTrue);
    expect(
      snapshot.routes.map((route) => route.gtfsRouteId).toSet(),
      hasLength(137),
    );
    expect(
      snapshot.routes.map((route) => route.routeShortName).toSet(),
      hasLength(137),
    );
  });

  test('preserves the exact Route 300 record and advisory schedule', () async {
    final snapshot = await repository.loadCatalog();

    final route = snapshot.routeByShortName('300');
    expect(route, isNotNull);
    expect(route!.gtfsRouteId, 'U3000');
    expect(route.agencyId, 'rapidkl');
    expect(route.routeShortName, '300');
    expect(route.routeLongName, 'Terminal Maluri ~ Lebuh Ampang');
    expect(route.routeType, 3);
    expect(route.scheduleContext!.serviceIds, ['weekday', 'weekend']);
    expect(route.scheduleContext!.serviceValidFrom, '2020-04-01');
    expect(route.scheduleContext!.serviceValidUntil, '2027-03-31');
    expect(route.scheduleContext!.publishedServiceStart, '05:00');
    expect(route.scheduleContext!.publishedServiceEnd, '23:45');
  });

  test('contains no incident vehicle data', () async {
    final snapshot = await repository.loadCatalog();
    final searchable = [
      snapshot.metadata.feedName,
      snapshot.metadata.attribution,
      for (final route in snapshot.routes) ...[
        route.gtfsRouteId,
        route.routeShortName,
        route.routeLongName,
      ],
    ].join(' ');

    expect(searchable, isNot(contains('B1023')));
  });
}
