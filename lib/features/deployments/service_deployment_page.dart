import 'dart:async';

import 'package:flutter/material.dart';

import 'controllers/deployment_controller.dart';
import 'controllers/route_catalog_controller.dart';
import 'data/dto/local_deployment_record.dart';
import 'models/deployment_prefill.dart';
import 'models/service_deployment.dart';
import 'repositories/bundled_route_catalog_repository.dart';
import 'repositories/deployment_repository.dart';
import 'repositories/in_memory_deployment_repository.dart';
import 'repositories/route_catalog_repository.dart';
import 'screens/deployment_detail_screen.dart';
import 'screens/deployment_form_screen.dart';
import 'screens/deployment_list_screen.dart';

/// Normal page entry point for Module 3.
///
/// The page owns its controller but does not create a [MaterialApp], so the
/// integration layer can place it directly in the shared application shell.
class ServiceDeploymentPage extends StatefulWidget {
  const ServiceDeploymentPage({
    this.repository,
    this.routeCatalogRepository,
    this.initialCreatePrefill,
    this.currentUserId = prototypeUserId,
    this.clock,
    this.deploymentIdGenerator,
    super.key,
  });

  static const String prototypeUserId = 'demo-operations-staff';

  final DeploymentRepository? repository;
  final RouteCatalogRepository? routeCatalogRepository;

  /// Opens the existing editable create form once after navigation to this
  /// page. The caller must supply an advisory [DeploymentPrefill]; it never
  /// creates, schedules, publishes, or allocates a deployment by itself.
  final DeploymentPrefill? initialCreatePrefill;
  final String currentUserId;
  final DateTime Function()? clock;
  final String Function(int sequence)? deploymentIdGenerator;

  @override
  State<ServiceDeploymentPage> createState() => _ServiceDeploymentPageState();
}

class _ServiceDeploymentPageState extends State<ServiceDeploymentPage> {
  late final DeploymentRepository _repository;
  late final DeploymentController _controller;
  late final RouteCatalogController _routeCatalogController;
  late final Future<void> _routeCatalogLoad;
  final Set<String> _issuedDeploymentIds = {'DEP-120'};
  int _deploymentIdSequence = 0;
  bool _initialCreatePrefillHandled = false;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        InMemoryDeploymentRepository.withDemonstrationData();
    _controller = DeploymentController(
      repository: _repository,
      clock: () => _now,
    );
    _routeCatalogController = RouteCatalogController(
      widget.routeCatalogRepository ?? const BundledRouteCatalogRepository(),
    );
    _routeCatalogLoad = _routeCatalogController.loadCatalog();
    if (widget.initialCreatePrefill != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _initialCreatePrefillHandled) {
          return;
        }
        _initialCreatePrefillHandled = true;
        unawaited(
          _openCreateForm(context, prefill: widget.initialCreatePrefill),
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_routeCatalogController.state == RouteCatalogLoadState.loading) {
      unawaited(
        _routeCatalogLoad.whenComplete(_routeCatalogController.dispose),
      );
    } else {
      _routeCatalogController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DeploymentListScreen(
      controller: _controller,
      onCreateDeployment: () => _openCreateForm(context),
      onOpenDeployment: (deployment) =>
          _openDeploymentDetails(context, deployment.deploymentId),
      onEditLocalWork: (record) => _openLocalDraftForm(context, record),
      onPublishLocalWork: (record) => _publishLocalWork(context, record),
      onDiscardLocalWork: (record) => _discardLocalWork(context, record),
    );
  }

