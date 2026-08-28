import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../controllers/deployment_controller.dart';
import '../data/dto/local_deployment_record.dart';
import '../models/deployment_status.dart';
import '../models/service_deployment.dart';
import '../widgets/deployment_card.dart';
import '../widgets/deployment_data_notice.dart';
import '../widgets/local_deployment_work_card.dart';

class DeploymentListScreen extends StatefulWidget {
  const DeploymentListScreen({
    required this.controller,
    this.onCreateDeployment,
    this.onOpenDeployment,
    this.onEditLocalWork,
    this.onPublishLocalWork,
    this.onDiscardLocalWork,
    super.key,
  });

  final DeploymentController controller;
  final VoidCallback? onCreateDeployment;
  final ValueChanged<ServiceDeployment>? onOpenDeployment;
  final ValueChanged<LocalDeploymentRecord>? onEditLocalWork;
  final ValueChanged<LocalDeploymentRecord>? onPublishLocalWork;
  final ValueChanged<LocalDeploymentRecord>? onDiscardLocalWork;

  @override
  State<DeploymentListScreen> createState() => _DeploymentListScreenState();
}

class _DeploymentListScreenState extends State<DeploymentListScreen> {
  final TextEditingController _searchController = TextEditingController();
  DeploymentStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.loadDeployments();
      }
    });
  }

  @override
  void didUpdateWidget(covariant DeploymentListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    _searchController.dispose();
    // The controller is supplied by the parent and remains parent-owned.
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
      title: 'Service Deployments',
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('new-deployment-button'),
        onPressed: widget.onCreateDeployment,
        icon: const Icon(Icons.add),
        label: const Text('New Deployment'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (widget.controller.isLoading &&
        widget.controller.deployments.isEmpty &&
        widget.controller.localWorkItems.isEmpty) {
      return const AppLoadingIndicator(message: 'Loading service deployments');
    }

    final errorMessage = widget.controller.errorMessage;
    if (errorMessage != null && widget.controller.localWorkItems.isEmpty) {
      return AppErrorState(
        title: 'Unable to load deployments',
        message: errorMessage,
        actionLabel: 'Retry',
        onAction: widget.controller.loadDeployments,
      );
    }

    final deployments = widget.controller.deployments;
    final scheduledCount = deployments
        .where((deployment) => deployment.status == DeploymentStatus.scheduled)
        .length;
    final activeCount = deployments
        .where((deployment) => deployment.status == DeploymentStatus.active)
        .length;

    if (deployments.isEmpty) {
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
                DeploymentDataNotice(
                  isPersistent: widget.controller.capabilities.isPersistent,
                  provenance: widget.controller.listProvenance,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _InlineLoadError(
                    message: errorMessage,
                    onRetry: widget.controller.loadDeployments,
                  ),
                ],
                if (widget.controller.localWorkItems.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildLocalWorkSection(),
                ],
                const SizedBox(height: AppSpacing.md),
                _DeploymentSummary(
                  totalCount: deployments.length,
                  scheduledCount: scheduledCount,
                  activeCount: activeCount,
                ),
              ],
            ),
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              title: 'No service deployments yet',
              message:
                  'Create a draft deployment when additional or replacement '
                  'service is required.',
              icon: Icons.route_outlined,
            ),
          ),
        ],
      );
    }

    final filteredDeployments = _filterAndSort(deployments);

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
              DeploymentDataNotice(
                isPersistent: widget.controller.capabilities.isPersistent,
                provenance: widget.controller.listProvenance,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _InlineLoadError(
                  message: errorMessage,
                  onRetry: widget.controller.loadDeployments,
                ),
              ],
              if (widget.controller.localWorkItems.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _buildLocalWorkSection(),
              ],
              const SizedBox(height: AppSpacing.md),
              _DeploymentSummary(
                totalCount: deployments.length,
                scheduledCount: scheduledCount,
                activeCount: activeCount,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey('deployment-search-field'),
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search deployments',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _StatusFilter(
                selectedStatus: _selectedStatus,
                onSelected: (status) {
                  setState(() {
                    _selectedStatus = status;
                  });
                },
              ),
              if (_filtersAreActive)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const ValueKey('clear-deployment-filters'),
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Clear filters'),
                  ),
                )
              else
                const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
        if (filteredDeployments.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              title: 'No deployments match your filters',
              message: 'Adjust or clear the active search and status filters.',
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
              itemCount: filteredDeployments.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final deployment = filteredDeployments[index];
                return DeploymentCard(
                  key: ValueKey('deployment-card-${deployment.deploymentId}'),
                  deployment: deployment,
                  onTap: widget.onOpenDeployment == null
                      ? null
                      : () => widget.onOpenDeployment!(deployment),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLocalWorkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Unpublished local work',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Stored only on this device until Supabase confirms publication.',
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final record in widget.controller.localWorkItems) ...[
          LocalDeploymentWorkCard(
            key: ValueKey('local-work-${record.localId}'),
            record: record,
            isPublishing: widget.controller.isPublishingLocalDraft(
              record.localId,
            ),
            onEdit: widget.onEditLocalWork == null
                ? null
                : () => widget.onEditLocalWork!(record),
            onPublish: widget.onPublishLocalWork == null
                ? null
                : () => widget.onPublishLocalWork!(record),
            onDiscard: widget.onDiscardLocalWork == null
                ? null
                : () => widget.onDiscardLocalWork!(record),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  bool get _filtersAreActive =>
      _searchController.text.trim().isNotEmpty || _selectedStatus != null;

  List<ServiceDeployment> _filterAndSort(List<ServiceDeployment> deployments) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = deployments
        .where((deployment) {
          final matchesStatus =
              _selectedStatus == null || deployment.status == _selectedStatus;
          if (!matchesStatus) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }

          final searchableValues = <String>[
            deployment.deploymentId,
            deployment.routeId,
            deployment.routeName,
            ...deployment.vehicleIds,
            ?deployment.incidentId,
            ?deployment.sourceRecommendationId,
          ];
          return searchableValues.any(
            (value) => value.toLowerCase().contains(query),
          );
        })
        .toList(growable: false);

    return [...filtered]
      ..sort((first, second) => first.startTime.compareTo(second.startTime));
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedStatus = null;
    });
  }
}

class _InlineLoadError extends StatelessWidget {
  const _InlineLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _DeploymentSummary extends StatelessWidget {
  const _DeploymentSummary({
    required this.totalCount,
    required this.scheduledCount,
    required this.activeCount,
  });

  final int totalCount;
  final int scheduledCount;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryItem(
            label: 'Total',
            count: totalCount,
            valueKey: const ValueKey('deployment-total-count'),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _SummaryItem(
            label: 'Scheduled',
            count: scheduledCount,
            valueKey: const ValueKey('deployment-scheduled-count'),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _SummaryItem(
            label: 'Active',
            count: activeCount,
            valueKey: const ValueKey('deployment-active-count'),
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.count,
    required this.valueKey,
  });

  final String label;
  final int count;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: [
            Text(
              '$count',
              key: valueKey,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.selectedStatus, required this.onSelected});

  final DeploymentStatus? selectedStatus;
  final ValueChanged<DeploymentStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Filter deployments by status',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              key: const ValueKey('status-filter-all'),
              label: const Text('All'),
              selected: selectedStatus == null,
              onSelected: (_) => onSelected(null),
            ),
            for (final status in DeploymentStatus.values) ...[
              const SizedBox(width: AppSpacing.xs),
              ChoiceChip(
                key: ValueKey('status-filter-${status.name}'),
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
