import 'package:flutter/material.dart';

import '../../../shared/widgets/app_status_chip.dart';
import '../models/work_order.dart';

class WorkOrderStatusChip extends StatelessWidget {
  const WorkOrderStatusChip({required this.status, super.key});

  final WorkOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      WorkOrderStatus.draft => AppStatusTone.neutral,
      WorkOrderStatus.open ||
      WorkOrderStatus.assigned => AppStatusTone.information,
      WorkOrderStatus.inProgress => AppStatusTone.warning,
      WorkOrderStatus.completed => AppStatusTone.success,
      WorkOrderStatus.cancelled => AppStatusTone.error,
    };
    return AppStatusChip(label: status.label, tone: tone);
  }
}
