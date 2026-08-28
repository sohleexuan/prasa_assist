import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/controllers/route_catalog_controller.dart';
import 'package:prasa_assist/features/deployments/models/route_catalog.dart';
import 'package:prasa_assist/features/deployments/repositories/route_catalog_repository.dart';

void main() {
  test('loads a snapshot through only the repository abstraction', () async {
    final repository = _FakeRouteCatalogRepository(snapshot: _snapshot());
    final controller = RouteCatalogController(repository);
    final states = <RouteCatalogLoadState>[];
    controller.addListener(() => states.add(controller.state));

    await controller.loadCatalog();

    expect(repository.loadCount, 1);
    expect(states, [
      RouteCatalogLoadState.loading,
      RouteCatalogLoadState.loaded,
    ]);
    expect(controller.snapshot, isNotNull);
    expect(controller.routes.single.routeShortName, '300');
  });

  test('converts repository failures into a safe unavailable state', () async {
    final repository = _FakeRouteCatalogRepository(
      error: StateError('private provider detail'),
    );
    final controller = RouteCatalogController(repository);

    await controller.loadCatalog();

    expect(controller.state, RouteCatalogLoadState.unavailable);
    expect(controller.snapshot, isNull);
    expect(controller.routes, isEmpty);
  });

  test('ignores a duplicate load while one is already running', () async {
    final completer = Completer<RouteCatalogSnapshot>();
    final repository = _FakeRouteCatalogRepository(completer: completer);
    final controller = RouteCatalogController(repository);

    final firstLoad = controller.loadCatalog();
    final secondLoad = controller.loadCatalog();
    expect(repository.loadCount, 1);

    completer.complete(_snapshot());
    await Future.wait([firstLoad, secondLoad]);

    expect(controller.state, RouteCatalogLoadState.loaded);
  });
}

class _FakeRouteCatalogRepository implements RouteCatalogRepository {
  _FakeRouteCatalogRepository({this.snapshot, this.error, this.completer});

  final RouteCatalogSnapshot? snapshot;
  final Object? error;
  final Completer<RouteCatalogSnapshot>? completer;
  int loadCount = 0;

  @override
  Future<RouteCatalogSnapshot> loadCatalog() async {
    loadCount++;
    if (error case final failure?) {
      throw failure;
    }
    if (completer case final pending?) {
      return pending.future;
    }
    return snapshot!;
  }
}

RouteCatalogSnapshot _snapshot() {
  return RouteCatalogSnapshot(
    metadata: RouteCatalogSourceMetadata(
      sourceUrl:
          'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-kl',
      feedName: 'Prasarana Rapid Bus KL',
      attribution: 'Government of Malaysia data.gov.my; Rapid KL',
      retrievedAtUtc: DateTime.utc(2026, 8, 27),
      providerLastModifiedUtc: DateTime.utc(2026, 8, 27),
      providerEtag: 'etag',
      sourceArchiveSha256:
          '977b748d479616ef683afcc8c9857ec01374b6d7f0ff3b371ed16868327ed4f1',
      dataClassification: RouteCatalogDataClassification.cachedGovernmentStatic,
      agencyId: 'rapidkl',
      agencyName: 'Rapid KL',
      agencyUrl: 'http://www.myrapid.com.my',
      agencyTimezone: 'Asia/Kuala_Lumpur',
    ),
    routes: [
      RouteCatalogEntry(
        gtfsRouteId: 'U3000',
        agencyId: 'rapidkl',
        routeShortName: '300',
        routeLongName: 'Terminal Maluri ~ Lebuh Ampang',
        routeType: 3,
      ),
    ],
  );
}
