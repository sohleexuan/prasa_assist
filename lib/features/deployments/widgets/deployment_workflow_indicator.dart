import 'package:flutter/material.dart';

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
          const SizedBox(height: 10),
          _CancelledOutcome(isCurrent: isCancelled),
          const SizedBox(height: 10),
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
    final foreground = isCurrent
        ? const Color(0xFF5636C7)
        : isCompleted
        ? const Color(0xFF166534)
        : const Color(0xFF64748B);
    final background = isCurrent
        ? const Color(0xFFEDE9FE)
        : isCompleted
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFF1F5F9);
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
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFFCBD5E1),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 18),
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
    final foreground = isCurrent
        ? const Color(0xFF991B1B)
        : const Color(0xFF64748B);
    final background = isCurrent
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFF8FAFC);

    return Semantics(
      container: true,
      label: isCurrent
          ? 'Cancelled, current alternative terminal outcome'
          : 'Cancelled, alternative terminal outcome',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFFFCA5A5)
                : const Color(0xFFCBD5E1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.cancel_outlined, color: foreground),
              const SizedBox(width: 10),
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
