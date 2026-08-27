import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../shared/widgets/app_page_scaffold.dart';
import '../shared/widgets/app_section_card.dart';
import '../shared/widgets/app_status_chip.dart';

class ModulePlaceholderPage extends StatelessWidget {
  const ModulePlaceholderPage({required this.moduleName, super.key});

  final String moduleName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppPageScaffold(
      title: moduleName,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AppSectionCard(
                leading: Container(
                  width: AppSpacing.xxl,
                  height: AppSpacing.xxl,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: AppRadius.medium,
                  ),
                  child: Icon(
                    Icons.construction_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                title: 'Module integration pending',
                subtitle:
                    '$moduleName currently opens this placeholder. '
                    'Its owner will expose an entry page, and the coordinator '
                    'will connect it during final integration.',
                body: const Align(
                  alignment: Alignment.centerLeft,
                  child: AppStatusChip(
                    label: 'Not integrated',
                    tone: AppStatusTone.neutral,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.developmentContainer,
                  borderRadius: AppRadius.card,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.onDevelopmentContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'This foundation contains no operational data or '
                        'automated actions. AI recommends. Staff decides.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.onDevelopmentContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
