import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/database/local_sync_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../controllers/incident_controller.dart';
import '../controllers/incident_state.dart';
import '../integration/m1_incident_recommendation_facts.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../models/incident_query.dart';
import '../models/local_incident_work_item.dart';
import '../repositories/in_memory_incident_repository.dart';
import '../repositories/incident_repository.dart';
import '../services/incident_report_factory.dart';
import '../widgets/incident_card.dart';
import '../widgets/incident_data_notice.dart';
import 'incident_detail_page.dart';
import 'incident_report_page.dart';

/// Normal page entry point for Module 1.
///
/// This page owns its Controller but does not create a MaterialApp or modify
/// shared navigation. The integration layer may inject a different Repository
/// after the team approves a shared Incident persistence contract.
class IncidentListPage extends StatefulWidget {
  const IncidentListPage({
    required this.currentStaffId,
    this.repository,
    this.onReportIncident,
    this.onOpenIncident,
    this.onPrepareIncidentRecommendation,
    this.clock,
    this.incidentIdGenerator,
    super.key,
  });

  final String currentStaffId;
  final IncidentRepository? repository;
  final VoidCallback? onReportIncident;
  final ValueChanged<Incident>? onOpenIncident;
  final PrepareIncidentRecommendationCallback? onPrepareIncidentRecommendation;
  final DateTime Function()? clock;
  final IncidentIdGenerator? incidentIdGenerator;

  @override
  State<IncidentListPage> createState() => _IncidentListPageState();
}

class _IncidentListPageState extends State<IncidentListPage> {
  final TextEditingController _searchController = TextEditingController();
  late final IncidentController _controller;

