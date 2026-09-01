import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../controllers/work_orders_controller.dart';
import '../models/work_order.dart';
import '../repositories/work_order_hybrid_operations.dart';
import '../widgets/work_order_card.dart';
import 'work_order_detail_page.dart';
import 'work_order_form_page.dart';

class WorkOrderListPage extends StatefulWidget {
  const WorkOrderListPage({required this.controller, super.key});

  factory WorkOrderListPage.hybrid({
    required WorkOrderHybridOperations operations,
    String localDraftCreatedByLabel = 'Current operations staff',
    Key? key,
  }) => WorkOrderListPage(
    key: key,
    controller: WorkOrdersController.hybrid(
      operations,
      localDraftCreatedByLabel: localDraftCreatedByLabel,
    ),
  );

  final WorkOrdersController controller;

  @override
  State<WorkOrderListPage> createState() => _WorkOrderListPageState();
}

class _WorkOrderListPageState extends State<WorkOrderListPage> {
  late final WorkOrdersController _controller;
  late final bool _ownsController;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _ownsController = false;
    _controller = widget.controller;
    _searchController = TextEditingController(text: _controller.searchQuery);
    _controller.addListener(_refresh);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _searchController.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Maintenance Work Orders',
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('createWorkOrderButton'),
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: AppRadius.small,
            ),
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _sourceMessage(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                if (_controller.errorMessage != null &&
                    _controller.workOrders.isNotEmpty)
                  TextButton(
                    key: const Key('retryConfirmedWorkOrders'),
                    onPressed: _controller.retryConfirmedRecords,
                    child: const Text('Retry confirmed'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final search = TextField(
                  key: const Key('workOrderSearchField'),
                  controller: _searchController,
                  onChanged: _controller.setSearchQuery,
                  decoration: InputDecoration(
                    labelText: 'Search work orders',
                    hintText: 'ID, vehicle, task, description, or staff',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _controller.searchQuery.trim().isEmpty
                        ? null
                        : IconButton(
                            key: const Key('clearWorkOrderSearch'),
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              _controller.setSearchQuery('');
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                  ),
                );
                final filter = DropdownButtonFormField<WorkOrderStatus?>(
                  key: ValueKey(
                    'workOrderStatusFilter-${_controller.selectedStatus?.name ?? 'all'}',
                  ),
                  initialValue: _controller.selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    for (final status in WorkOrderStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: _controller.setStatusFilter,
                );
                if (constraints.maxWidth < 560) {
                  return Column(
                    children: [
                      search,
                      const SizedBox(height: AppSpacing.sm),
                      filter,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: search),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: filter),
                  ],
                );
              },
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_controller.isLoading) {
      return const AppLoadingIndicator(message: 'Loading work orders');
    }
    if (_controller.errorMessage != null && _controller.workOrders.isEmpty) {
      return AppErrorState(
        title: 'Unable to load work orders',
        message: _controller.errorMessage!,
        actionLabel: 'Retry',
        onAction: _controller.load,
      );
    }
    if (_controller.workOrders.isEmpty) {
      return AppEmptyState(
        title: 'No work orders',
        message: 'Create a draft for staff review, then publish it explicitly when ready.',
        actionLabel: 'Create work order',
        onAction: _create,
      );
    }
    if (_controller.visibleWorkOrders.isEmpty) {
      return AppEmptyState(
        title: 'No matching work orders',
        message: 'No work orders match the current search and status.',
        actionLabel: 'Clear filters',
        onAction: () {
          _searchController.clear();
          _controller.clearFilters();
        },
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: _controller.visibleWorkOrders.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final workOrder = _controller.visibleWorkOrders[index];
            return WorkOrderCard(
              workOrder: workOrder,
              onTap: () => _openDetails(workOrder.workOrderId),
            );
          },
        ),
      ),
    );
  }

  Future<void> _create() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkOrderFormPage(controller: _controller),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local work-order draft saved.')),
      );
    }
  }

  String _sourceMessage() {
    if (_controller.errorMessage != null && _controller.workOrders.isNotEmpty) {
      return '${_controller.errorMessage} Local drafts remain on this device until staff explicitly publish them. AI recommends. Staff decides.';
    }
    final provenance = _controller.readProvenance;
    if (provenance == null) {
      return 'Draft records stay on this device until staff explicitly publish them. AI recommends. Staff decides.';
    }
    final state = provenance.isCached
        ? 'Showing verified cached confirmed records while remote access is unavailable.'
        : 'Showing confirmed shared work orders from the remote service.';
    return '$state Local drafts remain offline until staff explicitly publish them. AI recommends. Staff decides.';
  }

  Future<void> _openDetails(String workOrderId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WorkOrderDetailPage(
          controller: _controller,
          workOrderId: workOrderId,
        ),
      ),
    );
  }
}
