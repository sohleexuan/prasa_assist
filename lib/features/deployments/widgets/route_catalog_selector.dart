import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../controllers/route_catalog_controller.dart';
import '../models/route_catalog.dart';

class RouteCatalogSelector extends StatefulWidget {
  const RouteCatalogSelector({
    required this.controller,
    required this.onRouteSelected,
    this.enabled = true,
    super.key,
  });

  final RouteCatalogController controller;
  final ValueChanged<RouteCatalogEntry> onRouteSelected;
  final bool enabled;

  @override
  State<RouteCatalogSelector> createState() => _RouteCatalogSelectorState();
}

class _RouteCatalogSelectorState extends State<RouteCatalogSelector> {
  static const int _maximumVisibleResults = 8;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return switch (widget.controller.state) {
          RouteCatalogLoadState.initial ||
          RouteCatalogLoadState.loading => const _CatalogLoading(),
          RouteCatalogLoadState.unavailable => const _CatalogUnavailable(),
          RouteCatalogLoadState.loaded => _buildLoaded(context),
        };
      },
    );
  }

  Widget _buildLoaded(BuildContext context) {
    final snapshot = widget.controller.snapshot!;
    final matches = _matchingRoutes(snapshot.routes);
    final visibleMatches = matches
        .take(_maximumVisibleResults)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CachedDataLabel(),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          key: const ValueKey('route-catalog-search-field'),
          controller: _searchController,
          focusNode: _searchFocusNode,
          enabled: widget.enabled,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Search government route catalogue',
            hintText: 'Route number, name, or GTFS route ID',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    key: const ValueKey('clear-route-catalog-search'),
                    tooltip: 'Clear route search',
                    onPressed: widget.enabled ? _clearSearch : null,
                    icon: const Icon(Icons.clear),
                  ),
          ),
          onChanged: (value) {
            if (mounted) {
              setState(() => _query = value);
            }
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_query.trim().isEmpty)
          const Text(
            'Search to review routes. Existing route values stay unchanged '
            'until staff selects a result.',
            key: ValueKey('route-catalog-search-guidance'),
          )
        else if (visibleMatches.isEmpty)
          const Text(
            'No matching cached route. Manual route entry remains available.',
            key: ValueKey('route-catalog-no-results'),
          )
        else ...[
          if (matches.length > _maximumVisibleResults)
            Text(
              'Showing the first $_maximumVisibleResults of '
              '${matches.length} matching routes.',
              key: const ValueKey('route-catalog-result-limit'),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              key: const ValueKey('route-catalog-results'),
              shrinkWrap: true,
              primary: false,
              itemCount: visibleMatches.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final route = visibleMatches[index];
                return _RouteResultTile(
                  route: route,
                  enabled: widget.enabled,
                  onSelected: () => _selectRoute(route),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        _SourceAttribution(metadata: snapshot.metadata),
      ],
    );
  }

  List<RouteCatalogEntry> _matchingRoutes(List<RouteCatalogEntry> routes) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }
    return routes
        .where(
          (route) =>
              route.routeShortName.toLowerCase().contains(query) ||
              route.gtfsRouteId.toLowerCase().contains(query) ||
              route.routeLongName.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
    _searchFocusNode.requestFocus();
  }

  void _selectRoute(RouteCatalogEntry route) {
    widget.onRouteSelected(route);
    if (!mounted) {
      return;
    }
    _searchController.clear();
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _query = '');
  }
}

class _CatalogLoading extends StatelessWidget {
  const _CatalogLoading();

  @override
  Widget build(BuildContext context) {
    return const Row(
      key: ValueKey('route-catalog-loading'),
      children: [
        SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(child: Text('Loading cached route guidance...')),
      ],
    );
  }
}

class _CatalogUnavailable extends StatelessWidget {
  const _CatalogUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Row(
      key: ValueKey('route-catalog-unavailable'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Route guidance is unavailable. Manual or prefilled route entry '
            'remains available, and deployment saving can continue.',
          ),
        ),
      ],
    );
  }
}

class _CachedDataLabel extends StatelessWidget {
  const _CachedDataLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.dataset_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.xs),
        const Expanded(
          child: Text(
            'Cached government static data',
            key: ValueKey('route-catalog-data-label'),
          ),
        ),
      ],
    );
  }
}

class _RouteResultTile extends StatelessWidget {
  const _RouteResultTile({
    required this.route,
    required this.enabled,
    required this.onSelected,
  });

  final RouteCatalogEntry route;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final schedule = route.scheduleContext;
    return ListTile(
      key: ValueKey('route-catalog-result-${route.gtfsRouteId}'),
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      minVerticalPadding: AppSpacing.sm,
      title: Text(
        route.routeShortName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(route.routeLongName),
          Text('GTFS route reference: ${route.gtfsRouteId}'),
          if (schedule != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Static schedule (advisory): '
              '${_serviceDays(schedule.serviceDays)}, '
              '${schedule.publishedServiceStart}\u2013'
              '${schedule.publishedServiceEnd}',
              key: ValueKey('route-schedule-${route.gtfsRouteId}'),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: enabled ? onSelected : null,
    );
  }

  static String _serviceDays(List<String> days) {
    if (days.length == 7) {
      return 'Daily';
    }
    return days
        .map((day) => '${day[0].toUpperCase()}${day.substring(1)}')
        .join(', ');
  }
}

class _SourceAttribution extends StatelessWidget {
  const _SourceAttribution({required this.metadata});

  final RouteCatalogSourceMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final retrieved = _formatRetrievedAtUtc(metadata.retrievedAtUtc);
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Column(
      key: const ValueKey('route-catalog-attribution'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Government of Malaysia data.gov.my', style: style),
        Text('Prasarana / Rapid KL', style: style),
        Text('Retrieved $retrieved', style: style),
      ],
    );
  }

  String _formatRetrievedAtUtc(DateTime value) {
    const monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final utc = value.toUtc();
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    return '$day ${monthNames[utc.month - 1]} ${utc.year}, '
        '$hour:$minute UTC';
  }
}
