import 'package:flutter/material.dart';

import '../core/dependencies/app_dependencies_scope.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../shared/widgets/app_page_scaffold.dart';
import '../shared/widgets/app_section_card.dart';
import '../shared/widgets/app_status_chip.dart';
import 'module_registry.dart';

class PrasaAssistHomePage extends StatefulWidget {
  const PrasaAssistHomePage({super.key});

  @override
  State<PrasaAssistHomePage> createState() => _PrasaAssistHomePageState();
}

class _PrasaAssistHomePageState extends State<PrasaAssistHomePage> {
  static const _safeSignOutFailureMessage =
      'Unable to sign out. Check the connection and try again.';

  var _isSigningOut = false;

  Future<void> _signOut() async {
    if (_isSigningOut) {
      return;
    }

    setState(() => _isSigningOut = true);

    try {
      final authGateway = AppDependenciesScope.of(context).authGateway;
      await authGateway.signOut();
    } on Object {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text(_safeSignOutFailureMessage)),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppPageScaffold(
      title: 'PrasaAssist',
      actions: [
        IconButton(
          key: const Key('staff-sign-out-button'),
          tooltip: 'Sign out',
          onPressed: _isSigningOut ? null : _signOut,
          icon: _isSigningOut
              ? const SizedBox.square(
                  dimension: AppSpacing.lg,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded),
        ),
      ],
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Container(
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
                            'Integrated staff prototype',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppColors.onDevelopmentContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Not a live operations control system. Module '
                            'workflows are connected for staff-reviewed '
                            'decision support.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.onDevelopmentContainer,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Operations workspace',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choose a module to continue. All operational decisions '
                'remain with authorised staff.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: AppRadius.card,
                ),
                child: Row(
                  children: [
                    Container(
                      width: AppSpacing.xs,
                      height: AppSpacing.xxl,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: AppRadius.pill,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Operating principle',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'AI recommends. Staff decides.',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Modules',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const AppStatusChip(
                    label: 'Integrated',
                    tone: AppStatusTone.information,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              for (final destination in ModuleRegistry.destinations) ...[
                AppSectionCard(
                  key: ValueKey('module-${destination.id}'),
                  leading: _ModuleIcon(
                    icon: destination.icon,
                    color: colorScheme.primary,
                    backgroundColor: colorScheme.primaryContainer,
                  ),
                  title: destination.title,
                  subtitle: destination.description,
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  semanticLabel: 'Open ${destination.title}',
                  onTap: () => _openModule(context, destination),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openModule(BuildContext context, ModuleDestination destination) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: destination.pageBuilder));
  }
}

class _ModuleIcon extends StatelessWidget {
  const _ModuleIcon({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.xxl,
      height: AppSpacing.xxl,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.medium,
      ),
      child: Icon(icon, color: color),
    );
  }
}
