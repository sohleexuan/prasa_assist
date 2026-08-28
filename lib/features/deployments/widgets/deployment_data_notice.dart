import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/deployment_read_result.dart';

class DeploymentDataNotice extends StatelessWidget {
  const DeploymentDataNotice({
    this.isPersistent = false,
    this.provenance,
    super.key,
  });

  final bool isPersistent;
  final DeploymentReadProvenance? provenance;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: isPersistent
          ? '${_persistentSourceText()}. '
                'Operational decisions remain with authorised staff.'
          : 'Module 3 prototype. In-memory demonstration data. Changes reset '
                'when the app restarts. Not connected to live operations. '
                'Prototype user demo-operations-staff, not authenticated.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.developmentContainer,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.developmentBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.science_outlined,
              color: AppColors.onDevelopmentContainer,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPersistent
                        ? 'Module 3 Shared Data'
                        : 'Module 3 Prototype',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.onDevelopmentContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    isPersistent
                        ? _persistentSourceText()
                        : 'In-memory demonstration data \u2022 Changes reset when '
                              'the app restarts',
                    key: isPersistent
                        ? const ValueKey('deployment-data-source-label')
                        : null,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.onDevelopmentContainer),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    isPersistent
                        ? 'Operational decisions remain with authorised staff'
                        : 'Not connected to live operations',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: AppColors.onDevelopmentContainer),
                  ),
                  if (isPersistent && provenance?.warningMessage != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      provenance!.warningMessage!,
                      key: const ValueKey('deployment-provenance-warning'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onDevelopmentContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (!isPersistent) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Prototype user: demo-operations-staff '
                      '(not authenticated)',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.onDevelopmentContainer),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _persistentSourceText() {
    final value = provenance;
    if (value == null) {
      return 'Authenticated Supabase deployment records \u2022 '
          'Changes persist across sessions \u2022 SQLite offline storage enabled';
    }
    final timestamp = _formatUtc(value.retrievedAtUtc);
    return switch (value.source) {
      DeploymentReadSource.liveSupabase =>
        'Live Supabase data \u2022 Retrieved $timestamp',
      DeploymentReadSource.cachedSqlite =>
        'Cached/offline SQLite data \u2022 Cached $timestamp',
    };
  }

  String _formatUtc(DateTime value) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final utc = value.toUtc();
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    return '$day ${months[utc.month - 1]} ${utc.year}, '
        '$hour:$minute UTC';
  }
}
