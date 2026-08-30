import 'dart:math';

import 'package:flutter/material.dart';

import '../core/dependencies/app_dependencies_scope.dart';
import '../core/database/local_user_scope.dart';
import '../features/deployments/data/sources/sqlite_deployment_local_data_source.dart';
import '../features/deployments/data/sources/supabase_deployment_remote_data_source.dart';
import '../features/deployments/models/deployment_prefill.dart';
import '../features/deployments/repositories/hybrid_deployment_repository.dart';
import '../features/deployments/service_deployment_page.dart';
import '../features/incidents/incident_module.dart';
import '../features/incidents/data/sources/sqlite_incident_local_data_source.dart';
import '../features/recommendations/controllers/recommendation_controller.dart';
import '../features/recommendations/data/sources/sqlite_recommendation_local_data_source.dart';
import '../features/recommendations/data/sources/supabase_recommendation_remote_data_source.dart';
import '../features/recommendations/domain/recommendation_rule_policy.dart';
import '../features/recommendations/pages/incident_recommendation_confirmation_page.dart';
import '../features/recommendations/pages/recommendation_list_page.dart';
import '../features/recommendations/repositories/hybrid_recommendation_repository.dart';
import '../features/recommendations/repositories/recommendation_repository.dart';
import '../features/recommendations/services/deterministic_recommendation_rule_engine.dart';
import '../features/recommendations/services/explainable_confidence_scorer.dart';
import '../features/recommendations/services/incident_recommendation_submission_service.dart';
import '../features/work_orders/controllers/work_orders_controller.dart';
import '../features/work_orders/data/sources/sqlite_work_order_local_data_source.dart';
import '../features/work_orders/data/sources/supabase_work_order_remote_data_source.dart';
import '../features/work_orders/models/work_order_prefill.dart';
import '../features/work_orders/pages/work_order_form_page.dart';
import '../features/work_orders/pages/work_order_list_page.dart';
import '../features/work_orders/repositories/hybrid_work_order_repository.dart';

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
      pageBuilder: buildIncidentPage,
    ),
    ModuleDestination(
      id: 'work-orders',
      title: 'Maintenance Work Orders',
      description: 'Coordinate vehicle inspection and maintenance activity.',
      icon: Icons.build_circle_outlined,
      pageBuilder: _buildWorkOrderPage,
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

  static Widget buildIncidentPage(
    BuildContext context, {
    RecommendationRepository? recommendationRepository,
  }) {
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
      onPrepareIncidentRecommendation: (facts) => _openIncidentRecommendation(
        context,
        facts,
        recommendationRepository: recommendationRepository,
      ),
    );
  }

  static Widget _buildWorkOrderPage(BuildContext context) {
    return WorkOrderListPage(controller: _buildWorkOrderController(context));
  }

  static Widget _buildDeploymentPage(
    BuildContext context, {
    DeploymentPrefill? initialCreatePrefill,
  }) {
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
      initialCreatePrefill: initialCreatePrefill,
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
    final recommendationRepository = _buildRecommendationRepository(context);
    return RecommendationListPage(
      controller: RecommendationController(recommendationRepository),
      onPrepareWorkOrder: (prefill) => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => _buildWorkOrderFormPage(context, prefill),
        ),
      ),
      onPrepareServiceDeployment: (prefill) => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) =>
              _buildDeploymentPage(context, initialCreatePrefill: prefill),
        ),
      ),
    );
  }

  static Future<void> _openIncidentRecommendation(
    BuildContext context,
    M1IncidentRecommendationFacts facts, {
    RecommendationRepository? recommendationRepository,
  }) async {
    final dependencies = AppDependenciesScope.of(context);
    final session = dependencies.authGateway.currentSession;
    if (session == null) {
      throw StateError(
        'An authenticated staff session is required to prepare recommendations.',
      );
    }
    final repository =
        recommendationRepository ?? _buildRecommendationRepository(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => IncidentRecommendationConfirmationPage(
          facts: facts,
          ownerUserId: session.userId,
          recommendationIdGenerator: _uuidV4,
          submissionService: IncidentRecommendationSubmissionService(
            repository: repository,
            ruleEngine: DeterministicRecommendationRuleEngine(
              policy: RecommendationRulePolicy.ownerApproved(),
              confidenceScorer: const ExplainableConfidenceScorer(),
            ),
          ),
          clock: _utcNow,
          onSubmitted: (_) {
            Navigator.of(routeContext).pushReplacement<void, void>(
              MaterialPageRoute<void>(builder: _buildRecommendationPage),
            );
          },
        ),
      ),
    );
  }

  static HybridRecommendationRepository _buildRecommendationRepository(
    BuildContext context,
  ) {
    final dependencies = AppDependenciesScope.of(context);
    final session = dependencies.authGateway.currentSession;
    if (session == null) {
      throw StateError(
        'An authenticated staff session is required to open recommendations.',
      );
    }
    return HybridRecommendationRepository(
      remote: SupabaseRecommendationRemoteDataSource(
        dependencies.supabaseClient,
      ),
      local: SqliteRecommendationLocalDataSource(
        database: dependencies.appDatabase,
        userScope: LocalUserScope(session.userId),
      ),
    );
  }

  static WorkOrdersController _buildWorkOrderController(BuildContext context) {
    final dependencies = AppDependenciesScope.of(context);
    final session = dependencies.authGateway.currentSession;
    if (session == null) {
      throw StateError(
        'An authenticated staff session is required to open work orders.',
      );
    }
    final userScope = LocalUserScope(session.userId);
    final email = session.email?.trim();
    final staffLabel = email?.isNotEmpty == true ? email! : session.userId;
    var localIdSequence = 0;
    final localDataSource = SqliteWorkOrderLocalDataSource(
      database: dependencies.appDatabase,
      userScope: userScope,
      localIdGenerator: () {
        localIdSequence++;
        return 'work-order-local-'
            '${DateTime.now().toUtc().microsecondsSinceEpoch}-'
            '$localIdSequence';
      },
    );
    final hybridRepository = HybridWorkOrderRepository(
      remoteDataSource: SupabaseWorkOrderRemoteDataSource(
        dependencies.supabaseClient,
      ),
      localDataSource: localDataSource,
    );
    return WorkOrdersController.hybrid(
      hybridRepository,
      localDraftCreatedByLabel: staffLabel,
    );
  }

  static Widget _buildWorkOrderFormPage(
    BuildContext context,
    WorkOrderPrefill prefill,
  ) => WorkOrderFormPage(
    controller: _buildWorkOrderController(context),
    prefill: prefill,
  );

  static DateTime _utcNow() => DateTime.now().toUtc();

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final value = bytes.map(hex).join();
    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
