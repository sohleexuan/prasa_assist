import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

class DeploymentDataNotice extends StatelessWidget {
  const DeploymentDataNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Module 3 prototype. In-memory demonstration data. Changes reset '
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
                    'Module 3 Prototype',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.onDevelopmentContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'In-memory demonstration data \u2022 Changes reset when '
                    'the app restarts',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.onDevelopmentContainer),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Not connected to live operations',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: AppColors.onDevelopmentContainer),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Prototype user: demo-operations-staff '
                    '(not authenticated)',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.onDevelopmentContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
