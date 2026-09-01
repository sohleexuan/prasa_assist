import 'route_catalog.dart';

abstract interface class RouteCatalogRepository {
  Future<RouteCatalogSnapshot> loadCatalog();
}
