import 'package:flutter/material.dart';

import 'controllers/deployment_controller.dart';
import 'models/service_deployment.dart';
import 'repositories/deployment_repository.dart';
import 'repositories/in_memory_deployment_repository.dart';
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
    this.currentUserId = prototypeUserId,
    this.clock,
    this.deploymentIdGenerator,
    super.key,
  });

  static const String prototypeUserId = 'demo-operations-staff';

  final DeploymentRepository? repository;
  final String currentUserId;
  final DateTime Function()? clock;
  final String Function(int sequence)? deploymentIdGenerator;

  @override
  State<ServiceDeploymentPage> createState() => _ServiceDeploymentPageState();
}

class _ServiceDeploymentPageState extends State<ServiceDeploymentPage> {
  late final DeploymentRepository _repository;
  late final DeploymentController _controller;
  final Set<String> _issuedDeploymentIds = {'DEP-120'};
  int _deploymentIdSequence = 0;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DeploymentListScreen(
      controller: _controller,
      onCreateDeployment: () => _openCreateForm(context),
      onOpenDeployment: (deployment) =>
          _openDeploymentDetails(context, deployment.deploymentId),
    );
  }

  Future<void> _openCreateForm(BuildContext context) async {
    final saved = await Navigator.of(context).push<ServiceDeployment>(
      MaterialPageRoute<ServiceDeployment>(
        builder: (formContext) => DeploymentFormScreen(
          controller: _controller,
          currentUserId: widget.currentUserId,
          deploymentIdGenerator: _nextDeploymentId,
          clock: () => _now,
          onSaved: (deployment) => Navigator.of(formContext).pop(deployment),
          onCancel: () => Navigator.of(formContext).pop(),
        ),
      ),
    );
    if (!mounted || saved == null) {
      return;
    }
    await _controller.loadDeployments();
  }

  Future<void> _openDeploymentDetails(
    BuildContext context,
    String deploymentId,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _DeploymentDetailPage(
          controller: _controller,
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
    required this.deploymentId,
    required this.currentUserId,
    required this.clock,
  });

  final DeploymentController controller;
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
