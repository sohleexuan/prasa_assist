import 'package:flutter/material.dart';

import '../../../shared/widgets/app_status_chip.dart';
import '../models/deployment_status.dart';

class DeploymentStatusChip extends StatelessWidget {
  const DeploymentStatusChip({required this.status, super.key});

  final DeploymentStatus status;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Deployment status: ${status.displayLabel}',
      child: ExcludeSemantics(
        child: AppStatusChip(
          label: status.displayLabel,
          tone: _toneFor(status),
        ),
      ),
    );
  }

  AppStatusTone _toneFor(DeploymentStatus status) => switch (status) {
    DeploymentStatus.draft => AppStatusTone.neutral,
    DeploymentStatus.scheduled => AppStatusTone.information,
    DeploymentStatus.active => AppStatusTone.success,
    DeploymentStatus.completed => AppStatusTone.information,
    DeploymentStatus.cancelled => AppStatusTone.error,
  };
}