  @override
  void initState() {
    super.initState();
    _controller = IncidentController(
      repository:
          widget.repository ??
          InMemoryIncidentRepository.withDemonstrationData(),
    );
    _controller.addListener(_handleControllerChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_controller.loadIncidents());
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChange);
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Incident Management',
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('report-incident-button'),
        onPressed: widget.onReportIncident ?? _openReport,
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('Report Incident'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final state = _controller.state;
    if (state.status == IncidentStateStatus.initial || state.isLoading) {
      return const AppLoadingIndicator(message: 'Loading incidents...');
    }
    if (state.status == IncidentStateStatus.error) {
      return AppErrorState(
        title: 'Unable to load incidents',
        message: state.errorMessage ?? 'Incident data is unavailable.',
        actionLabel: 'Retry',
        onAction: () => unawaited(_controller.loadIncidents()),
      );
    }
    if (state.status == IncidentStateStatus.empty && !state.hasActiveQuery) {
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            sliver: SliverToBoxAdapter(
              child: IncidentDataNotice(
                isPersistent: _controller.capabilities.isPersistent,
                provenance: state.listProvenance,
              ),
            ),
          ),
          if (state.localWorkItems.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: _LocalDraftSection(
                  items: state.localWorkItems,
                  onSubmit: (item) =>
                      unawaited(_controller.publishLocalDraft(item.localId)),
                  onDiscard: (item) =>
                      unawaited(_controller.discardLocalDraft(item.localId)),
                ),
              ),
            ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              title: 'No incidents reported',
              message:
                  'Report the first operational incident when staff identify '
                  'a service issue.',
              icon: Icons.warning_amber_outlined,
              actionLabel: widget.onReportIncident == null
                  ? null
                  : 'Report Incident',
              onAction: widget.onReportIncident,
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          sliver: SliverList.list(
            children: [
              IncidentDataNotice(
                isPersistent: _controller.capabilities.isPersistent,
                provenance: state.listProvenance,
              ),
              const SizedBox(height: AppSpacing.md),
              if (state.localWorkItems.isNotEmpty) ...[
                _LocalDraftSection(
                  items: state.localWorkItems,
                  onSubmit: (item) =>
                      unawaited(_controller.publishLocalDraft(item.localId)),
                  onDiscard: (item) =>
                      unawaited(_controller.discardLocalDraft(item.localId)),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _ResultSummary(count: state.incidents.length),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey('incident-search-field'),
                controller: _searchController,
                onChanged: _updateSearch,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search incidents, routes, vehicles, or locations',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _StatusFilter(
                selectedStatus: _singleValue(state.query.statuses),
                onSelected: _updateStatus,
              ),
              const SizedBox(height: AppSpacing.sm),
              LayoutBuilder(
                builder: (context, constraints) {
                  final filters = <Widget>[
                    _SeverityFilter(
                      selectedSeverity: _singleValue(state.query.severities),
                      onChanged: _updateSeverity,
                    ),
                    _TypeFilter(
                      selectedType: _singleValue(state.query.incidentTypes),
                      onChanged: _updateType,
                    ),
                    _SortFilter(
                      sortOrder: state.query.sortOrder,
                      onChanged: _updateSort,
                    ),
                  ];
                  if (constraints.maxWidth >= 640) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          var index = 0;
                          index < filters.length;
                          index++
                        ) ...[
                          Expanded(child: filters[index]),
                          if (index < filters.length - 1)
                            const SizedBox(width: AppSpacing.sm),
                        ],
                      ],
                    );
                  }
                  return Column(
                    children: [
                      for (var index = 0; index < filters.length; index++) ...[
                        filters[index],
                        if (index < filters.length - 1)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  );
                },
              ),
              if (state.hasActiveQuery)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const ValueKey('clear-incident-filters'),
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Clear search and filters'),
                  ),
                )
              else
                const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
        if (state.incidents.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              title: 'No matching incidents',
              message: 'Adjust or clear the active search and filters.',
              icon: Icons.filter_alt_off_outlined,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xxl * 2,
            ),
            sliver: SliverList.separated(
              itemCount: state.incidents.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final incident = state.incidents[index];
                return IncidentCard(
                  key: ValueKey('incident-card-${incident.incidentId}'),
                  incident: incident,
                  onTap: () {
                    final onOpenIncident = widget.onOpenIncident;
                    if (onOpenIncident != null) {
                      onOpenIncident(incident);
                    } else {
                      _openDetail(incident);
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  void _updateSearch(String searchTerm) {
    final query = _controller.state.query;
    unawaited(
      _controller.updateQuery(
        IncidentQuery(
          searchTerm: searchTerm,
          statuses: query.statuses,
          severities: query.severities,
          incidentTypes: query.incidentTypes,
          sortOrder: query.sortOrder,
        ),
      ),
    );
  }

  Future<void> _openReport() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => IncidentReportPage(
          controller: _controller,
          reportedBy: widget.currentStaffId,
          clock: widget.clock,
          incidentIdGenerator: widget.incidentIdGenerator,
          onSaved: (_) => Navigator.of(routeContext).pop(),
          onCancel: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  Future<void> _openDetail(Incident incident) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => IncidentDetailPage(
          controller: _controller,
          incidentId: incident.incidentId,
          currentStaffId: widget.currentStaffId,
          clock: widget.clock,
          onPrepareIncidentRecommendation:
              widget.onPrepareIncidentRecommendation,
          onDeleted: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  void _updateStatus(IncidentStatus? status) {
    final query = _controller.state.query;
    unawaited(
      _controller.updateQuery(
        IncidentQuery(
          searchTerm: query.searchTerm,
          statuses: status == null ? const {} : {status},
          severities: query.severities,
          incidentTypes: query.incidentTypes,
          sortOrder: query.sortOrder,
        ),
      ),
    );
  }

  void _updateSeverity(IncidentSeverity? severity) {
    final query = _controller.state.query;
    unawaited(
      _controller.updateQuery(
        IncidentQuery(
          searchTerm: query.searchTerm,
          statuses: query.statuses,
          severities: severity == null ? const {} : {severity},
          incidentTypes: query.incidentTypes,
          sortOrder: query.sortOrder,
        ),
      ),
    );
  }

  void _updateType(IncidentType? incidentType) {
    final query = _controller.state.query;
    unawaited(
      _controller.updateQuery(
        IncidentQuery(
          searchTerm: query.searchTerm,
          statuses: query.statuses,
          severities: query.severities,
          incidentTypes: incidentType == null ? const {} : {incidentType},
          sortOrder: query.sortOrder,
        ),
      ),
    );
  }

  void _updateSort(IncidentSortOrder sortOrder) {
    final query = _controller.state.query;
    unawaited(
      _controller.updateQuery(
        IncidentQuery(
          searchTerm: query.searchTerm,
          statuses: query.statuses,
          severities: query.severities,
          incidentTypes: query.incidentTypes,
          sortOrder: sortOrder,
        ),
      ),
    );
  }

  void _clearFilters() {
    final sortOrder = _controller.state.query.sortOrder;
    _searchController.clear();
    unawaited(_controller.updateQuery(IncidentQuery(sortOrder: sortOrder)));
  }

  static T? _singleValue<T>(Set<T> values) {
    return values.length == 1 ? values.single : null;
  }
}

class _LocalDraftSection extends StatelessWidget {
  const _LocalDraftSection({
    required this.items,
    required this.onSubmit,
    required this.onDiscard,
  });

  final List<LocalIncidentWorkItem> items;
  final ValueChanged<LocalIncidentWorkItem> onSubmit;
  final ValueChanged<LocalIncidentWorkItem> onDiscard;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Local drafts',
      subtitle: 'Not submitted to Supabase. Staff must review and submit each report explicitly.',
      leading: const Icon(Icons.edit_note_outlined),
      body: Column(
        children: [
          for (final item in items)
            ListTile(
              title: Text(item.incident.title),
              subtitle: Text(
                item.safeErrorMessage == null
                    ? 'Draft only · ${item.syncState.storageValue}'
                    : item.safeErrorMessage!,
              ),
              trailing: Wrap(
                spacing: AppSpacing.xs,
                children: [
                  if (item.syncState != LocalSyncState.conflict)
                    FilledButton(
                      onPressed: () => onSubmit(item),
                      child: const Text('Submit'),
                    ),
                  TextButton(
                    onPressed: () => onDiscard(item),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Incident results',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(
          '$count ${count == 1 ? 'record' : 'records'}',
          key: const ValueKey('incident-result-count'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.selectedStatus, required this.onSelected});

  final IncidentStatus? selectedStatus;
  final ValueChanged<IncidentStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Filter incidents by status',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              key: const ValueKey('incident-status-filter-all'),
              label: const Text('All'),
              selected: selectedStatus == null,
              onSelected: (_) => onSelected(null),
            ),
            for (final status in IncidentStatus.values) ...[
              const SizedBox(width: AppSpacing.xs),
              ChoiceChip(
                key: ValueKey('incident-status-filter-${status.name}'),
                label: Text(status.displayLabel),
                selected: selectedStatus == status,
                onSelected: (_) => onSelected(status),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeverityFilter extends StatelessWidget {
  const _SeverityFilter({
    required this.selectedSeverity,
    required this.onChanged,
  });

  final IncidentSeverity? selectedSeverity;
  final ValueChanged<IncidentSeverity?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<IncidentSeverity?>(
      key: ValueKey('incident-severity-filter-${selectedSeverity?.name}'),
      initialValue: selectedSeverity,
      decoration: const InputDecoration(labelText: 'Severity'),
      isExpanded: true,
      items: [
        const DropdownMenuItem(value: null, child: Text('All severities')),
        for (final severity in IncidentSeverity.values)
          DropdownMenuItem(value: severity, child: Text(severity.displayLabel)),
      ],
      onChanged: onChanged,
    );
  }
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.selectedType, required this.onChanged});

  final IncidentType? selectedType;
  final ValueChanged<IncidentType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<IncidentType?>(
      key: ValueKey('incident-type-filter-${selectedType?.name}'),
      initialValue: selectedType,
      decoration: const InputDecoration(labelText: 'Incident Type'),
      isExpanded: true,
      items: [
        const DropdownMenuItem(value: null, child: Text('All types')),
        for (final type in IncidentType.values)
          DropdownMenuItem(value: type, child: Text(type.displayLabel)),
      ],
      onChanged: onChanged,
    );
  }
}

class _SortFilter extends StatelessWidget {
  const _SortFilter({required this.sortOrder, required this.onChanged});

  final IncidentSortOrder sortOrder;
  final ValueChanged<IncidentSortOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<IncidentSortOrder>(
      key: ValueKey('incident-sort-${sortOrder.name}'),
      initialValue: sortOrder,
      decoration: const InputDecoration(labelText: 'Sort By'),
      isExpanded: true,
      items: [
        for (final order in IncidentSortOrder.values)
          DropdownMenuItem(value: order, child: Text(order.displayLabel)),
      ],
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}
