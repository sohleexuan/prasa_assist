import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../controllers/incident_controller.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../models/incident_status_change.dart';
import '../widgets/incident_data_notice.dart';
import 'incident_edit_page.dart';

class IncidentDetailPage extends StatefulWidget {
  const IncidentDetailPage({
    required this.controller,
    required this.incidentId,
    required this.currentStaffId,
    this.onEdit,
    this.onStatusChanged,
    this.onDeleted,
    this.clock,
    super.key,
  });

  final IncidentController controller;
  final String incidentId;
  final String currentStaffId;
  final ValueChanged<Incident>? onEdit;
  final ValueChanged<Incident>? onStatusChanged;
  final VoidCallback? onDeleted;
  final DateTime Function()? clock;

  @override
  State<IncidentDetailPage> createState() => _IncidentDetailPageState();
}

class _IncidentDetailPageState extends State<IncidentDetailPage> {
  Incident? _incident;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isNotFound = false;
  bool _isDeleted = false;
  String? _loadError;
  String? _operationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadIncident());
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Incident Details',
      actions: _incident != null && !_isSubmitting
          ? [
              if (!_incident!.status.isTerminal)
                IconButton(
                  key: const ValueKey('edit-incident-action'),
                  tooltip: 'Edit Incident',
                  onPressed: () {
                    final onEdit = widget.onEdit;
                    if (onEdit != null) {
                      onEdit(_incident!);
                    } else {
                      _openEdit(_incident!);
                    }
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
            ]
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingIndicator(message: 'Loading incident details...');
    }
    if (_isDeleted) {
      return const AppEmptyState(
        title: 'Incident deleted',
        message: 'The in-memory Incident record was permanently removed.',
        icon: Icons.delete_outline,
      );
    }
    if (_isNotFound) {
      return AppErrorState(
        title: 'Incident not found',
        message: 'Incident ${widget.incidentId} does not exist.',
        actionLabel: 'Retry',
        onAction: _loadIncident,
      );
    }
    if (_loadError != null || _incident == null) {
      return AppErrorState(
        title: 'Unable to load incident',
        message: _loadError ?? 'Incident details are unavailable.',
        actionLabel: 'Retry',
        onAction: _loadIncident,
      );
    }

    final incident = _incident!;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IncidentDataNotice(
            isPersistent: widget.controller.capabilities.isPersistent,
          ),
          if (_isSubmitting) ...[
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(
              key: ValueKey('incident-detail-progress'),
            ),
          ],
          if (_operationError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _OperationError(message: _operationError!),
          ],
          const SizedBox(height: AppSpacing.md),
          _OverviewCard(incident: incident),
          const SizedBox(height: AppSpacing.sm),
          _ServiceContextCard(incident: incident),
          const SizedBox(height: AppSpacing.sm),
          _DelayEvidenceCard(incident: incident),
          const SizedBox(height: AppSpacing.sm),
          _StatusHistoryCard(history: incident.statusHistory),
          const SizedBox(height: AppSpacing.sm),
          _AuditCard(incident: incident),
          const SizedBox(height: AppSpacing.lg),
          _buildActions(incident),
        ],
      ),
    );
  }

  Widget _buildActions(Incident incident) {
    final nextStatuses = IncidentStatus.values
        .where(incident.status.canTransitionTo)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (nextStatuses.isNotEmpty) ...[
          Text(
            'Staff Status Actions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'A status change occurs only after staff explicitly confirms it.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final status in nextStatuses)
                status == IncidentStatus.cancelled
                    ? OutlinedButton.icon(
                        key: ValueKey('incident-status-action-${status.name}'),
                        onPressed: _isSubmitting
                            ? null
                            : () => _confirmStatusChange(status),
                        icon: const Icon(Icons.cancel_outlined),
                        label: Text('Mark ${status.displayLabel}'),
                      )
                    : FilledButton.icon(
                        key: ValueKey('incident-status-action-${status.name}'),
                        onPressed: _isSubmitting
                            ? null
                            : () => _confirmStatusChange(status),
                        icon: Icon(_statusIcon(status)),
                        label: Text('Mark ${status.displayLabel}'),
                      ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ] else ...[
          AppSectionCard(
            title: '${incident.status.displayLabel} Incident',
            subtitle:
                'This status is terminal. The Incident cannot be edited or '
                'moved to another status.',
            leading: const Icon(Icons.lock_outline),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (!widget.controller.capabilities.supportsPhysicalDelete) ...[
          const AppSectionCard(
            title: 'Audit record retained',
            subtitle:
                'Persistent incidents cannot be permanently deleted. If the '
                'incident occurred but is no longer processed, use Cancelled.',
            leading: Icon(Icons.history_outlined),
          ),
        ] else if (incident.status.canBeDeleted)
          TextButton.icon(
            key: const ValueKey('delete-incident-button'),
            onPressed: _isSubmitting ? null : _confirmDeletion,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete Incident Permanently'),
          ),
      ],
    );
  }

  Future<void> _loadIncident() async {
    setState(() {
      _isLoading = true;
      _isNotFound = false;
      _loadError = null;
      _operationError = null;
    });
    final incident = await widget.controller.selectIncident(widget.incidentId);
    if (!mounted) {
      return;
    }
    final notFoundMessage = 'Incident ${widget.incidentId} does not exist.';
    setState(() {
      _isLoading = false;
      if (incident != null) {
        _incident = incident;
      } else if (widget.controller.errorMessage == notFoundMessage) {
        _incident = null;
        _isNotFound = true;
      } else {
        _incident = null;
        _loadError =
            widget.controller.errorMessage ??
            'Unable to load incident details.';
      }
    });
  }

  Future<void> _openEdit(Incident incident) async {
    final updated = await Navigator.of(context).push<Incident>(
      MaterialPageRoute(
        builder: (routeContext) => IncidentEditPage(
          controller: widget.controller,
          incident: incident,
          currentStaffId: widget.currentStaffId,
          clock: widget.clock,
          onSaved: (saved) => Navigator.of(routeContext).pop(saved),
          onCancel: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
    if (!mounted || updated == null) {
      return;
    }
    setState(() {
      _incident = updated;
      _operationError = null;
    });
  }

  Future<void> _confirmStatusChange(IncidentStatus targetStatus) async {
    if (_isSubmitting) {
      return;
    }
    var note = '';
    final confirmedNote = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Mark incident ${targetStatus.displayLabel}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_statusConfirmationMessage(targetStatus)),
            const SizedBox(height: AppSpacing.sm),
            const Text('AI recommends. Staff decides.'),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('incident-status-note-field'),
              minLines: 2,
              maxLines: 4,
              onChanged: (value) => note = value,
              decoration: const InputDecoration(
                labelText: 'Status note (optional)',
                hintText: 'Record staff reasoning or observations',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('dismiss-incident-status-dialog'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Keep Current Status'),
          ),
          FilledButton(
            key: ValueKey('confirm-incident-status-${targetStatus.name}'),
            onPressed: () => Navigator.of(dialogContext).pop(note),
            style: targetStatus == IncidentStatus.cancelled
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            child: Text('Confirm ${targetStatus.displayLabel}'),
          ),
        ],
      ),
    );
    if (!mounted || confirmedNote == null) {
      return;
    }
    await _changeStatus(targetStatus, note: confirmedNote);
  }

  Future<void> _changeStatus(
    IncidentStatus targetStatus, {
    required String note,
  }) async {
    if (_isSubmitting) {
      return;
    }
    final staffId = widget.currentStaffId.trim();
    if (staffId.isEmpty) {
      setState(() {
        _operationError =
            'A staff identity is required before changing Incident status.';
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _operationError = null;
    });
    final changed = await widget.controller.changeStatus(
      widget.incidentId,
      targetStatus,
      changedBy: staffId,
      note: note.trim().isEmpty ? null : note.trim(),
    );
    if (!mounted) {
      return;
    }
    final updated = widget.controller.selectedIncident;
    setState(() {
      _isSubmitting = false;
      if (changed && updated != null) {
        _incident = updated;
        _operationError = null;
      } else {
        _operationError =
            widget.controller.errorMessage ?? 'Unable to change status.';
      }
    });
    if (changed && updated != null) {
      widget.onStatusChanged?.call(updated);
    }
  }

  Future<void> _confirmDeletion() async {
    if (_isSubmitting) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Incident permanently?'),
        content: const Text(
          'Deleting is permanent and cannot be recovered. If the incident '
          'occurred but no longer requires handling, change its status to '
          'Cancelled instead. This removes only the Phase 1 in-memory record '
          'and does not affect live operations.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('dismiss-delete-incident-dialog'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Incident'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-incident'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    await _deleteIncident();
  }

  Future<void> _deleteIncident() async {
    setState(() {
      _isSubmitting = true;
      _operationError = null;
    });
    final deleted = await widget.controller.deleteIncident(widget.incidentId);
    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
      if (deleted) {
        _incident = null;
        _isDeleted = true;
      } else {
        _operationError =
            widget.controller.errorMessage ?? 'Unable to delete Incident.';
      }
    });
    if (deleted) {
      widget.onDeleted?.call();
    }
  }

  static String _statusConfirmationMessage(IncidentStatus status) =>
      switch (status) {
        IncidentStatus.underReview =>
          'Confirm that staff have begun reviewing the reported Incident.',
        IncidentStatus.active => 'Confirm that staff recognise the Incident as actively affecting operations.',
        IncidentStatus.resolved =>
          'Confirm that staff have verified the Incident is resolved.',
        IncidentStatus.cancelled => 'Use Cancelled when the Incident record should remain for audit but no further handling is required.',
        IncidentStatus.reported =>
          'Reported is assigned only when a new Incident is created.',
      };

  static IconData _statusIcon(IncidentStatus status) => switch (status) {
    IncidentStatus.underReview => Icons.manage_search_outlined,
    IncidentStatus.active => Icons.warning_amber_outlined,
    IncidentStatus.resolved => Icons.check_circle_outline,
    IncidentStatus.reported => Icons.assignment_outlined,
    IncidentStatus.cancelled => Icons.cancel_outlined,
  };
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: incident.title,
      subtitle: incident.incidentId,
      leading: const Icon(Icons.warning_amber_outlined),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppStatusChip(
                label: incident.status.displayLabel,
                tone: _statusTone(incident.status),
              ),
              AppStatusChip(
                label: incident.severity.displayLabel,
                tone: _severityTone(incident.severity),
              ),
              AppStatusChip(
                label: incident.impactLevel.displayLabel,
                tone: _impactTone(incident.impactLevel),
              ),
              AppStatusChip(
                label: incident.dataSource.displayLabel,
                tone: AppStatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(incident.description),
          const SizedBox(height: AppSpacing.sm),
          _DetailRow(
            label: 'Incident Type',
            value: incident.incidentType.displayLabel,
          ),
          _DetailRow(
            label: 'Reported Time',
            value: _formatDateTime(incident.reportedAt),
          ),
          _DetailRow(label: 'Reported By', value: incident.reportedBy),
        ],
      ),
    );
  }
}

