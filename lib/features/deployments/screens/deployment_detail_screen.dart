import 'package:flutter/material.dart';

import '../controllers/deployment_controller.dart';
import '../models/deployment_status.dart';
import '../models/service_deployment.dart';
import '../widgets/deployment_status_chip.dart';
import '../widgets/deployment_workflow_indicator.dart';

class DeploymentDetailScreen extends StatefulWidget {
  const DeploymentDetailScreen({
    required this.controller,
    required this.deploymentId,
    this.onEditDeployment,
    this.onStatusChanged,
    this.onDeleted,
    this.onBack,
    this.clock,
    super.key,
  });

  final DeploymentController controller;
  final String deploymentId;
  final ValueChanged<ServiceDeployment>? onEditDeployment;
  final ValueChanged<ServiceDeployment>? onStatusChanged;
  final VoidCallback? onDeleted;
  final VoidCallback? onBack;
  final DateTime Function()? clock;

  @override
  State<DeploymentDetailScreen> createState() => _DeploymentDetailScreenState();
}

class _DeploymentDetailScreenState extends State<DeploymentDetailScreen> {
  ServiceDeployment? _deployment;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isNotFound = false;
  bool _isDeleted = false;
  String? _loadError;
  String? _operationError;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDeployment();
      }
    });
  }

  @override
  void didUpdateWidget(covariant DeploymentDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.deploymentId != widget.deploymentId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadDeployment();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF17203A),
        foregroundColor: Colors.white,
        leading: widget.onBack == null
            ? null
            : IconButton(
                key: const ValueKey('back-from-deployment-button'),
                onPressed: _isSubmitting ? null : widget.onBack,
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
              ),
        title: const Text(
          'Deployment Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Semantics(
          label: 'Loading deployment details',
          child: const CircularProgressIndicator(),
        ),
      );
    }
    if (_loadError != null) {
      return _LoadErrorState(message: _loadError!, onRetry: _loadDeployment);
    }
    if (_isNotFound) {
      return _NotFoundState(
        deploymentId: widget.deploymentId,
        onRetry: _loadDeployment,
      );
    }
    if (_isDeleted) {
      return const _DeletedState();
    }

    final deployment = _deployment;
    if (deployment == null) {
      return _NotFoundState(
        deploymentId: widget.deploymentId,
        onRetry: _loadDeployment,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PrototypeNotice(),
          if (_isSubmitting) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              key: ValueKey('deployment-operation-progress'),
            ),
          ],
          if (_operationError != null) ...[
            const SizedBox(height: 12),
            _OperationError(message: _operationError!),
          ],
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Status and workflow',
            icon: Icons.account_tree_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      deployment.deploymentId,
                      key: const ValueKey('detail-deployment-id'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF17203A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    DeploymentStatusChip(status: deployment.status),
                  ],
                ),
                const SizedBox(height: 18),
                DeploymentWorkflowIndicator(currentStatus: deployment.status),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Route and vehicles',
            icon: Icons.route_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DetailItem(label: 'Route name', value: deployment.routeName),
                _DetailItem(label: 'Route ID', value: deployment.routeId),
                _DetailItem(
                  label: 'Selected vehicles',
                  value:
                      '${deployment.vehicleCount} '
                      '${deployment.vehicleCount == 1 ? 'vehicle' : 'vehicles'}',
                ),
                const SizedBox(height: 4),
                for (final vehicleId in deployment.vehicleIds)
                  _VehicleItem(vehicleId: vehicleId),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Service window',
            icon: Icons.schedule_outlined,
            child: Column(
              children: [
                _DetailItem(
                  label: 'Start',
                  value: _formatDateTime(deployment.startTime),
                ),
                _DetailItem(
                  label: 'End',
                  value: _formatDateTime(deployment.endTime),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Operational purpose',
            icon: Icons.description_outlined,
            child: Text(
              deployment.purpose,
              key: const ValueKey('detail-purpose'),
            ),
          ),
          if (deployment.incidentId != null ||
              deployment.sourceRecommendationId != null) ...[
            const SizedBox(height: 12),
            _DetailSection(
              key: const ValueKey('linked-records-section'),
              title: 'Linked records',
              icon: Icons.link_outlined,
              child: Column(
                children: [
                  if (deployment.incidentId case final incidentId?)
                    _DetailItem(label: 'Incident ID', value: incidentId),
                  if (deployment.sourceRecommendationId
                      case final recommendationId?)
                    _DetailItem(
                      label: 'Recommendation ID',
                      value: recommendationId,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Audit information',
            icon: Icons.history_outlined,
            child: Column(
              children: [
                _DetailItem(label: 'Created by', value: deployment.createdBy),
                _DetailItem(
                  label: 'Created at',
                  value: _formatDateTime(deployment.createdAt),
                ),
                _DetailItem(
                  label: 'Last updated at',
                  value: _formatDateTime(deployment.updatedAt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildActions(deployment),
        ],
      ),
    );
  }

  Widget _buildActions(ServiceDeployment deployment) {
    final actions = <Widget>[];

    void addAction(Widget action) {
      if (actions.isNotEmpty) {
        actions.add(const SizedBox(height: 10));
      }
      actions.add(action);
    }

    if (deployment.status == DeploymentStatus.draft ||
        deployment.status == DeploymentStatus.scheduled) {
      addAction(
        OutlinedButton.icon(
          key: const ValueKey('edit-deployment-button'),
          onPressed: _isSubmitting
              ? null
              : () => widget.onEditDeployment?.call(deployment),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      );
    }

    switch (deployment.status) {
      case DeploymentStatus.draft:
        addAction(
          FilledButton.icon(
            key: const ValueKey('schedule-detail-button'),
            onPressed: _isSubmitting
                ? null
                : () => _confirmStatusChange(DeploymentStatus.scheduled),
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Schedule Deployment'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: const Color(0xFF6D4AFF),
            ),
          ),
        );
        addAction(_cancelButton());
        addAction(_deleteButton());
      case DeploymentStatus.scheduled:
        addAction(
          FilledButton.icon(
            key: const ValueKey('start-deployment-button'),
            onPressed: _isSubmitting
                ? null
                : () => _confirmStatusChange(DeploymentStatus.active),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Deployment'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: const Color(0xFF6D4AFF),
            ),
          ),
        );
        addAction(_cancelButton());
      case DeploymentStatus.active:
        addAction(
          FilledButton.icon(
            key: const ValueKey('complete-deployment-button'),
            onPressed: _isSubmitting
                ? null
                : () => _confirmStatusChange(DeploymentStatus.completed),
            icon: const Icon(Icons.task_alt_outlined),
            label: const Text('Complete Deployment'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: const Color(0xFF166534),
            ),
          ),
        );
        addAction(_cancelButton());
      case DeploymentStatus.completed:
        addAction(
          const _WorkflowMessage(
            key: ValueKey('completed-workflow-message'),
            icon: Icons.verified_outlined,
            message:
                'Deployment workflow is complete. No further status '
                'changes are available.',
            color: Color(0xFF166534),
            background: Color(0xFFDCFCE7),
          ),
        );
      case DeploymentStatus.cancelled:
        addAction(
          const _WorkflowMessage(
            key: ValueKey('cancelled-workflow-message'),
            icon: Icons.cancel_outlined,
            message:
                'This deployment is cancelled. Workflow progression '
                'has stopped.',
            color: Color(0xFF991B1B),
            background: Color(0xFFFEE2E2),
          ),
        );
        addAction(_deleteButton());
    }

    return _DetailSection(
      title: 'Staff actions',
      icon: Icons.touch_app_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: actions,
      ),
    );
  }

  Widget _cancelButton() {
    return OutlinedButton.icon(
      key: const ValueKey('cancel-deployment-status-button'),
      onPressed: _isSubmitting
          ? null
          : () => _confirmStatusChange(DeploymentStatus.cancelled),
      icon: const Icon(Icons.cancel_outlined),
      label: const Text('Cancel Deployment'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: const Color(0xFF991B1B),
      ),
    );
  }

  Widget _deleteButton() {
    return TextButton.icon(
      key: const ValueKey('delete-deployment-button'),
      onPressed: _isSubmitting ? null : _confirmDeletion,
      icon: const Icon(Icons.delete_outline),
      label: const Text('Delete Prototype Record'),
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: const Color(0xFF991B1B),
      ),
    );
  }

  Future<void> _loadDeployment() async {
    setState(() {
      _isLoading = true;
      _isNotFound = false;
      _isDeleted = false;
      _loadError = null;
      _operationError = null;
    });

    final deployment = await widget.controller.getDeploymentById(
      widget.deploymentId,
    );
    if (!mounted) {
      return;
    }

    final controllerError = widget.controller.errorMessage;
    final notFoundMessage = 'Deployment ${widget.deploymentId} does not exist.';
    setState(() {
      _isLoading = false;
      if (deployment != null) {
        _deployment = deployment;
      } else if (controllerError == notFoundMessage) {
        _deployment = null;
        _isNotFound = true;
      } else {
        _deployment = null;
        _loadError = controllerError ?? 'Unable to load deployment details.';
      }
    });
  }

  Future<void> _confirmStatusChange(DeploymentStatus nextStatus) async {
    if (_isSubmitting) {
      return;
    }
    final content = _confirmationContent(nextStatus);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(content.title),
        content: Text('${content.message}\n\nAI recommends. Staff decides.'),
        actions: [
          TextButton(
            key: const ValueKey('dismiss-status-dialog'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(content.safeLabel),
          ),
          FilledButton(
            key: ValueKey('confirm-status-${nextStatus.name}'),
            onPressed: () => Navigator.of(context).pop(true),
            style: nextStatus == DeploymentStatus.cancelled
                ? FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF991B1B),
                  )
                : null,
            child: Text(content.confirmLabel),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    await _changeStatus(nextStatus);
  }

  Future<void> _changeStatus(DeploymentStatus nextStatus) async {
    if (_isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _operationError = null;
    });

    final changed = await widget.controller.changeStatus(
      widget.deploymentId,
      nextStatus,
      updatedAt: _now,
    );
    if (!mounted) {
      return;
    }
    if (!changed) {
      setState(() {
        _isSubmitting = false;
        _operationError =
            widget.controller.errorMessage ?? 'Unable to change status.';
      });
      return;
    }

    final latest = await widget.controller.getDeploymentById(
      widget.deploymentId,
    );
    if (!mounted) {
      return;
    }
    if (latest == null) {
      setState(() {
        _isSubmitting = false;
        _operationError =
            widget.controller.errorMessage ?? 'Unable to reload deployment.';
      });
      return;
    }

    setState(() {
      _deployment = latest;
      _isSubmitting = false;
      _operationError = null;
    });
    widget.onStatusChanged?.call(latest);
  }

  Future<void> _confirmDeletion() async {
    if (_isSubmitting) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete prototype record?'),
        content: const Text(
          'This removes the prototype deployment record from in-memory '
          'storage. This action does not affect live operations.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('dismiss-delete-dialog'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Record'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-deployment'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF991B1B),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    await _deleteDeployment();
  }

  Future<void> _deleteDeployment() async {
    if (_isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _operationError = null;
    });

    final deleted = await widget.controller.deleteDeployment(
      widget.deploymentId,
    );
    if (!mounted) {
      return;
    }
    if (!deleted) {
      setState(() {
        _isSubmitting = false;
        _operationError =
            widget.controller.errorMessage ?? 'Unable to delete deployment.';
      });
      return;
    }

    setState(() {
      _deployment = null;
      _isSubmitting = false;
      _isDeleted = true;
    });
    widget.onDeleted?.call();
  }

  _StatusConfirmationContent _confirmationContent(
    DeploymentStatus nextStatus,
  ) => switch (nextStatus) {
    DeploymentStatus.scheduled => const _StatusConfirmationContent(
      title: 'Schedule deployment?',
      message:
          'Confirm the route, actual vehicles and service window. '
          'Recommendation data does not automatically schedule this deployment.',
      confirmLabel: 'Schedule',
      safeLabel: 'Keep Draft',
    ),
    DeploymentStatus.active => const _StatusConfirmationContent(
      title: 'Start deployment?',
      message: 'Confirm that staff have verified the deployment has physically started.',
      confirmLabel: 'Start Deployment',
      safeLabel: 'Keep Scheduled',
    ),
    DeploymentStatus.completed => const _StatusConfirmationContent(
      title: 'Complete deployment?',
      message: 'Confirm that staff have verified the deployment operation has finished.',
      confirmLabel: 'Complete Deployment',
      safeLabel: 'Keep Active',
    ),
    DeploymentStatus.cancelled => const _StatusConfirmationContent(
      title: 'Cancel deployment?',
      message:
          'Confirm that cancellation should stop further workflow progression.',
      confirmLabel: 'Cancel Deployment',
      safeLabel: 'Keep Current Status',
    ),
    DeploymentStatus.draft => throw StateError(
      'Draft is not an operational action from this screen.',
    ),
  };

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusConfirmationContent {
  const _StatusConfirmationContent({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.safeLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String safeLabel;
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.child,
    super.key,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF6D4AFF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF17203A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}

class _VehicleItem extends StatelessWidget {
  const _VehicleItem({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.directions_bus_outlined,
            size: 18,
            color: Color(0xFF6D4AFF),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(vehicleId)),
        ],
      ),
    );
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

class _WorkflowMessage extends StatelessWidget {
  const _WorkflowMessage({
    required this.icon,
    required this.message,
    required this.color,
    required this.background,
    super.key,
  });

  final IconData icon;
  final String message;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationError extends StatelessWidget {
  const _OperationError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFF991B1B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  key: const ValueKey('deployment-operation-error'),
                  style: const TextStyle(color: Color(0xFF7F1D1D)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: Icons.error_outline,
      title: 'Unable to load deployment',
      message: message,
      action: FilledButton.icon(
        key: const ValueKey('retry-deployment-detail-button'),
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
      ),
    );
  }
}

class _NotFoundState extends StatelessWidget {
  const _NotFoundState({required this.deploymentId, required this.onRetry});

  final String deploymentId;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: Icons.search_off_outlined,
      title: 'Deployment not found',
      message: 'No deployment with ID $deploymentId could be found.',
      action: OutlinedButton.icon(
        key: const ValueKey('retry-deployment-detail-button'),
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
      ),
    );
  }
}

class _DeletedState extends StatelessWidget {
  const _DeletedState();

  @override
  Widget build(BuildContext context) {
    return const _CenteredState(
      icon: Icons.delete_outline,
      title: 'Deployment deleted',
      message: 'The prototype deployment record has been removed.',
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF6D4AFF)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
