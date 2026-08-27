import 'package:flutter/material.dart';

import 'controllers/deployment_controller.dart';
import 'models/service_deployment.dart';
import 'repositories/in_memory_deployment_repository.dart';
import 'screens/deployment_detail_screen.dart';
import 'screens/deployment_form_screen.dart';
import 'screens/deployment_list_screen.dart';

void main() {
  runApp(const DeploymentDemoApp());
}

/// Feature-local application harness for demonstrating Module 3 independently.
///
/// Data is intentionally in-memory and is recreated whenever this app restarts.
class DeploymentDemoApp extends StatefulWidget {
  const DeploymentDemoApp({this.clock, this.deploymentIdGenerator, super.key});

  final DateTime Function()? clock;
  final String Function(int sequence)? deploymentIdGenerator;

  @override
  State<DeploymentDemoApp> createState() => _DeploymentDemoAppState();
}

class _DeploymentDemoAppState extends State<DeploymentDemoApp> {
  static const _prototypeUserId = 'demo-operations-staff';

  late final InMemoryDeploymentRepository _repository;
  late final DeploymentController _controller;
  final Set<String> _issuedDeploymentIds = {'DEP-120'};
  int _deploymentIdSequence = 0;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _repository = InMemoryDeploymentRepository.withDemonstrationData();
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
    const navy = Color(0xFF17203A);
    const purple = Color(0xFF6D4AFF);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: purple,
      brightness: Brightness.light,
      surface: const Color(0xFFFFFFFF),
    );

    return MaterialApp(
      title: 'PrasaAssist — Service Deployment',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(backgroundColor: purple),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: purple,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: Builder(
        builder: (context) => _DemoHomePage(
          child: DeploymentListScreen(
            controller: _controller,
            onCreateDeployment: () => _openCreateForm(context),
            onOpenDeployment: (deployment) =>
                _openDeploymentDetails(context, deployment.deploymentId),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateForm(BuildContext context) async {
    final saved = await Navigator.of(context).push<ServiceDeployment>(
      MaterialPageRoute<ServiceDeployment>(
        builder: (formContext) => DeploymentFormScreen(
          controller: _controller,
          currentUserId: _prototypeUserId,
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
        builder: (_) => _DemoDeploymentDetailPage(
          controller: _controller,
          deploymentId: deploymentId,
          currentUserId: _prototypeUserId,
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

class _DemoDeploymentDetailPage extends StatefulWidget {
  const _DemoDeploymentDetailPage({
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
  State<_DemoDeploymentDetailPage> createState() =>
      _DemoDeploymentDetailPageState();
}

class _DemoDeploymentDetailPageState extends State<_DemoDeploymentDetailPage> {
  int _detailRevision = 0;

  @override
  Widget build(BuildContext context) {
    return DeploymentDetailScreen(
      key: ValueKey('demo-detail-${widget.deploymentId}-$_detailRevision'),
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
      // Recreate the detail screen so its single initial load reads the edit.
      _detailRevision++;
    });
  }
}

class _DemoHomePage extends StatelessWidget {
  const _DemoHomePage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF17203A),
      child: Column(
        children: [
          const SafeArea(bottom: false, child: _DemoNotice()),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('module-3-demo-notice'),
      container: true,
      label:
          'Module 3 prototype. In-memory demonstration data. Changes reset '
          'when the app restarts. Not connected to live operations. '
          'Prototype user demo-operations-staff, not authenticated.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        color: const Color(0xFF17203A),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  color: Color(0xFFB9AAFF),
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Module 3 Prototype',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 5),
            Text(
              'In-memory demonstration data • Changes reset when the app restarts',
              style: TextStyle(color: Color(0xFFD8DCEB), fontSize: 12),
            ),
            SizedBox(height: 2),
            Text(
              'Not connected to live operations',
              style: TextStyle(
                color: Color(0xFFFFD7A3),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Prototype user: demo-operations-staff (not authenticated)',
              style: TextStyle(color: Color(0xFFD8DCEB), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
