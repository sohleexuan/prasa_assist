import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AppStatusTone { neutral, information, success, warning, error }

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    required this.label,
    this.tone = AppStatusTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final AppStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(tone);

    return Semantics(
      container: true,
      label: 'Status: $label',
      child: ExcludeSemantics(
        child: Chip(
          avatar: icon == null ? null : Icon(icon, color: colors.foreground),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          labelStyle: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: colors.foreground),
          backgroundColor: colors.background,
          side: BorderSide(color: colors.foreground.withValues(alpha: 0.28)),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  _StatusColors _colorsFor(AppStatusTone tone) {
    return switch (tone) {
      AppStatusTone.neutral => const _StatusColors(
        background: AppColors.neutralContainer,
        foreground: AppColors.onNeutralContainer,
      ),
      AppStatusTone.information => const _StatusColors(
        background: AppColors.informationContainer,
        foreground: AppColors.onInformationContainer,
      ),
      AppStatusTone.success => const _StatusColors(
        background: AppColors.successContainer,
        foreground: AppColors.onSuccessContainer,
      ),
      AppStatusTone.warning => const _StatusColors(
        background: AppColors.warningContainer,
        foreground: AppColors.onWarningContainer,
      ),
      AppStatusTone.error => const _StatusColors(
        background: AppColors.errorContainer,
        foreground: AppColors.onErrorContainer,
      ),
    };
  }
}

class _StatusColors {
  const _StatusColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}
