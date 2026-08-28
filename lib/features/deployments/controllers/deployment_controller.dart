import 'package:flutter/foundation.dart';

import '../data/dto/local_deployment_draft.dart';
import '../data/dto/local_deployment_record.dart';
import '../models/deployment_read_result.dart';
import '../models/deployment_status.dart';
import '../models/service_deployment.dart';
import '../repositories/deployment_data_exception.dart';
import '../repositories/deployment_hybrid_operations.dart';
import '../repositories/deployment_repository.dart';
import '../repositories/deployment_repository_capabilities.dart';

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
  List<LocalDeploymentRecord> _localWorkItems = const [];
  ServiceDeployment? _selectedDeployment;
  LocalDeploymentRecord? _selectedLocalWorkItem;
  DeploymentReadProvenance? _listProvenance;
  DeploymentReadProvenance? _detailProvenance;
  bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _publishingLocalIds = <String>{};

  List<ServiceDeployment> get deployments =>
      List<ServiceDeployment>.unmodifiable(_deployments);

  ServiceDeployment? get selectedDeployment => _selectedDeployment;

  List<LocalDeploymentRecord> get localWorkItems =>
      List<LocalDeploymentRecord>.unmodifiable(_localWorkItems);

  LocalDeploymentRecord? get selectedLocalWorkItem => _selectedLocalWorkItem;

  DeploymentReadProvenance? get listProvenance => _listProvenance;

  DeploymentReadProvenance? get detailProvenance => _detailProvenance;

  bool get supportsLocalDrafts => _hybridOperations != null;

  bool isPublishingLocalDraft(String localId) =>
      _publishingLocalIds.contains(localId);

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  DeploymentRepositoryCapabilities get capabilities =>
      deploymentCapabilitiesOf(_repository);

  Future<void> loadDeployments() async {
    _beginOperation();
    try {
      await _loadConfirmedDeployments();
    } catch (error) {
      _errorMessage = _readableError(error);
    } finally {
      await _loadLocalWorkSafely();
      _endOperation();
    }
  }

  Future<ServiceDeployment?> getDeploymentById(String deploymentId) async {
    _beginOperation();
    try {
      final hybrid = _hybridOperations;
      if (hybrid == null) {
        _selectedDeployment = await _repository.getById(deploymentId);
        _detailProvenance = null;
      } else {
        final result = await hybrid.getByIdWithProvenance(deploymentId);
        _selectedDeployment = result.data;
        _detailProvenance = result.provenance;
      }
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
      _selectedDeployment = await _repository.create(deployment);
    });
  }

  Future<bool> updateDeployment(ServiceDeployment deployment) async {
    return _runMutation(() async {
      _selectedDeployment = await _repository.update(deployment);
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
    String? changedByLabel,
  }) async {
    return _runMutation(() async {
      final actorLabel = changedByLabel?.trim().isNotEmpty == true
          ? changedByLabel!.trim()
          : _selectedDeployment?.createdBy ?? 'Operations Staff';
      _selectedDeployment = await _repository.transitionStatus(
        deploymentId,
        nextStatus,
        changedByLabel: actorLabel,
        changedAt: updatedAt ?? _clock(),
      );
    });
  }

  Future<bool> createLocalDraft(LocalDeploymentDraft draft) {
    return _runLocalMutation((hybrid) async {
      _selectedLocalWorkItem = await hybrid.createLocalDraft(draft);
    });
  }

  Future<bool> updateLocalDraft(String localId, LocalDeploymentDraft draft) {
    return _runLocalMutation((hybrid) async {
      _selectedLocalWorkItem = await hybrid.updateLocalDraft(localId, draft);
    });
  }

  Future<bool> discardLocalDraft(String localId) {
    return _runLocalMutation((hybrid) async {
      await hybrid.discardLocalDraft(localId);
      if (_selectedLocalWorkItem?.localId == localId) {
        _selectedLocalWorkItem = null;
      }
    });
  }

  Future<bool> publishLocalDraft(String localId) async {
    if (!_publishingLocalIds.add(localId)) {
      return false;
    }
    try {
      return await _runLocalMutation((hybrid) async {
        _selectedDeployment = await hybrid.publishLocalDraft(localId);
        _selectedLocalWorkItem = null;
        _upsertSelectedDeployment();
        _listProvenance = DeploymentReadProvenance(
          source: DeploymentReadSource.liveSupabase,
          retrievedAtUtc: _clock(),
        );
      });
    } finally {
      _publishingLocalIds.remove(localId);
      notifyListeners();
    }
  }

  Future<bool> _runMutation(Future<void> Function() operation) async {
    _beginOperation();
    try {
      await operation();
      await _loadConfirmedDeployments();
      await _loadLocalWorkSafely();
      return true;
    } catch (error) {
      _errorMessage = _readableError(error);
      return false;
    } finally {
      _endOperation();
    }
  }

  Future<bool> _runLocalMutation(
    Future<void> Function(DeploymentHybridOperations hybrid) operation,
  ) async {
    final hybrid = _hybridOperations;
    if (hybrid == null) {
      _errorMessage = 'Local deployment work is unavailable.';
      notifyListeners();
      return false;
    }
    _beginOperation();
    try {
      await operation(hybrid);
      await _loadLocalWorkSafely();
      return true;
    } catch (error) {
      _errorMessage = _readableError(error);
      await _loadLocalWorkSafely();
      return false;
    } finally {
      _endOperation();
    }
  }

  void _upsertSelectedDeployment() {
    final selected = _selectedDeployment;
    if (selected == null) {
      return;
    }
    _deployments = List<ServiceDeployment>.unmodifiable(
      [
        for (final deployment in _deployments)
          if (deployment.deploymentId != selected.deploymentId) deployment,
        selected,
      ]..sort((first, second) => first.startTime.compareTo(second.startTime)),
    );
  }

  DeploymentHybridOperations? get _hybridOperations {
    final repository = _repository;
    return repository is DeploymentHybridOperations
        ? repository as DeploymentHybridOperations
        : null;
  }

  Future<void> _loadConfirmedDeployments() async {
    final hybrid = _hybridOperations;
    if (hybrid == null) {
      _deployments = await _repository.getAll();
      _listProvenance = null;
      return;
    }
    final result = await hybrid.getAllWithProvenance();
    _deployments = result.data;
    _listProvenance = result.provenance;
  }

  Future<void> _loadLocalWorkSafely() async {
    final hybrid = _hybridOperations;
    if (hybrid == null) {
      _localWorkItems = const [];
      return;
    }
    try {
      _localWorkItems = await hybrid.getLocalWorkItems();
    } catch (error) {
      _localWorkItems = const [];
      _errorMessage ??= _readableError(error);
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
    if (error is DeploymentDataException) {
      return error.message;
    }
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Invalid deployment data.';
    }
    if (error is StateError) {
      return _hybridOperations == null
          ? error.message
          : 'Unable to complete the deployment operation.';
    }
    return 'Unable to complete the deployment operation.';
  }
}
