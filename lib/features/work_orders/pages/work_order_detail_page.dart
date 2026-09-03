import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/time/malaysia_time.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../../shared/staff/staff_directory_repository.dart';
import '../../../shared/staff/staff_profile.dart';
import '../controllers/work_orders_controller.dart';
import '../models/work_order.dart';
import '../repositories/work_order_data_exception.dart';
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
  late String _workOrderId;

  @override
  void initState() {
    super.initState();
    _workOrderId = widget.workOrderId;
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
    final workOrder = widget.controller.findById(_workOrderId);
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
              message: 'This work-order record could not be found.',
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text(
                      _recordStateMessage(workOrder),
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
                            value: widget.controller.assignmentLabelFor(
                              workOrder,
                            ),
                            selectable: true,
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
                            label: 'Created by',
                            value: widget.controller.createdByLabelFor(
                              workOrder,
                            ),
                            selectable: true,
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
                    AppSectionCard(
                      title: 'Linked records',
                      body: Column(
                        children: [
                          _LinkedRecordRow(
                            label: 'Incident ID',
                            value: workOrder.incidentId,
                          ),
                          _LinkedRecordRow(
                            label: 'Recommendation ID',
                            value: workOrder.recommendationId,
                          ),
                          _LinkedRecordRow(
                            label: 'Route ID',
                            value: workOrder.routeId,
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
    if (widget.controller.isLocalDraft(workOrder.workOrderId)) {
      final legacyBlock = workOrder.hasLegacyScheduleEquality
          ? 'Scheduled end must be later than scheduled start before this '
                'legacy draft can be published.'
          : null;
      return AppSectionCard(
        title: 'Draft review',
        subtitle: legacyBlock ?? 'Saving keeps this draft on the device. Publish only after staff review confirms that a shared work order should be created.',
        body: FilledButton.icon(
          key: const Key('publishWorkOrderAction'),
          onPressed: _isWorking || legacyBlock != null
              ? null
              : () => _confirmPublish(workOrder),
          icon: const Icon(Icons.publish_outlined),
          label: const Text('Publish confirmed work order'),
        ),
      );
    }
    final transitionBlockReason = workOrder.status == WorkOrderStatus.draft
        ? widget.controller.transitionBlockReason(
            workOrder,
            WorkOrderStatus.open,
          )
        : null;
    final assignmentBlockReason = workOrder.status == WorkOrderStatus.open
        ? widget.controller.assignmentUnavailableReason
        : null;
    final primary = switch (workOrder.status) {
      WorkOrderStatus.draft => FilledButton.icon(
        key: const Key('openWorkOrderAction'),
        onPressed: _isWorking || transitionBlockReason != null
            ? null
            : () => _confirmOpen(workOrder),
        icon: const Icon(Icons.mark_email_read_outlined),
        label: const Text('Open work order'),
      ),
      WorkOrderStatus.open => FilledButton.icon(
        key: const Key('assignWorkOrderAction'),
        onPressed: _isWorking || assignmentBlockReason != null
            ? null
            : () => _assign(workOrder),
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
      subtitle:
          transitionBlockReason ??
          assignmentBlockReason ??
          'Review and explicitly confirm each operational action.',
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

  Future<void> _confirmPublish(WorkOrder workOrder) async {
    final confirmed = await _confirm(
      title: 'Publish confirmed work order?',
      message:
          'Publish ${workOrder.workOrderId} as a shared confirmed work order? Staff must review and explicitly confirm this action. If remote confirmation is unavailable, this draft remains local for later review.',
      confirmLabel: 'Confirm publication',
    );
    if (confirmed) {
      final published = await _runAction(
        () => widget.controller.publishLocalDraft(workOrder.workOrderId),
        successMessage: 'Work order confirmed by the remote service.',
      );
      if (published != null && mounted) {
        setState(() => _workOrderId = published.workOrderId);
      }
    }
  }

  Future<void> _assign(WorkOrder workOrder) async {
    final assignee = await _assignmentDialog(workOrder);
    if (!mounted || assignee == null) return;
    await _runAction(
      () => widget.controller.assignWorkOrderToStaff(
        workOrder.workOrderId,
        assignee: assignee,
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

  Future<StaffProfile?> _assignmentDialog(WorkOrder workOrder) async {
    return showDialog<StaffProfile>(
      context: context,
      builder: (context) => _AssignmentDialog(
        workOrder: workOrder,
        controller: widget.controller,
      ),
    );
  }

  Future<WorkOrder?> _runAction(
    Future<WorkOrder> Function() action, {
    String successMessage = 'Work order updated by staff.',
  }) async {
    setState(() => _isWorking = true);
    try {
      final updated = await action();
      if (!mounted) return null;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
      return updated;
    } on WorkOrderValidationException catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } on StateError catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } on WorkOrderDataException catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
    return null;
  }

  String _format(DateTime? value) {
    if (value == null) return 'Not scheduled';
    return MalaysiaTime.formatDateTime(value);
  }

  String _formatLifecycle(DateTime? value) =>
      value == null ? 'Not recorded' : _format(value);

  String _recordStateMessage(WorkOrder workOrder) {
    if (widget.controller.isLocalDraft(workOrder.workOrderId)) {
      return 'Local draft — not yet a confirmed shared work order';
    }
    if (widget.controller.readProvenance?.isCached ?? false) {
      return 'Verified cached confirmed record — remote service currently unavailable';
    }
    return 'Confirmed shared work order';
  }
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog({required this.workOrder, required this.controller});

  final WorkOrder workOrder;
  final WorkOrdersController controller;

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  StaffDirectorySnapshot? _snapshot;
  StaffProfile? _selected;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.controller.assignableStaffDirectory;
    if (_snapshot == null) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await widget.controller.retryAssignableStaffDirectory();
    if (!mounted) return;
    setState(() {
      _snapshot = widget.controller.assignableStaffDirectory;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign responsible staff'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign ${widget.workOrder.workOrderId} only after staff '
                'review. AI does not assign personnel automatically.',
              ),
              const SizedBox(height: AppSpacing.md),
              ..._directoryContent(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Go back'),
        ),
        FilledButton(
          key: const Key('confirmAssignmentAction'),
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: const Text('Confirm assignment'),
        ),
      ],
    );
  }

  List<Widget> _directoryContent() {
    if (_loading) {
      return const [
        Center(
          child: CircularProgressIndicator(key: Key('staffDirectoryLoading')),
        ),
      ];
    }
    final error = widget.controller.assignableStaffDirectoryError;
    if (_snapshot == null && error != null) {
      return [
        Text(error, key: const Key('staffDirectoryError')),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const Key('retryStaffDirectory'),
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ];
    }
    final snapshot = _snapshot;
    final staff = snapshot?.assignableStaff ?? const <StaffProfile>[];
    if (staff.isEmpty) {
      return [
        const Text(
          'No active maintenance staff are available for assignment.',
          key: Key('staffDirectoryEmpty'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const Key('retryStaffDirectory'),
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ];
    }
    return [
      if (snapshot!.isCached)
        Container(
          key: const Key('staffDirectoryCachedNotice'),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Text(
            snapshot.isStale
                ? 'Offline cached directory — may be out of date. The server will revalidate the assignment.'
                : 'Offline cached directory. The server will revalidate the assignment.',
          ),
        ),
      if (snapshot.isCached) const SizedBox(height: AppSpacing.sm),
      for (final profile in staff)
        ListTile(
          key: ValueKey('staff-${profile.staffCode}'),
          selected: _selected == profile,
          leading: Icon(
            _selected == profile
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          onTap: () => setState(() => _selected = profile),
          title: Text(profile.displayLabel),
          subtitle: const Text('Maintenance staff'),
          contentPadding: EdgeInsets.zero,
        ),
    ];
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool showDivider;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final valueWidget = selectable
                  ? SelectableText(value)
                  : Text(value, textAlign: TextAlign.end);
              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    valueWidget,
                  ],
                );
              }
              return Row(
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
                  Expanded(flex: 3, child: valueWidget),
                ],
              );
            },
          ),
        ),
        if (showDivider) const Divider(),
      ],
    );
  }
}

class _LinkedRecordRow extends StatelessWidget {
  const _LinkedRecordRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final valueWidget = SelectableText(value ?? 'Not linked');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                valueWidget,
              ],
            );
          }
          return Row(
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
              Expanded(flex: 3, child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}
