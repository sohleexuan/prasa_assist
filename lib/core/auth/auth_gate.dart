import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_loading_indicator.dart';
import 'auth_gateway.dart';
import 'staff_sign_in_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.authGateway,
    required this.authenticatedChild,
    super.key,
  });

  final AuthGateway authGateway;
  final Widget authenticatedChild;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthSession?>? _authSubscription;
  AuthSession? _session;
  Object? _authError;
  var _isLoading = true;
  var _receivedAuthEvent = false;

  @override
  void initState() {
    super.initState();
    _listenForAuthChanges();
  }

  @override
  void didUpdateWidget(AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.authGateway != oldWidget.authGateway) {
      _listenForAuthChanges();
    }
  }

  void _listenForAuthChanges() {
    unawaited(_authSubscription?.cancel());
    _receivedAuthEvent = false;
    _authError = null;
    _isLoading = true;

    _authSubscription = widget.authGateway.authStateChanges.listen(
      _handleAuthChange,
      onError: _handleAuthError,
    );
    unawaited(_restoreCurrentSession());
  }

  Future<void> _restoreCurrentSession() async {
    await Future<void>.value();
    if (!mounted || _receivedAuthEvent) {
      return;
    }

    setState(() {
      _session = widget.authGateway.currentSession;
      _isLoading = false;
    });
  }

  void _handleAuthChange(AuthSession? session) {
    if (!mounted) {
      return;
    }

    _receivedAuthEvent = true;
    setState(() {
      _session = session;
      _authError = null;
      _isLoading = false;
    });
  }

  void _handleAuthError(Object error, StackTrace stackTrace) {
    if (!mounted) {
      return;
    }

    setState(() {
      _authError = error;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppLoadingIndicator(message: 'Checking staff access'),
      );
    }

    if (_authError != null) {
      return Scaffold(
        body: AppErrorState(
          title: 'Unable to verify staff access',
          message: 'Check the connection and try again.',
          actionLabel: 'Try again',
          onAction: _listenForAuthChanges,
        ),
      );
    }

    if (_session == null) {
      return StaffSignInPage(authGateway: widget.authGateway);
    }

    return widget.authenticatedChild;
  }
}
