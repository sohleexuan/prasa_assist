import 'package:flutter/material.dart';

import '../models/deployment_status.dart';

class DeploymentStatusChip extends StatelessWidget {
  const DeploymentStatusChip({required this.status, super.key});

  final DeploymentStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(status);

    return Semantics(
      container: true,
      label: 'Deployment status: ${status.displayLabel}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              status.displayLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  _StatusColors _colorsFor(DeploymentStatus status) => switch (status) {
    DeploymentStatus.draft => const _StatusColors(
      background: Color(0xFFE2E8F0),
      foreground: Color(0xFF334155),
      border: Color(0xFFCBD5E1),
    ),
    DeploymentStatus.scheduled => const _StatusColors(
      background: Color(0xFFEDE9FE),
      foreground: Color(0xFF5B21B6),
      border: Color(0xFFC4B5FD),
    ),
    DeploymentStatus.active => const _StatusColors(
      background: Color(0xFFDCFCE7),
      foreground: Color(0xFF166534),
      border: Color(0xFF86EFAC),
    ),
    DeploymentStatus.completed => const _StatusColors(
      background: Color(0xFFDBEAFE),
      foreground: Color(0xFF1E40AF),
      border: Color(0xFF93C5FD),
    ),
    DeploymentStatus.cancelled => const _StatusColors(
      background: Color(0xFFFEE2E2),
      foreground: Color(0xFF991B1B),
      border: Color(0xFFFCA5A5),
    ),
  };
}

class _StatusColors {
  const _StatusColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
