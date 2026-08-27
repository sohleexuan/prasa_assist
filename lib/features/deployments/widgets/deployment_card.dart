import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/service_deployment.dart';
import '../utils/deployment_date_time_formatter.dart';
import 'deployment_status_chip.dart';

class DeploymentCard extends StatelessWidget {
  const DeploymentCard({required this.deployment, this.onTap, super.key});

  final ServiceDeployment deployment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      button: onTap != null,
      label: onTap == null
          ? 'Deployment ${deployment.deploymentId}'
          : 'Open deployment ${deployment.deploymentId}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deployment.deploymentId,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            deployment.routeName,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Route ID ${deployment.routeId}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    DeploymentStatusChip(status: deployment.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  icon: Icons.directions_bus_outlined,
                  label: _vehicleCountLabel(deployment.vehicleCount),
                  value: deployment.vehicleIds.join(', '),
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  icon: Icons.schedule_outlined,
                  label: 'Service window',
                  value:
                      '${formatDeploymentLocalDateTime(deployment.startTime)} '
                      'to '
                      '${formatDeploymentLocalDateTime(deployment.endTime)}',
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  icon: Icons.assignment_outlined,
                  label: 'Purpose',
                  value: deployment.purpose,
                ),
                if (deployment.incidentId != null ||
                    deployment.sourceRecommendationId != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (deployment.incidentId case final incidentId?)
                        _ReferenceLabel(
                          icon: Icons.warning_amber_rounded,
                          text: 'Incident $incidentId',
                        ),
                      if (deployment.sourceRecommendationId
                          case final recommendationId?)
                        _ReferenceLabel(
                          icon: Icons.lightbulb_outline_rounded,
                          text: 'Recommendation $recommendationId',
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _vehicleCountLabel(int count) {
    return '$count ${count == 1 ? 'vehicle' : 'vehicles'}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReferenceLabel extends StatelessWidget {
  const _ReferenceLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: AppRadius.small,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSpacing.md, color: colorScheme.primary),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                text,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
