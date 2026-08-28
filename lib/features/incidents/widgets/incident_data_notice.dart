import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../../shared/widgets/app_status_chip.dart';

class IncidentDataNotice extends StatelessWidget {
  const IncidentDataNotice({required this.isPersistent, super.key});

  final bool isPersistent;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: isPersistent ? 'Shared Incident Data' : 'Module 1 Prototype',
      subtitle: isPersistent
          ? 'Supabase-backed staff records persist across app restarts. '
                'They remain decision-support records and do not control '
                'live operations.'
          : 'In-memory demonstration data. Changes reset when the app '
                'restarts and are not connected to live incident operations.',
      leading: Icon(
        isPersistent ? Icons.cloud_done_outlined : Icons.science_outlined,
      ),
      body: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          AppStatusChip(
            label: isPersistent
                ? 'Persistent / Shared Data'
                : 'Mock / Demonstration Data',
            tone: isPersistent
                ? AppStatusTone.success
                : AppStatusTone.information,
          ),
          AppStatusChip(
            label: 'Staff decision required',
            tone: AppStatusTone.warning,
          ),
        ],
      ),
    );
  }
}
