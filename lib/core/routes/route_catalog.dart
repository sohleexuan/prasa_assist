enum RouteCatalogDataClassification { cachedGovernmentStatic }

class RouteCatalogSourceMetadata {
  RouteCatalogSourceMetadata({
    required this.sourceUrl,
    required this.feedName,
    required this.attribution,
    required DateTime retrievedAtUtc,
    required DateTime providerLastModifiedUtc,
    required this.providerEtag,
    required this.sourceArchiveSha256,
    required this.dataClassification,
    required this.agencyId,
    required this.agencyName,
    required this.agencyUrl,
    required this.agencyTimezone,
  }) : retrievedAtUtc = retrievedAtUtc.toUtc(),
       providerLastModifiedUtc = providerLastModifiedUtc.toUtc() {
    _requireText(sourceUrl, 'sourceUrl');
    _requireAbsoluteUrl(sourceUrl, 'sourceUrl');
    _requireText(feedName, 'feedName');
    _requireText(attribution, 'attribution');
    _requireText(providerEtag, 'providerEtag');
    _requireSha256(sourceArchiveSha256);
    _requireText(agencyId, 'agencyId');
    _requireText(agencyName, 'agencyName');
    _requireText(agencyUrl, 'agencyUrl');
    _requireAbsoluteUrl(agencyUrl, 'agencyUrl');
    _requireText(agencyTimezone, 'agencyTimezone');
  }

  final String sourceUrl;
  final String feedName;
  final String attribution;
  final DateTime retrievedAtUtc;
  final DateTime providerLastModifiedUtc;
  final String providerEtag;
  final String sourceArchiveSha256;
  final RouteCatalogDataClassification dataClassification;
  final String agencyId;
  final String agencyName;
  final String agencyUrl;
  final String agencyTimezone;
}

class RouteScheduleContext {
  RouteScheduleContext({
    required List<String> serviceIds,
    required List<String> serviceDays,
    required this.serviceValidFrom,
    required this.serviceValidUntil,
    required this.publishedServiceStart,
    required this.publishedServiceEnd,
  }) : serviceIds = List<String>.unmodifiable(serviceIds),
       serviceDays = List<String>.unmodifiable(serviceDays) {
    if (serviceIds.isEmpty || serviceIds.any((value) => value.trim().isEmpty)) {
      throw ArgumentError.value(serviceIds, 'serviceIds');
    }
    if (serviceDays.isEmpty ||
        serviceDays.any((value) => !_validServiceDays.contains(value))) {
      throw ArgumentError.value(serviceDays, 'serviceDays');
    }
    _requireIsoDate(serviceValidFrom, 'serviceValidFrom');
    _requireIsoDate(serviceValidUntil, 'serviceValidUntil');
    if (serviceValidFrom.compareTo(serviceValidUntil) > 0) {
      throw ArgumentError('Service validity start must not be after its end.');
    }
    _requireGtfsServiceTime(publishedServiceStart, 'publishedServiceStart');
    _requireGtfsServiceTime(publishedServiceEnd, 'publishedServiceEnd');
  }

  static const _validServiceDays = <String>{
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  };

  final List<String> serviceIds;
  final List<String> serviceDays;
  final String serviceValidFrom;
  final String serviceValidUntil;

  final String publishedServiceStart;
  final String publishedServiceEnd;
}

class RouteCatalogEntry {
  RouteCatalogEntry({
    required this.gtfsRouteId,
    required this.agencyId,
    required this.routeShortName,
    required this.routeLongName,
    required this.routeType,
    this.scheduleContext,
  }) {
    _requireText(gtfsRouteId, 'gtfsRouteId');
    _requireText(agencyId, 'agencyId');
    _requireText(routeShortName, 'routeShortName');
    _requireText(routeLongName, 'routeLongName');
    if (routeType < 0) {
      throw ArgumentError.value(routeType, 'routeType');
    }
  }

  final String gtfsRouteId;
  final String agencyId;

  final String routeShortName;

  final String routeLongName;
  final int routeType;
  final RouteScheduleContext? scheduleContext;
}

class RouteCatalogSnapshot {
  RouteCatalogSnapshot({
    required this.metadata,
    required List<RouteCatalogEntry> routes,
  }) : routes = List<RouteCatalogEntry>.unmodifiable(routes) {
    if (routes.isEmpty) {
      throw ArgumentError.value(routes, 'routes');
    }
    if (routes.any((route) => route.agencyId != metadata.agencyId)) {
      throw ArgumentError('Every route must belong to the snapshot agency.');
    }
    if (routes.map((route) => route.gtfsRouteId).toSet().length !=
        routes.length) {
      throw ArgumentError('GTFS route IDs must be unique.');
    }
    if (routes.map((route) => route.routeShortName).toSet().length !=
        routes.length) {
      throw ArgumentError('Route short names must be unique.');
    }
  }

  final RouteCatalogSourceMetadata metadata;
  final List<RouteCatalogEntry> routes;

  RouteCatalogEntry? routeByShortName(String routeShortName) {
    final normalizedRouteId = normalizeRouteId(routeShortName);
    for (final route in routes) {
      if (normalizeRouteId(route.routeShortName) == normalizedRouteId) {
        return route;
      }
    }
    return null;
  }
}

String normalizeRouteId(String value) => value.trim().toUpperCase();

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
}

void _requireAbsoluteUrl(String value, String name) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw ArgumentError.value(value, name, 'must be an absolute URL');
  }
}

void _requireSha256(String value) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw ArgumentError.value(value, 'sourceArchiveSha256');
  }
}

void _requireIsoDate(String value, String name) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw ArgumentError.value(value, name, 'must use YYYY-MM-DD');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
    throw ArgumentError.value(value, name, 'must be a valid date');
  }
}

void _requireGtfsServiceTime(String value, String name) {
  final match = RegExp(r'^(\d{2,}):(\d{2})$').firstMatch(value);
  if (match == null || int.parse(match.group(2)!) > 59) {
    throw ArgumentError.value(value, name, 'must use GTFS HH:MM');
  }
}
