import 'package:flutter/material.dart';

import '../core/dependencies/app_dependencies_scope.dart';
import '../core/database/local_user_scope.dart';
import '../features/deployments/data/sources/sqlite_deployment_local_data_source.dart';
import '../features/deployments/data/sources/supabase_deployment_remote_data_source.dart';
import '../features/deployments/repositories/hybrid_deployment_repository.dart';
import '../features/deployments/service_deployment_page.dart';
import '../features/incidents/incident_module.dart';
import '../features/incidents/data/sources/sqlite_incident_local_data_source.dart';
import '../features/recommendations/controllers/recommendation_controller.dart';
import '../features/recommendations/data/sources/sqlite_recommendation_local_data_source.dart';
import '../features/recommendations/data/sources/supabase_recommendation_remote_data_source.dart';
import '../features/recommendations/pages/recommendation_list_page.dart';
import '../features/recommendations/repositories/hybrid_recommendation_repository.dart';
import '../features/work_orders/controllers/work_orders_controller.dart';
import '../features/work_orders/data/in_memory_work_order_repository.dart';
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
      pageBuilder: _buildIncidentPage,
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
      pageBuilder: _buildRecommendationPage,
    ),
  ]);

  static Widget _buildIncidentPage(BuildContext context) {
    final dependencies = AppDependenciesScope.of(context);
    final session = dependencies.authGateway.currentSession;
    if (session == null) {
      throw StateError(
        'An authenticated staff session is required to open incidents.',
      );
    }
    final email = session.email?.trim();
    final actorIdentifier = email?.isNotEmpty == true ? email! : session.userId;
    late final LocalUserScope userScope;
    try {
      userScope = LocalUserScope(session.userId);
    } on ArgumentError {
      throw StateError(
        'A valid authenticated staff identity is required to open incidents.',
      );
    }
    final remoteDataSource = SupabaseIncidentRemoteDataSource(
      dependencies.supabaseClient,
    );
    return IncidentListPage(
      repository: HybridIncidentRepository(
        remoteDataSource: remoteDataSource,
        localDataSource: SqliteIncidentLocalDataSource(
          database: dependencies.appDatabase,
          userScope: userScope,
        ),
      ),
      currentStaffId: actorIdentifier,
    );
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
    late final LocalUserScope userScope;
    try {
      userScope = LocalUserScope(session.userId);
    } on ArgumentError {
      throw StateError(
        'A valid authenticated staff identity is required to open deployments.',
      );
    }
    final remoteDataSource = SupabaseDeploymentRemoteDataSource(
      dependencies.supabaseClient,
    );
    var localIdSequence = 0;
    return ServiceDeploymentPage(
      repository: HybridDeploymentRepository(
        remoteDataSource: remoteDataSource,
        draftPublisher: remoteDataSource,
        localDataSource: SqliteDeploymentLocalDataSource(
          database: dependencies.appDatabase,
          userScope: userScope,
          localIdGenerator: () {
            localIdSequence++;
            return 'deployment-local-'
                '${DateTime.now().toUtc().microsecondsSinceEpoch}-'
                '$localIdSequence';
          },
        ),
      ),
      currentUserId: actorIdentifier,
    );
  }

  static Widget _buildRecommendationPage(BuildContext context) {
    final dependencies = AppDependenciesScope.of(context);
    final session = dependencies.authGateway.currentSession;
    if (session == null) {
      throw StateError(
        'An authenticated staff session is required to open recommendations.',
      );
    }
    final userScope = LocalUserScope(session.userId);
    return RecommendationListPage(
      controller: RecommendationController(
        HybridRecommendationRepository(
          remote: SupabaseRecommendationRemoteDataSource(
            dependencies.supabaseClient,
          ),
          local: SqliteRecommendationLocalDataSource(
            database: dependencies.appDatabase,
            userScope: userScope,
          ),
        ),
      ),
      workOrdersController: WorkOrdersController(
        InMemoryWorkOrderRepository(initialWorkOrders: const []),
      ),
    );
  }
}
