import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../domain/recommendation_analysis.dart';

class RecommendationAnalysisPanel extends StatelessWidget {
  const RecommendationAnalysisPanel({
    required this.analysis,
    required this.loading,
    required this.errorMessage,
    required this.onRetry,
    super.key,
  });

  final RecommendationAnalysis? analysis;
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'AI-generated explanation',
      subtitle:
          'Gemini explains stored deterministic facts only. Staff must decide.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (analysis == null) ...[
            const Text('Analysis unavailable'),
            const SizedBox(height: AppSpacing.xs),
            if (errorMessage != null) ...[
              Text(
                errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            const Text(
              'This does not block staff from accepting or rejecting the recommendation.',
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('retryAnalysisButton'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry analysis'),
            ),
          ] else ...[
            Text(analysis!.summary),
            _List(title: 'Rationale', values: analysis!.rationale),
            _List(title: 'Limitations', values: analysis!.limitations),
            _List(
              title: 'Staff review checklist',
              values: analysis!.staffReviewChecklist,
            ),
          ],
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.title, required this.values});
  final String title;
  final List<String> values;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        for (final value in values)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text('• $value'),
          ),
      ],
    ),
  );
}
