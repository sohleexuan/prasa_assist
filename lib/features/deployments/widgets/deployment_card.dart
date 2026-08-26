import 'package:flutter/material.dart';

import '../models/service_deployment.dart';
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
        margin: EdgeInsets.zero,
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                                  color: const Color(0xFF17203A),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
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
                    const SizedBox(width: 12),
                    DeploymentStatusChip(status: deployment.status),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailRow(
                  icon: Icons.directions_bus_outlined,
                  label: _vehicleCountLabel(deployment.vehicleCount),
                  value: deployment.vehicleIds.join(', '),
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.schedule_outlined,
                  label: 'Service window',
                  value:
                      '${_formatDateTime(deployment.startTime)} to '
                      '${_formatDateTime(deployment.endTime)}',
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.assignment_outlined,
                  label: 'Purpose',
                  value: deployment.purpose,
                ),
                if (deployment.incidentId != null ||
                    deployment.sourceRecommendationId != null) ...[
                  const SizedBox(height: 14),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
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
        Icon(icon, size: 20, color: const Color(0xFF6D4AFF)),
        const SizedBox(width: 10),
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
              const SizedBox(height: 2),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1EFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF5636C7)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF402596),
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
