import '../models/route_catalog.dart';

abstract interface class RouteCatalogRepository {
  Future<RouteCatalogSnapshot> loadCatalog();
}
