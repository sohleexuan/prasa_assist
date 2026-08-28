import 'package:flutter/material.dart';

import '../../../core/database/local_sync_state.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/dto/local_deployment_record.dart';
import '../utils/deployment_date_time_formatter.dart';

class LocalDeploymentWorkCard extends StatelessWidget {
  const LocalDeploymentWorkCard({
    required this.record,
    this.isPublishing = false,
    this.onEdit,
    this.onPublish,
    this.onDiscard,
    super.key,
  });

  final LocalDeploymentRecord record;
  final bool isPublishing;
  final VoidCallback? onEdit;
  final VoidCallback? onPublish;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Text(
                  'Local work ${record.localId}',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: AppRadius.small,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      isPublishing
                          ? 'Pending publication'
                          : _stateLabel(record.syncState),
                      key: ValueKey('local-state-${record.localId}'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              record.draft.routeName,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text('Route ID ${record.draft.routeId}'),
            const SizedBox(height: AppSpacing.xs),
            Text('Vehicles: ${record.draft.vehicleIds.join(', ')}'),
            Text(
              'Service window: '
              '${formatDeploymentLocalDateTime(record.draft.startTime)} to '
              '${formatDeploymentLocalDateTime(record.draft.endTime)}',
            ),
            if (record.safeErrorMessage case final message?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                key: ValueKey('local-error-${record.localId}'),
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (record.syncState == LocalSyncState.conflict) ...[
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Review and edit this local work before deciding what to do.',
              ),
            ],
            if (isPublishing) ...[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(),
            ],
            if (_hasActions) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  if (_canEdit)
                    OutlinedButton.icon(
                      key: ValueKey('edit-local-${record.localId}'),
                      onPressed: isPublishing ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  if (_canPublish)
                    FilledButton.icon(
                      key: ValueKey('publish-local-${record.localId}'),
                      onPressed: isPublishing ? null : onPublish,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(
                        record.syncState == LocalSyncState.publicationFailed
                            ? 'Retry publication'
                            : 'Publish',
                      ),
                    ),
                  if (record.syncState == LocalSyncState.localDraft)
                    TextButton.icon(
                      key: ValueKey('discard-local-${record.localId}'),
                      onPressed: isPublishing ? null : onDiscard,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Discard draft'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _canEdit => switch (record.syncState) {
    LocalSyncState.localDraft ||
    LocalSyncState.publicationFailed ||
    LocalSyncState.conflict => true,
    LocalSyncState.pendingPublication || LocalSyncState.cachedRemote => false,
  };

  bool get _canPublish => switch (record.syncState) {
    LocalSyncState.localDraft || LocalSyncState.publicationFailed => true,
    LocalSyncState.pendingPublication ||
    LocalSyncState.conflict ||
    LocalSyncState.cachedRemote => false,
  };

  bool get _hasActions => _canEdit || _canPublish;

  String _stateLabel(LocalSyncState state) => switch (state) {
    LocalSyncState.localDraft => 'Local draft — not published',
    LocalSyncState.pendingPublication => 'Pending publication',
    LocalSyncState.publicationFailed => 'Publication failed',
    LocalSyncState.conflict => 'Conflict — staff review required',
    LocalSyncState.cachedRemote => 'Confirmed cache',
  };
}