class _ServiceContextCard extends StatelessWidget {
  const _ServiceContextCard({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Affected Service',
      subtitle: 'Route, vehicle and location values use the record\'s labelled data source.',
      leading: const Icon(Icons.route_outlined),
      body: Column(
        children: [
          _DetailRow(label: 'Route ID', value: incident.routeId),
          if (incident.routeName != null)
            _DetailRow(label: 'Route Name', value: incident.routeName!),
          _DetailRow(
            label: 'Vehicle ID',
            value: incident.vehicleId ?? 'Not provided',
          ),
          _DetailRow(label: 'Location', value: incident.location),
          _DetailRow(
            label: 'Vehicle Condition',
            value: incident.vehicleCondition.displayLabel,
          ),
          _DetailRow(
            label: 'Disruption Scope',
            value: incident.disruptionScope.displayLabel,
          ),
        ],
      ),
    );
  }
}

class _DelayEvidenceCard extends StatelessWidget {
  const _DelayEvidenceCard({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Delay and Operational Impact',
      subtitle:
          'PrasaAssist demonstration rules—not an official Prasarana model. '
          'Staff review is required.',
      leading: const Icon(Icons.timer_outlined),
      trailing: Text(
        '${incident.estimatedDelayMinutes} min',
        key: const ValueKey('incident-detail-delay'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final reason in incident.estimationReasons)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xxs),
                    child: Icon(Icons.check_circle_outline, size: 16),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(reason)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusHistoryCard extends StatelessWidget {
  const _StatusHistoryCard({required this.history});

  final List<IncidentStatusChange> history;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Status History',
      subtitle: 'Chronological staff audit trail',
      leading: const Icon(Icons.history_outlined),
      body: Column(
        children: [
          for (var index = 0; index < history.length; index++)
            _HistoryEntry(
              change: history[index],
              isLast: index == history.length - 1,
            ),
        ],
      ),
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.change, required this.isLast});

  final IncidentStatusChange change;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(Icons.circle, size: 14, color: colorScheme.primary),
            if (!isLast)
              Container(
                width: 2,
                height: 54,
                color: colorScheme.outlineVariant,
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  change.fromStatus == null
                      ? change.toStatus.displayLabel
                      : '${change.fromStatus!.displayLabel} → ${change.toStatus.displayLabel}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  '${_formatDateTime(change.changedAt)} · ${change.changedBy}',
                ),
                if (change.note != null) Text(change.note!),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Record Audit',
      leading: const Icon(Icons.fact_check_outlined),
      body: Column(
        children: [
          _DetailRow(
            label: 'Created',
            value: _formatDateTime(incident.createdAt),
          ),
          _DetailRow(
            label: 'Last Updated',
            value: _formatDateTime(incident.updatedAt),
          ),
          _DetailRow(
            label: 'Data Source',
            value: incident.dataSource.displayLabel,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(flex: 3, child: Text(value)),
        ],
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
      liveRegion: true,
      child: AppSectionCard(
        title: 'Incident action failed',
        subtitle: message,
        leading: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}

AppStatusTone _statusTone(IncidentStatus status) => switch (status) {
  IncidentStatus.reported => AppStatusTone.information,
  IncidentStatus.underReview => AppStatusTone.neutral,
  IncidentStatus.active => AppStatusTone.warning,
  IncidentStatus.resolved => AppStatusTone.success,
  IncidentStatus.cancelled => AppStatusTone.neutral,
};

AppStatusTone _severityTone(IncidentSeverity severity) => switch (severity) {
  IncidentSeverity.low => AppStatusTone.success,
  IncidentSeverity.medium => AppStatusTone.information,
  IncidentSeverity.high => AppStatusTone.warning,
  IncidentSeverity.critical => AppStatusTone.error,
};

AppStatusTone _impactTone(OperationalImpactLevel impact) => switch (impact) {
  OperationalImpactLevel.minor => AppStatusTone.success,
  OperationalImpactLevel.moderate => AppStatusTone.information,
  OperationalImpactLevel.major => AppStatusTone.warning,
  OperationalImpactLevel.severe => AppStatusTone.error,
};

String _formatDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}
