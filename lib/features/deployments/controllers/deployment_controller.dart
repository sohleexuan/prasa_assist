import 'package:flutter/foundation.dart';

import '../models/deployment_status.dart';
import '../models/service_deployment.dart';
import '../repositories/deployment_repository.dart';

class DeploymentController extends ChangeNotifier {
  factory DeploymentController({
    required DeploymentRepository repository,
    DateTime Function()? clock,
  }) {
    return DeploymentController._(repository, clock ?? DateTime.now);
  }

  DeploymentController._(this._repository, this._clock);

  final DeploymentRepository _repository;
  final DateTime Function() _clock;

  List<ServiceDeployment> _deployments = const [];
  ServiceDeployment? _selectedDeployment;
  bool _isLoading = false;
  String? _errorMessage;

  List<ServiceDeployment> get deployments =>
      List<ServiceDeployment>.unmodifiable(_deployments);

  ServiceDeployment? get selectedDeployment => _selectedDeployment;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  Future<void> loadDeployments() async {
    _beginOperation();
    try {
      _deployments = await _repository.getAll();
    } catch (error) {
      _errorMessage = _readableError(error);
    } finally {
      _endOperation();
    }
  }

  Future<ServiceDeployment?> getDeploymentById(String deploymentId) async {
    _beginOperation();
    try {
      _selectedDeployment = await _repository.getById(deploymentId);
      if (_selectedDeployment == null) {
        _errorMessage = 'Deployment $deploymentId does not exist.';
      }
      return _selectedDeployment;
    } catch (error) {
      _errorMessage = _readableError(error);
      return null;
    } finally {
      _endOperation();
    }
  }

  Future<bool> createDeployment(ServiceDeployment deployment) async {
    return _runMutation(() async {
      await _repository.create(deployment);
      _selectedDeployment = deployment.copyWith();
    });
  }

  Future<bool> updateDeployment(ServiceDeployment deployment) async {
    return _runMutation(() async {
      await _repository.update(deployment);
      _selectedDeployment = deployment.copyWith();
    });
  }

  Future<bool> deleteDeployment(String deploymentId) async {
    return _runMutation(() async {
      await _repository.delete(deploymentId);
      if (_selectedDeployment?.deploymentId == deploymentId) {
        _selectedDeployment = null;
      }
    });
  }

  Future<bool> changeStatus(
    String deploymentId,
    DeploymentStatus nextStatus, {
    DateTime? updatedAt,
  }) async {
    return _runMutation(() async {
      final deployment = await _repository.getById(deploymentId);
      if (deployment == null) {
        throw StateError('Deployment $deploymentId does not exist.');
      }
      if (!deployment.status.canTransitionTo(nextStatus)) {
        throw StateError(
          'Cannot change deployment status from '
          '${deployment.status.displayLabel} to ${nextStatus.displayLabel}.',
        );
      }

      final updatedDeployment = deployment.copyWith(
        status: nextStatus,
        updatedAt: updatedAt ?? _clock(),
      );
      await _repository.update(updatedDeployment);
      _selectedDeployment = updatedDeployment;
    });
  }

  Future<bool> _runMutation(Future<void> Function() operation) async {
    _beginOperation();
    try {
      await operation();
      _deployments = await _repository.getAll();
      return true;
    } catch (error) {
      _errorMessage = _readableError(error);
      return false;
    } finally {
      _endOperation();
    }
  }

  void _beginOperation() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
  }

  void _endOperation() {
    _isLoading = false;
    notifyListeners();
  }

  String _readableError(Object error) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Invalid deployment data.';
    }
    if (error is StateError) {
      return error.message;
    }
    return error.toString();
  }
}
