import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../deployments/models/deployment_prefill.dart';
import '../../work_orders/models/work_order_prefill.dart';
import '../controllers/recommendation_controller.dart';
import '../domain/recommendation_action.dart';
import '../domain/recommendation_status.dart';
import '../services/recommendation_work_order_prefill_factory.dart';
import '../services/recommendation_deployment_prefill_factory.dart';
import '../widgets/recommendation_analysis_panel.dart';

/// Lets the coordinator open Module 3's editable create form. The callback is
/// advisory only; Module 4 does not navigate or persist a deployment.
typedef PrepareServiceDeploymentCallback = FutureOr<void> Function(
  DeploymentPrefill prefill,
);

/// Lets the coordinator open Module 2's editable create form. The callback is
/// advisory only; Module 4 does not navigate or persist a work order.
typedef PrepareWorkOrderCallback = FutureOr<void> Function(
  WorkOrderPrefill prefill,
);

class RecommendationDetailPage extends StatefulWidget {
  const RecommendationDetailPage({
    required this.recommendationId,
    required this.controller,
    this.onPrepareWorkOrder,
    this.onPrepareServiceDeployment,
    super.key,
  });
  final String recommendationId;
  final RecommendationController controller;
  final PrepareWorkOrderCallback? onPrepareWorkOrder;
  final PrepareServiceDeploymentCallback? onPrepareServiceDeployment;
  @override
  State<RecommendationDetailPage> createState() =>
      _RecommendationDetailPageState();
}

class _RecommendationDetailPageState extends State<RecommendationDetailPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final record = widget.controller.find(widget.recommendationId);
      if (record != null && record.analysis == null) {
        widget.controller.generateAnalysis(widget.recommendationId);
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.controller.find(widget.recommendationId);
    if (record == null) {
      return const AppPageScaffold(
        title: 'Recommendation',
        body: AppErrorState(
          title: 'Recommendation unavailable',
          message: 'Refresh the recommendation list and try again.',
        ),
      );
    }
    final item = record.recommendation;
    final busy = widget.controller.isBusy(item.id);
    final canPrepareWorkOrder =
        item.status == RecommendationStatus.accepted &&
        item.actions.any((action) => action is InspectOrRepairVehicleAction);
    final canPrepareServiceDeployment =
        item.status == RecommendationStatus.accepted &&
        item.actions.any((action) => action is DeployReplacementBusesAction);
    return AppPageScaffold(
      title: 'Recommendation review',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'AI recommends. Staff decides.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          AppSectionCard(
            title:
                '${item.vehicleId}${item.routeId == null ? '' : ' • Route ${item.routeId}'}',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deterministic score: ${item.score}/100'),
                Text(
                  'Explainable confidence: ${(item.confidence * 100).round()}%',
                ),
                for (final action in item.actions)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text('• ${_action(action)}'),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Evidence and provenance',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final evidence in item.evidence)
                  Text(
                    '• ${evidence.description} (${evidence.dataClassification.name}, +${evidence.contribution})',
                  ),
                for (final factor in item.confidenceDetails.factors)
                  Text(
                    '• ${factor.description}: ${(factor.weight * 100).round()}% weight',
                  ),
                for (final penalty in item.confidenceDetails.penalties)
                  Text(
                    '• ${penalty.description}: −${(penalty.amount * 100).round()}%',
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          RecommendationAnalysisPanel(
            analysis: record.analysis,
            loading: busy && record.analysis == null,
            onRetry: busy
                ? null
                : () => widget.controller.generateAnalysis(item.id),
          ),
          if (widget.controller.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                widget.controller.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          if (item.status == RecommendationStatus.pendingReview)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('rejectRecommendationButton'),
                    onPressed: busy ? null : _reject,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    key: const Key('acceptRecommendationButton'),
                    onPressed: busy
                        ? null
                        : () => widget.controller.decide(item.id, 'accepted'),
                    child: Text(busy ? 'Saving…' : 'Accept'),
                  ),
                ),
              ],
            )
          else ...[
            AppSectionCard(
              title: item.status == RecommendationStatus.accepted
                  ? 'Accepted'
                  : 'Rejected',
              body: Text(
                'Decision by ${item.decisionUserId ?? 'staff'} at ${item.decisionAt?.toIso8601String() ?? 'recorded time'}${item.decisionNote == null ? '' : '\nNote: ${item.decisionNote}'}',
              ),
            ),
            if (item.status == RecommendationStatus.accepted) ...[
              const SizedBox(height: AppSpacing.sm),
              if (canPrepareWorkOrder)
                FilledButton.icon(
                  key: const Key('prepareWorkOrderButton'),
                  onPressed: widget.onPrepareWorkOrder == null
                      ? null
                      : _prepareWorkOrder,
                  icon: const Icon(Icons.build_outlined),
                  label: const Text('Prepare Work Order'),
                ),
              if (canPrepareServiceDeployment) ...[
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  key: const Key('prepareServiceDeploymentButton'),
                  onPressed: widget.onPrepareServiceDeployment == null
                      ? null
                      : _prepareServiceDeployment,
                  icon: const Icon(Icons.directions_bus_outlined),
                  label: const Text('Prepare Service Deployment'),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _reject() async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject recommendation'),
        content: TextField(
          controller: note,
          decoration: const InputDecoration(
            labelText: 'Decision note (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm rejection'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.decide(
        widget.recommendationId,
        'rejected',
        note: note.text,
      );
    }
    note.dispose();
  }

  Future<void> _prepareWorkOrder() async {
    final callback = widget.onPrepareWorkOrder;
    if (callback == null) return;
    final record = widget.controller.find(widget.recommendationId)!;
    final prefill = RecommendationWorkOrderPrefillFactory().create(record);
    await callback(prefill);
  }

  Future<void> _prepareServiceDeployment() async {
    final callback = widget.onPrepareServiceDeployment;
    if (callback == null) return;
    final record = widget.controller.find(widget.recommendationId)!;
    final prefill = RecommendationDeploymentPrefillFactory().create(record);
    await callback(prefill);
  }
}

String _action(RecommendationAction action) => switch (action) {
  InspectOrRepairVehicleAction() => 'Inspect or repair ${action.vehicleId}',
  DeployReplacementBusesAction() =>
    'Deploy ${action.busCount} replacement buses on Route ${action.routeId}',
};
