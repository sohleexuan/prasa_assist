import 'package:flutter/material.dart';

import 'module_placeholder_page.dart';

typedef ModulePageBuilder = Widget Function(BuildContext context);

@immutable
class ModuleDestination {
  const ModuleDestination({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.pageBuilder,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final ModulePageBuilder pageBuilder;
}

abstract final class ModuleRegistry {
  static final List<ModuleDestination> destinations = List.unmodifiable([
    ModuleDestination(
      id: 'incidents',
      title: 'Incident Management',
      description: 'Report incidents and review their operational impact.',
      icon: Icons.warning_amber_rounded,
      pageBuilder: _buildIncidentPlaceholder,
    ),
    ModuleDestination(
      id: 'work-orders',
      title: 'Maintenance Work Orders',
      description: 'Coordinate vehicle inspection and maintenance activity.',
      icon: Icons.build_circle_outlined,
      pageBuilder: _buildWorkOrderPlaceholder,
    ),
    ModuleDestination(
      id: 'deployments',
      title: 'Service Deployment',
      description: 'Plan additional or replacement service deployment.',
      icon: Icons.directions_bus_filled_outlined,
      pageBuilder: _buildDeploymentPlaceholder,
    ),
    ModuleDestination(
      id: 'recommendations',
      title: 'AI Recommendations',
      description: 'Review explainable guidance before staff take action.',
      icon: Icons.lightbulb_outline_rounded,
      pageBuilder: _buildRecommendationPlaceholder,
    ),
  ]);

  static Widget _buildIncidentPlaceholder(BuildContext context) {
    return const ModulePlaceholderPage(moduleName: 'Incident Management');
  }

  static Widget _buildWorkOrderPlaceholder(BuildContext context) {
    return const ModulePlaceholderPage(moduleName: 'Maintenance Work Orders');
  }

  static Widget _buildDeploymentPlaceholder(BuildContext context) {
    return const ModulePlaceholderPage(moduleName: 'Service Deployment');
  }

  static Widget _buildRecommendationPlaceholder(BuildContext context) {
    return const ModulePlaceholderPage(moduleName: 'AI Recommendations');
  }
}
