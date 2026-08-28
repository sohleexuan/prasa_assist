import 'dart:async';

import 'package:flutter/material.dart';

import '../core/auth/auth_gate.dart';
import '../core/dependencies/app_dependencies.dart';
import '../core/dependencies/app_dependencies_scope.dart';
import '../core/theme/app_theme.dart';
import 'prasa_assist_home_page.dart';

class PrasaAssistApp extends StatefulWidget {
  const PrasaAssistApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  State<PrasaAssistApp> createState() => _PrasaAssistAppState();
}

class _PrasaAssistAppState extends State<PrasaAssistApp> {
  @override
  void dispose() {
    unawaited(widget.dependencies.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDependenciesScope(
      dependencies: widget.dependencies,
      child: MaterialApp(
        title: 'PrasaAssist',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: AuthGate(
          authGateway: widget.dependencies.authGateway,
          authenticatedChild: const PrasaAssistHomePage(),
        ),
      ),
    );
  }
}
