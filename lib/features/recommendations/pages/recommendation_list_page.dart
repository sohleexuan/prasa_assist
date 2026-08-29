import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../work_orders/controllers/work_orders_controller.dart';
import '../controllers/recommendation_controller.dart';
import '../domain/recommendation_status.dart';
import 'recommendation_detail_page.dart';

class RecommendationListPage extends StatefulWidget {
  const RecommendationListPage({
    required this.controller,
    required this.workOrdersController,
    this.onPrepareServiceDeployment,
    super.key,
  });
  final RecommendationController controller;
  final WorkOrdersController workOrdersController;
  final PrepareServiceDeploymentCallback? onPrepareServiceDeployment;

  @override
  State<RecommendationListPage> createState() => _RecommendationListPageState();
}

class _RecommendationListPageState extends State<RecommendationListPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.controller.load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    widget.controller.dispose();
    widget.workOrdersController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) =>
      AppPageScaffold(title: 'AI Recommendations', body: _content());

  Widget _content() {
    if (widget.controller.isLoading) {
      return const AppLoadingIndicator(message: 'Loading recommendations');
    }
    if (widget.controller.errorMessage != null &&
        widget.controller.records.isEmpty) {
      return AppErrorState(
        title: 'Unable to load recommendations',
        message: widget.controller.errorMessage!,
        actionLabel: 'Retry',
        onAction: widget.controller.load,
      );
    }
    if (widget.controller.records.isEmpty) {
      return const AppEmptyState(
        title: 'No recommendations',
        message: 'Deterministic recommendations awaiting staff review will appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: widget.controller.records.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final item = widget.controller.records[index].recommendation;
        return Card(
          child: ListTile(
            title: Text(
              '${item.vehicleId}${item.routeId == null ? '' : ' • Route ${item.routeId}'}',
            ),
            subtitle: Text(
              'Score ${item.score} • Confidence ${(item.confidence * 100).round()}%',
            ),
            trailing: Chip(label: Text(_status(item.status))),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecommendationDetailPage(
                  recommendationId: item.id,
                  controller: widget.controller,
                  workOrdersController: widget.workOrdersController,
                  onPrepareServiceDeployment: widget.onPrepareServiceDeployment,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _status(RecommendationStatus value) => switch (value) {
  RecommendationStatus.pendingReview => 'Pending review',
  RecommendationStatus.accepted => 'Accepted',
  RecommendationStatus.rejected => 'Rejected',
  RecommendationStatus.superseded => 'Superseded',
};
