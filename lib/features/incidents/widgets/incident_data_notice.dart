import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/time/malaysia_time.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../models/incident_read_result.dart';

class IncidentDataNotice extends StatelessWidget {
  const IncidentDataNotice({
    required this.isPersistent,
    this.provenance,
    super.key,
  });

  final bool isPersistent;
  final IncidentReadProvenance? provenance;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: isPersistent ? 'Shared Incident Data' : 'Module 1 Prototype',
      subtitle: provenance?.isCached == true
          ? 'Showing owner-scoped SQLite cache saved at '
                '${MalaysiaTime.formatDateTime(provenance!.retrievedAtUtc)}. Supabase is '
                'currently unreachable.'
          : isPersistent
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
            label: provenance?.isCached == true
                ? 'Cached / Offline Data'
                : isPersistent
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
