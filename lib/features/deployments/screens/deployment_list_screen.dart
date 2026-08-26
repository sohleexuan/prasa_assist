import 'package:flutter/material.dart';

import '../controllers/deployment_controller.dart';
import '../models/deployment_status.dart';
import '../models/service_deployment.dart';
import '../widgets/deployment_card.dart';

class DeploymentListScreen extends StatefulWidget {
  const DeploymentListScreen({
    required this.controller,
    this.onCreateDeployment,
    this.onOpenDeployment,
    super.key,
  });

  final DeploymentController controller;
  final VoidCallback? onCreateDeployment;
  final ValueChanged<ServiceDeployment>? onOpenDeployment;

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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17203A),
        foregroundColor: Colors.white,
        title: const Text(
          'Service Deployments',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('new-deployment-button'),
        onPressed: widget.onCreateDeployment,
        backgroundColor: const Color(0xFF6D4AFF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Deployment'),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (widget.controller.isLoading) {
      return Center(
        child: Semantics(
          label: 'Loading service deployments',
          child: CircularProgressIndicator(),
        ),
      );
    }

    final errorMessage = widget.controller.errorMessage;
    if (errorMessage != null) {
      return _ErrorState(
        message: errorMessage,
        onRetry: widget.controller.loadDeployments,
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverList.list(
              children: [
                const _PrototypeNotice(),
                const SizedBox(height: 16),
                _DeploymentSummary(
                  totalCount: deployments.length,
                  scheduledCount: scheduledCount,
                  activeCount: activeCount,
                ),
              ],
            ),
          ),
          const SliverFillRemaining(hasScrollBody: false, child: _EmptyState()),
        ],
      );
    }

    final filteredDeployments = _filterAndSort(deployments);

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverList.list(
                  children: [
                    const _PrototypeNotice(),
                    const SizedBox(height: 16),
                    _DeploymentSummary(
                      totalCount: deployments.length,
                      scheduledCount: scheduledCount,
                      activeCount: activeCount,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('deployment-search-field'),
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search deployments',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDE1EB),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StatusFilter(
                      selectedStatus: _selectedStatus,
                      onSelected: (status) {
                        setState(() {
                          _selectedStatus = status;
                        });
                      },
                    ),
                    if (_filtersAreActive) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: const ValueKey('clear-deployment-filters'),
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: const Text('Clear filters'),
                        ),
                      ),
                    ] else
                      const SizedBox(height: 8),
                  ],
                ),
              ),
              if (filteredDeployments.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NoFilterResultsState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverList.separated(
                    itemCount: filteredDeployments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final deployment = filteredDeployments[index];
                      return DeploymentCard(
                        key: ValueKey(
                          'deployment-card-${deployment.deploymentId}',
                        ),
                        deployment: deployment,
                        onTap: widget.onOpenDeployment == null
                            ? null
                            : () => widget.onOpenDeployment!(deployment),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
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

class _PrototypeNotice extends StatelessWidget {
  const _PrototypeNotice();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Prototype data, not live operations',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF1EFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD8D0FF)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.science_outlined, size: 20, color: Color(0xFF5636C7)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Prototype data — not live operations',
                  style: TextStyle(
                    color: Color(0xFF402596),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
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
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryItem(
            label: 'Scheduled',
            count: scheduledCount,
            valueKey: const ValueKey('deployment-scheduled-count'),
          ),
        ),
        const SizedBox(width: 8),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE1EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          children: [
            Text(
              '$count',
              key: valueKey,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF17203A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: const Color(0xFF5F667A)),
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
              const SizedBox(width: 8),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined, size: 48, color: Color(0xFF6D4AFF)),
            SizedBox(height: 12),
            Text(
              'No service deployments yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'Create a draft deployment when additional or replacement '
              'service is required.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoFilterResultsState extends StatelessWidget {
  const _NoFilterResultsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 112),
        child: Text(
          'No deployments match your filters',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF5F667A),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFF991B1B)),
            const SizedBox(height: 12),
            const Text(
              'Unable to load deployments',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('retry-deployments-button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
