import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../controllers/work_orders_controller.dart';
import '../models/work_order.dart';
import '../widgets/work_order_priority_chip.dart';
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
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

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
                          WorkOrderPriorityChip(priority: workOrder.priority),
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
                            label: 'Completed at',
                            value: _formatLifecycle(workOrder.completedAt),
                          ),
                          _DetailRow(
                            label: 'Cancelled at',
                            value: _formatLifecycle(workOrder.cancelledAt),
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
                    if (!workOrder.isTerminal)
                      _buildActions(workOrder)
                    else
                      AppSectionCard(
                        title: 'Work order closed',
                        subtitle:
                            'This ${workOrder.status.label.toLowerCase()} '
                            'record is retained and cannot be edited or '
                            'transitioned.',
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

  Widget _buildActions(WorkOrder workOrder) {
    final primary = switch (workOrder.status) {
      WorkOrderStatus.draft => FilledButton.icon(
        key: const Key('openWorkOrderAction'),
        onPressed: _isWorking ? null : () => _confirmOpen(workOrder),
        icon: const Icon(Icons.mark_email_read_outlined),
        label: const Text('Open work order'),
      ),
      WorkOrderStatus.open => FilledButton.icon(
        key: const Key('assignWorkOrderAction'),
        onPressed: _isWorking ? null : () => _assign(workOrder),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Assign responsible staff'),
      ),
      WorkOrderStatus.assigned => FilledButton.icon(
        key: const Key('startWorkAction'),
        onPressed: _isWorking ? null : () => _confirmStart(workOrder),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Start work'),
      ),
      WorkOrderStatus.inProgress => FilledButton.icon(
        key: const Key('completeWorkAction'),
        onPressed: _isWorking ? null : () => _confirmComplete(workOrder),
        icon: const Icon(Icons.check_circle_outline_rounded),
        label: const Text('Complete work order'),
      ),
      WorkOrderStatus.completed ||
      WorkOrderStatus.cancelled => const SizedBox.shrink(),
    };
    return AppSectionCard(
      title: 'Staff actions',
      subtitle: 'Review and explicitly confirm each operational action.',
      body: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          primary,
          OutlinedButton.icon(
            key: const Key('cancelWorkOrderAction'),
            onPressed: _isWorking ? null : () => _confirmCancel(workOrder),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel work order'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmOpen(WorkOrder workOrder) async {
    final confirmed = await _confirm(
      title: 'Open work order?',
      message:
          'Open ${workOrder.workOrderId} for ${workOrder.vehicleId}? Staff '
          'remain responsible for this decision.',
      confirmLabel: 'Confirm open',
    );
    if (confirmed) {
      await _runAction(
        () => widget.controller.openWorkOrder(workOrder.workOrderId),
      );
    }
  }

  Future<void> _assign(WorkOrder workOrder) async {
    final assignedTo = await _assignmentDialog(workOrder);
    if (assignedTo == null) return;
    await _runAction(
      () => widget.controller.assignWorkOrder(
        workOrder.workOrderId,
        assignedTo: assignedTo,
      ),
    );
  }

  Future<void> _confirmStart(WorkOrder workOrder) async {
    final confirmed = await _confirm(
      title: 'Start maintenance work?',
      message:
          'Start ${workOrder.workOrderId} for ${workOrder.vehicleId}? Staff '
          'must confirm that work is beginning.',
      confirmLabel: 'Confirm start',
    );
    if (confirmed) {
      await _runAction(
        () => widget.controller.startWork(workOrder.workOrderId),
      );
    }
  }

  Future<void> _confirmComplete(WorkOrder workOrder) async {
    final confirmed = await _confirm(
      title: 'Complete work order?',
      message:
          'Mark ${workOrder.workOrderId} as completed? This is a terminal '
          'staff decision and cannot be reversed.',
      confirmLabel: 'Confirm completion',
    );
    if (confirmed) {
      await _runAction(
        () => widget.controller.completeWork(workOrder.workOrderId),
      );
    }
  }

  Future<void> _confirmCancel(WorkOrder workOrder) async {
    final confirmed = await _confirm(
      title: 'Cancel work order?',
      message:
          'Cancel ${workOrder.workOrderId}? This is a terminal staff decision '
          'and the record will be retained.',
      confirmLabel: 'Confirm cancellation',
    );
    if (confirmed) {
      await _runAction(
        () => widget.controller.cancelWorkOrder(workOrder.workOrderId),
      );
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Go back'),
              ),
              FilledButton(
                key: const Key('confirmWorkOrderAction'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _assignmentDialog(WorkOrder workOrder) async {
    return showDialog<String>(
      context: context,
      builder: (context) => _AssignmentDialog(workOrder: workOrder),
    );
  }

  Future<void> _runAction(Future<WorkOrder> Function() action) async {
    setState(() => _isWorking = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work order updated by staff.')),
      );
    } on WorkOrderValidationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  String _format(DateTime? value) {
    if (value == null) return 'Not scheduled';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  String _formatLifecycle(DateTime? value) =>
      value == null ? 'Not recorded' : _format(value);
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog({required this.workOrder});

  final WorkOrder workOrder;

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  final _textController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign responsible staff'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assign ${widget.workOrder.workOrderId} only after staff '
              'review. AI does not assign personnel automatically.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('assignedToField'),
              controller: _textController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Responsible staff',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Go back'),
        ),
        FilledButton(
          key: const Key('confirmAssignmentAction'),
          onPressed: () {
            final value = _textController.text.trim();
            if (value.isEmpty) {
              setState(() => _error = 'Responsible staff is required.');
              return;
            }
            Navigator.of(context).pop(value);
          },
          child: const Text('Confirm assignment'),
        ),
      ],
    );
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
