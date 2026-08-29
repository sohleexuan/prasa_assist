import 'package:flutter/material.dart';

import '../../../shared/widgets/app_status_chip.dart';
import '../models/work_order.dart';

class WorkOrderPriorityChip extends StatelessWidget {
  const WorkOrderPriorityChip({required this.priority, super.key});

  final WorkOrderPriority priority;

  @override
  Widget build(BuildContext context) {
    final tone = switch (priority) {
      WorkOrderPriority.low => AppStatusTone.neutral,
      WorkOrderPriority.medium => AppStatusTone.information,
      WorkOrderPriority.high => AppStatusTone.warning,
      WorkOrderPriority.urgent => AppStatusTone.error,
    };
    return AppStatusChip(label: priority.label, tone: tone);
  }
}
