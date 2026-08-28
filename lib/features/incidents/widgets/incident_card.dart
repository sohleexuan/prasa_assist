import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';

class IncidentCard extends StatelessWidget {
  const IncidentCard({required this.incident, this.onTap, super.key});

  final Incident incident;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      button: onTap != null,
      label: onTap == null
          ? 'Incident ${incident.incidentId}'
          : 'Open incident ${incident.incidentId}',
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
                            incident.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '${incident.incidentId} · '
                            '${incident.incidentType.displayLabel}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
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
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _Metadata(
                      icon: Icons.route_outlined,
                      label: incident.routeName ?? incident.routeId,
                    ),
                    if (incident.vehicleId != null)
                      _Metadata(
                        icon: Icons.directions_bus_outlined,
                        label: incident.vehicleId!,
                      ),
                    _Metadata(
                      icon: Icons.schedule_outlined,
                      label: _formatDateTime(incident.reportedAt),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Estimated delay: '
                        '${incident.estimatedDelayMinutes} minutes',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  incident.dataSource.displayLabel,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static AppStatusTone _statusTone(IncidentStatus status) => switch (status) {
    IncidentStatus.reported => AppStatusTone.information,
    IncidentStatus.underReview => AppStatusTone.neutral,
    IncidentStatus.active => AppStatusTone.warning,
    IncidentStatus.resolved => AppStatusTone.success,
    IncidentStatus.cancelled => AppStatusTone.neutral,
  };

  static AppStatusTone _severityTone(IncidentSeverity severity) =>
      switch (severity) {
        IncidentSeverity.low => AppStatusTone.success,
        IncidentSeverity.medium => AppStatusTone.information,
        IncidentSeverity.high => AppStatusTone.warning,
        IncidentSeverity.critical => AppStatusTone.error,
      };

  static AppStatusTone _impactTone(OperationalImpactLevel impact) =>
      switch (impact) {
        OperationalImpactLevel.minor => AppStatusTone.success,
        OperationalImpactLevel.moderate => AppStatusTone.information,
        OperationalImpactLevel.major => AppStatusTone.warning,
        OperationalImpactLevel.severe => AppStatusTone.error,
      };

  static String _formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: AppSpacing.xxs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
