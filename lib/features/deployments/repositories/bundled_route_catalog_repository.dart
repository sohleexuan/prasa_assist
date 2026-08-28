import '../data/snapshots/rapid_bus_kl_route_snapshot.dart';
import '../models/route_catalog.dart';
import 'route_catalog_repository.dart';

/// Reads only the verified snapshot compiled into Module 3.
///
/// It performs no network, archive, CSV, file-storage, or Supabase work.
class BundledRouteCatalogRepository implements RouteCatalogRepository {
  const BundledRouteCatalogRepository();

  @override
  Future<RouteCatalogSnapshot> loadCatalog() async {
    return rapidBusKlRouteSnapshot;
  }
}
