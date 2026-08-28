import 'package:flutter/foundation.dart';

import '../models/route_catalog.dart';
import '../repositories/route_catalog_repository.dart';

enum RouteCatalogLoadState { initial, loading, loaded, unavailable }

class RouteCatalogController extends ChangeNotifier {
  RouteCatalogController(this._repository);

  final RouteCatalogRepository _repository;

  RouteCatalogLoadState _state = RouteCatalogLoadState.initial;
  RouteCatalogSnapshot? _snapshot;

  RouteCatalogLoadState get state => _state;
  RouteCatalogSnapshot? get snapshot => _snapshot;
  List<RouteCatalogEntry> get routes => _snapshot?.routes ?? const [];

  Future<void> loadCatalog() async {
    if (_state == RouteCatalogLoadState.loading) {
      return;
    }
    _state = RouteCatalogLoadState.loading;
    notifyListeners();
    try {
      _snapshot = await _repository.loadCatalog();
      _state = RouteCatalogLoadState.loaded;
    } catch (_) {
      // Provider details are deliberately not exposed to future UI consumers.
      _snapshot = null;
      _state = RouteCatalogLoadState.unavailable;
    }
    notifyListeners();
  }
}
