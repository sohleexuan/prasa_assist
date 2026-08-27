import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../controllers/work_orders_controller.dart';
import '../models/work_order.dart';
import '../widgets/work_order_status_chip.dart';
import 'work_order_form_page.dart';

class WorkOrderDetailPage extends StatefulWidget {
  const WorkOrderDetailPage({
    required this.controller,
    required this.workOrderId,
    super.key,
  });

  final WorkOrdersController controller;
  final String workOrderId;

  @override
  State<WorkOrderDetailPage> createState() => _WorkOrderDetailPageState();
}

class _WorkOrderDetailPageState extends State<WorkOrderDetailPage> {
  @override
  Widget build(BuildContext context) {
    final workOrder = widget.controller.findById(widget.workOrderId);
    return AppPageScaffold(
      title: 'Work order details',
      actions: workOrder == null || workOrder.isTerminal
          ? null
          : [
              IconButton(
                tooltip: 'Edit work order',
                onPressed: () => _edit(workOrder),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
      body: workOrder == null
          ? const AppErrorState(
              title: 'Work order unavailable',
              message: 'This local demonstration record could not be found.',
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text(
                      'Local demonstration data — not live or real-time',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppSectionCard(
                      title: workOrder.taskType,
                      subtitle: workOrder.description,
                      body: Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          WorkOrderStatusChip(status: workOrder.status),
                          Chip(label: Text(workOrder.priority.label)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppSectionCard(
                      title: 'Work-order information',
                      body: Column(
                        children: [
                          _DetailRow(
                            label: 'Work order ID',
                            value: workOrder.workOrderId,
                          ),
                          _DetailRow(
                            label: 'Vehicle ID',
                            value: workOrder.vehicleId,
                          ),
                          _DetailRow(
                            label: 'Assigned to',
                            value: workOrder.assignedTo ?? 'Not assigned',
                          ),
                          _DetailRow(
                            label: 'Scheduled start',
                            value: _format(workOrder.scheduledStart),
                          ),
                          _DetailRow(
                            label: 'Scheduled end',
                            value: _format(workOrder.scheduledEnd),
                          ),
                          _DetailRow(
                            label: 'Incident ID',
                            value: workOrder.incidentId ?? 'Not linked',
                          ),
                          _DetailRow(
                            label: 'Recommendation ID',
                            value: workOrder.recommendationId ?? 'Not linked',
                          ),
                          _DetailRow(
                            label: 'Created by',
                            value: workOrder.createdBy,
                          ),
                          _DetailRow(
                            label: 'Created at',
                            value: _format(workOrder.createdAt),
                          ),
                          _DetailRow(
                            label: 'Updated at',
                            value: _format(workOrder.updatedAt),
                          ),
                          _DetailRow(
                            label: 'Notes',
                            value: workOrder.notes ?? 'None',
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'AI recommends. Staff decides. Staff must review and '
                      'confirm operational actions.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _edit(WorkOrder workOrder) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkOrderFormPage(
          controller: widget.controller,
          workOrder: workOrder,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  String _format(DateTime? value) {
    if (value == null) return 'Not scheduled';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(flex: 3, child: Text(value, textAlign: TextAlign.end)),
            ],
          ),
        ),
        if (showDivider) const Divider(),
      ],
    );
  }
}
