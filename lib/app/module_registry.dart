import 'package:flutter/material.dart';

import '../core/dependencies/app_dependencies_scope.dart';
import '../features/deployments/data/sources/supabase_deployment_remote_data_source.dart';
import '../features/deployments/repositories/persistent_deployment_repository.dart';
import '../features/deployments/service_deployment_page.dart';
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
      pageBuilder: _buildDeploymentPage,
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

  static Widget _buildDeploymentPage(BuildContext context) {
    final dependencies = AppDependenciesScope.of(context);
    final session = dependencies.authGateway.currentSession;
    if (session == null) {
      throw StateError(
        'An authenticated staff session is required to open deployments.',
      );
    }
    final email = session.email?.trim();
    final actorIdentifier = email?.isNotEmpty == true ? email! : session.userId;
    return ServiceDeploymentPage(
      repository: PersistentDeploymentRepository(
        dataSource: SupabaseDeploymentRemoteDataSource(
          dependencies.supabaseClient,
        ),
      ),
      currentUserId: actorIdentifier,
    );
  }

  static Widget _buildRecommendationPlaceholder(BuildContext context) {
    return const ModulePlaceholderPage(moduleName: 'AI Recommendations');
  }
}