  Future<void> _openCreateForm(
    BuildContext context, {
    DeploymentPrefill? prefill,
  }) async {
    final saved = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (formContext) => DeploymentFormScreen(
          controller: _controller,
          routeCatalogController: _routeCatalogController,
          currentUserId: widget.currentUserId,
          deploymentIdGenerator: _nextDeploymentId,
          clock: () => _now,
          prefill: prefill,
          onSaved: (deployment) => Navigator.of(formContext).pop(deployment),
          onLocalSaved: (record) => Navigator.of(formContext).pop(record),
          onCancel: () => Navigator.of(formContext).pop(),
        ),
      ),
    );
    if (!mounted || saved == null) {
      return;
    }
    await _controller.loadDeployments();
  }

  Future<void> _openLocalDraftForm(
    BuildContext context,
    LocalDeploymentRecord record,
  ) async {
    final saved = await Navigator.of(context).push<LocalDeploymentRecord>(
      MaterialPageRoute<LocalDeploymentRecord>(
        builder: (formContext) => DeploymentFormScreen(
          controller: _controller,
          routeCatalogController: _routeCatalogController,
          currentUserId: widget.currentUserId,
          existingLocalWorkItem: record,
          clock: () => _now,
          onLocalSaved: (updated) => Navigator.of(formContext).pop(updated),
          onCancel: () => Navigator.of(formContext).pop(),
        ),
      ),
    );
    if (mounted && saved != null) {
      await _controller.loadDeployments();
    }
  }

  Future<void> _publishLocalWork(
    BuildContext context,
    LocalDeploymentRecord record,
  ) async {
    final published = await _controller.publishLocalDraft(record.localId);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          published
              ? 'Deployment published and confirmed by Supabase.'
              : _controller.errorMessage ?? 'Unable to publish deployment.',
        ),
      ),
    );
  }

  Future<void> _discardLocalWork(
    BuildContext context,
    LocalDeploymentRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard local draft?'),
        content: const Text(
          'This removes only the unpublished draft stored on this device. '
          'It does not delete any Supabase deployment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep draft'),
          ),
          FilledButton(
            key: const ValueKey('confirm-discard-local-draft'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _controller.discardLocalDraft(record.localId);
    }
  }

  Future<void> _openDeploymentDetails(
    BuildContext context,
    String deploymentId,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _DeploymentDetailPage(
          controller: _controller,
          routeCatalogController: _routeCatalogController,
          deploymentId: deploymentId,
          currentUserId: widget.currentUserId,
          clock: () => _now,
        ),
      ),
    );
    if (mounted) {
      await _controller.loadDeployments();
    }
  }

  String _nextDeploymentId() {
    while (true) {
      _deploymentIdSequence++;
      final generated =
          widget.deploymentIdGenerator?.call(_deploymentIdSequence) ??
          'DEP-${_now.microsecondsSinceEpoch}-'
              '${_deploymentIdSequence.toString().padLeft(3, '0')}';
      if (generated.startsWith('DEP-') &&
          generated.trim() == generated &&
          _issuedDeploymentIds.add(generated)) {
        return generated;
      }
      if (_deploymentIdSequence >= 10000) {
        throw StateError('Unable to generate a unique DEP- identifier.');
      }
    }
  }
}

class _DeploymentDetailPage extends StatefulWidget {
  const _DeploymentDetailPage({
    required this.controller,
    required this.routeCatalogController,
    required this.deploymentId,
    required this.currentUserId,
    required this.clock,
  });

  final DeploymentController controller;
  final RouteCatalogController routeCatalogController;
  final String deploymentId;
  final String currentUserId;
  final DateTime Function() clock;

  @override
  State<_DeploymentDetailPage> createState() => _DeploymentDetailPageState();
}

class _DeploymentDetailPageState extends State<_DeploymentDetailPage> {
  int _detailRevision = 0;

  @override
  Widget build(BuildContext context) {
    return DeploymentDetailScreen(
      key: ValueKey(
        'deployment-detail-${widget.deploymentId}-$_detailRevision',
      ),
      controller: widget.controller,
      deploymentId: widget.deploymentId,
      clock: widget.clock,
      onBack: () => Navigator.of(context).pop(),
      onEditDeployment: _openEditForm,
      onDeleted: () => Navigator.of(context).pop(),
    );
  }

  Future<void> _openEditForm(ServiceDeployment deployment) async {
    final saved = await Navigator.of(context).push<ServiceDeployment>(
      MaterialPageRoute<ServiceDeployment>(
        builder: (formContext) => DeploymentFormScreen(
          controller: widget.controller,
          routeCatalogController: widget.routeCatalogController,
          currentUserId: widget.currentUserId,
          existingDeployment: deployment,
          clock: widget.clock,
          onSaved: (updated) => Navigator.of(formContext).pop(updated),
          onCancel: () => Navigator.of(formContext).pop(),
        ),
      ),
    );
    if (!mounted || saved == null) {
      return;
    }
    setState(() {
      _detailRevision++;
    });
  }
}
