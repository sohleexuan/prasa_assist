import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../models/work_order.dart';
import 'work_order_status_chip.dart';

class WorkOrderCard extends StatelessWidget {
  const WorkOrderCard({
    required this.workOrder,
    required this.onTap,
    super.key,
  });

  final WorkOrder workOrder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '${workOrder.vehicleId} · ${workOrder.taskType}',
      subtitle: workOrder.description,
      semanticLabel: 'Open work order ${workOrder.workOrderId}',
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right_rounded),
      body: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          WorkOrderStatusChip(status: workOrder.status),
          Chip(label: Text(workOrder.priority.label)),
          Text(
            workOrder.workOrderId,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
