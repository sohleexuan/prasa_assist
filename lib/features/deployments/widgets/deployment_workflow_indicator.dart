import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/deployment_status.dart';

class DeploymentWorkflowIndicator extends StatelessWidget {
  const DeploymentWorkflowIndicator({required this.currentStatus, super.key});

  final DeploymentStatus currentStatus;

  static const List<DeploymentStatus> _mainStages = [
    DeploymentStatus.draft,
    DeploymentStatus.scheduled,
    DeploymentStatus.active,
    DeploymentStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final isCancelled = currentStatus == DeploymentStatus.cancelled;
    final currentIndex = _mainStages.indexOf(currentStatus);

    return Semantics(
      container: true,
      label:
          'Deployment workflow. Current status: '
          '${currentStatus.displayLabel}. This shows the configured workflow, '
          'not recorded transition history.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < _mainStages.length; index++)
            _WorkflowStage(
              status: _mainStages[index],
              appearance: _appearanceFor(
                index: index,
                currentIndex: currentIndex,
                isCancelled: isCancelled,
              ),
              showConnector: index < _mainStages.length - 1,
            ),
          const SizedBox(height: AppSpacing.sm),
          _CancelledOutcome(isCurrent: isCancelled),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Workflow position only — no historical transition timestamps '
            'are recorded here.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  _StageAppearance _appearanceFor({
    required int index,
    required int currentIndex,
    required bool isCancelled,
  }) {
    if (isCancelled) {
      return _StageAppearance.unconfirmed;
    }
    if (index < currentIndex) {
      return _StageAppearance.completed;
    }
    if (index == currentIndex) {
      return _StageAppearance.current;
    }
    return _StageAppearance.future;
  }
}

enum _StageAppearance { completed, current, future, unconfirmed }

class _WorkflowStage extends StatelessWidget {
  const _WorkflowStage({
    required this.status,
    required this.appearance,
    required this.showConnector,
  });

  final DeploymentStatus status;
  final _StageAppearance appearance;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final isCurrent = appearance == _StageAppearance.current;
    final isCompleted = appearance == _StageAppearance.completed;
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isCurrent
        ? colorScheme.primary
        : isCompleted
        ? AppColors.success
        : colorScheme.onSurfaceVariant;
    final background = isCurrent
        ? colorScheme.primaryContainer
        : isCompleted
        ? AppColors.successContainer
        : colorScheme.surfaceContainer;
    final stateLabel = switch (appearance) {
      _StageAppearance.completed => 'completed workflow stage',
      _StageAppearance.current => 'current workflow stage',
      _StageAppearance.future => 'future workflow stage',
      _StageAppearance.unconfirmed =>
        'workflow stage, transition history unavailable',
    };

    return Semantics(
      container: true,
      label: '${status.displayLabel}, $stateLabel',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    shape: BoxShape.circle,
                    border: Border.all(color: foreground, width: 1.5),
                  ),
                  child: SizedBox.square(
                    dimension: 28,
                    child: Icon(
                      isCompleted
                          ? Icons.check_rounded
                          : isCurrent
                          ? Icons.circle
                          : Icons.circle_outlined,
                      size: isCurrent ? 10 : 17,
                      color: foreground,
                    ),
                  ),
                ),
                if (showConnector)
                  Container(
                    width: 2,
                    height: 22,
                    color: isCompleted
                        ? AppColors.success
                        : colorScheme.outlineVariant,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xxs,
                bottom: AppSpacing.md,
              ),
              child: Text(
                status.displayLabel,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: foreground,
                  fontWeight: isCurrent || isCompleted
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledOutcome extends StatelessWidget {
  const _CancelledOutcome({required this.isCurrent});

  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isCurrent
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;
    final background = isCurrent
        ? colorScheme.errorContainer
        : colorScheme.surfaceContainerLow;

    return Semantics(
      container: true,
      label: isCurrent
          ? 'Cancelled, current alternative terminal outcome'
          : 'Cancelled, alternative terminal outcome',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.medium,
          border: Border.all(
            color: isCurrent ? colorScheme.error : colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Icon(Icons.cancel_outlined, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  isCurrent
                      ? 'Cancelled — workflow stopped'
                      : 'Cancelled — alternative terminal outcome',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
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
