import 'rapid_bus_kl_route_snapshot.dart';
import 'route_catalog.dart';
import 'route_catalog_repository.dart';

class BundledRouteCatalogRepository implements RouteCatalogRepository {
  const BundledRouteCatalogRepository();

  @override
  Future<RouteCatalogSnapshot> loadCatalog() async {
    return rapidBusKlRouteSnapshot;
  }
}
