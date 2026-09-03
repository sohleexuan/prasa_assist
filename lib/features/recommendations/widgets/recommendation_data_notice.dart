import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/time/malaysia_time.dart';
import '../models/recommendation_read_result.dart';

class RecommendationDataNotice extends StatelessWidget {
  const RecommendationDataNotice({required this.provenance, super.key});

  final RecommendationReadProvenance provenance;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = _label();
    return Semantics(
      container: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: provenance.isCached
              ? colorScheme.errorContainer
              : colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                provenance.isCached
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_done_outlined,
                color: provenance.isCached
                    ? colorScheme.onErrorContainer
                    : colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: provenance.isCached
                        ? colorScheme.onErrorContainer
                        : colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _label() {
    final retrieved = MalaysiaTime.formatDateTime(provenance.retrievedAtUtc);
    return switch (provenance.source) {
      RecommendationReadSource.liveSupabase =>
        'Live Supabase recommendation data • Retrieved $retrieved',
      RecommendationReadSource.cachedSqlite =>
        'Cached/offline SQLite recommendation data — not live • Cached $retrieved',
    };
  }
}
