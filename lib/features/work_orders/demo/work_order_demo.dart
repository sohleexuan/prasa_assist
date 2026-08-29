import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/work_orders_controller.dart';
import '../data/in_memory_work_order_repository.dart';
import '../pages/work_order_list_page.dart';

void main() {
  runApp(const WorkOrderDemoApp());
}

class WorkOrderDemoApp extends StatefulWidget {
  const WorkOrderDemoApp({super.key});

  @override
  State<WorkOrderDemoApp> createState() => _WorkOrderDemoAppState();
}

class _WorkOrderDemoAppState extends State<WorkOrderDemoApp> {
  late final WorkOrdersController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WorkOrdersController(InMemoryWorkOrderRepository());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Work Order Demo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: WorkOrderListPage(controller: _controller),
    );
  }
}
