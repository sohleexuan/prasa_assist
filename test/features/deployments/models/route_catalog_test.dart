import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/models/route_catalog.dart';

void main() {
  group('RouteCatalogSourceMetadata', () {
    test('normalizes provenance timestamps to UTC', () {
      final metadata = _metadata(
        retrievedAt: DateTime.parse('2026-08-28T06:32:48.624+08:00'),
      );

      expect(metadata.retrievedAtUtc.isUtc, isTrue);
      expect(
        metadata.retrievedAtUtc,
        DateTime.parse('2026-08-27T22:32:48.624Z'),
      );
    });

    test('rejects missing or malformed source metadata', () {
      expect(() => _metadata(sourceUrl: 'relative/path'), throwsArgumentError);
      expect(() => _metadata(feedName: ' '), throwsArgumentError);
      expect(() => _metadata(sha256: 'not-a-hash'), throwsArgumentError);
    });
  });

  group('RouteScheduleContext', () {
    test('preserves GTFS service-day times beyond midnight', () {
      final context = _schedule(end: '25:15');

      expect(context.publishedServiceEnd, '25:15');
      expect(context.serviceIds, ['weekday', 'weekend']);
      expect(() => context.serviceIds.add('other'), throwsUnsupportedError);
    });

    test('rejects malformed days, dates, and service times', () {
      expect(() => _schedule(days: const ['holiday']), throwsArgumentError);
      expect(() => _schedule(validFrom: '2026-02-30'), throwsArgumentError);
      expect(() => _schedule(start: '05:99'), throwsArgumentError);
      expect(
        () => _schedule(validFrom: '2027-01-01', validUntil: '2026-01-01'),
        throwsArgumentError,
      );
    });
  });

  group('RouteCatalogSnapshot', () {
    test('is immutable and finds a route by its short name', () {
      final route = _route();
      final snapshot = RouteCatalogSnapshot(
        metadata: _metadata(),
        routes: [route],
      );

      expect(snapshot.routeByShortName('300'), same(route));
      expect(snapshot.routeByShortName('missing'), isNull);
      expect(() => snapshot.routes.add(route), throwsUnsupportedError);
    });

    test('rejects empty, duplicate, and wrong-agency routes', () {
      expect(
        () => RouteCatalogSnapshot(metadata: _metadata(), routes: const []),
        throwsArgumentError,
      );
      expect(
        () => RouteCatalogSnapshot(
          metadata: _metadata(),
          routes: [_route(), _route()],
        ),
        throwsArgumentError,
      );
      expect(
        () => RouteCatalogSnapshot(
          metadata: _metadata(),
          routes: [_route(agencyId: 'other')],
        ),
        throwsArgumentError,
      );
    });
  });
}

RouteCatalogSourceMetadata _metadata({
  String sourceUrl =
      'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-kl',
  String feedName = 'Prasarana Rapid Bus KL',
  String sha256 =
      '977b748d479616ef683afcc8c9857ec01374b6d7f0ff3b371ed16868327ed4f1',
  DateTime? retrievedAt,
}) {
  return RouteCatalogSourceMetadata(
    sourceUrl: sourceUrl,
    feedName: feedName,
    attribution: 'Government of Malaysia data.gov.my; Rapid KL',
    retrievedAtUtc: retrievedAt ?? DateTime.utc(2026, 8, 27, 22, 32),
    providerLastModifiedUtc: DateTime.utc(2026, 8, 27, 19, 18),
    providerEtag: 'etag',
    sourceArchiveSha256: sha256,
    dataClassification: RouteCatalogDataClassification.cachedGovernmentStatic,
    agencyId: 'rapidkl',
    agencyName: 'Rapid KL',
    agencyUrl: 'http://www.myrapid.com.my',
    agencyTimezone: 'Asia/Kuala_Lumpur',
  );
}

RouteScheduleContext _schedule({
  List<String> days = const ['monday', 'sunday'],
  String validFrom = '2020-04-01',
  String validUntil = '2027-03-31',
  String start = '05:00',
  String end = '23:45',
}) {
  return RouteScheduleContext(
    serviceIds: const ['weekday', 'weekend'],
    serviceDays: days,
    serviceValidFrom: validFrom,
    serviceValidUntil: validUntil,
    publishedServiceStart: start,
    publishedServiceEnd: end,
  );
}

RouteCatalogEntry _route({String agencyId = 'rapidkl'}) {
  return RouteCatalogEntry(
    gtfsRouteId: 'U3000',
    agencyId: agencyId,
    routeShortName: '300',
    routeLongName: 'Terminal Maluri ~ Lebuh Ampang',
    routeType: 3,
    scheduleContext: _schedule(),
  );
}
