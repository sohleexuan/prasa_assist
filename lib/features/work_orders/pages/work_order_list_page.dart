import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../controllers/work_orders_controller.dart';
import '../data/in_memory_work_order_repository.dart';
import '../models/work_order.dart';
import '../widgets/work_order_card.dart';
import 'work_order_detail_page.dart';
import 'work_order_form_page.dart';

class WorkOrderListPage extends StatefulWidget {
  const WorkOrderListPage({this.controller, super.key});

  final WorkOrdersController? controller;

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
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        WorkOrdersController(InMemoryWorkOrderRepository());
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
            child: Text(
              'Local demonstration data only — not government, live, or '
              'real-time data. AI recommends. Staff decides.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
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
      return const AppLoadingIndicator(
        message: 'Loading local demonstration work orders',
      );
    }
    if (_controller.errorMessage != null) {
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
        message: 'Create a local draft work order for staff review.',
        actionLabel: 'Create work order',
        onAction: _create,
      );
    }
    if (_controller.visibleWorkOrders.isEmpty) {
      return AppEmptyState(
        title: 'No matching work orders',
        message: 'No local records match the current search and status.',
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
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkOrderFormPage(controller: _controller),
      ),
    );
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
