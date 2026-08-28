import 'package:flutter/foundation.dart';

import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../models/incident_query.dart';
import '../repositories/incident_data_exception.dart';
import '../repositories/incident_repository.dart';
import '../repositories/incident_repository_capabilities.dart';
import '../repositories/incident_hybrid_operations.dart';
import '../data/dto/local_incident_draft.dart';
import '../models/local_incident_work_item.dart';
import 'incident_state.dart';

class IncidentController extends ChangeNotifier {
  factory IncidentController({required IncidentRepository repository}) {
    return IncidentController._(repository);
  }

  IncidentController._(this._repository);

  final IncidentRepository _repository;

  IncidentState _state = IncidentState.initial();
  var _operationRevision = 0;
  var _isDisposed = false;

  IncidentState get state => _state;

  List<Incident> get incidents => _state.incidents;

  Incident? get selectedIncident => _state.selectedIncident;

  bool get isLoading => _state.isLoading;

  String? get errorMessage => _state.errorMessage;
  List<LocalIncidentWorkItem> get localWorkItems => _state.localWorkItems;
  bool get supportsLocalDrafts => _repository is IncidentHybridOperations;

  IncidentRepositoryCapabilities get capabilities =>
      incidentCapabilitiesOf(_repository);

  Future<void> loadIncidents({IncidentQuery? query}) async {
    final effectiveQuery = query ?? _state.query;
    final revision = _beginOperation(
      _state.copyWith(
        status: IncidentStateStatus.loading,
        query: effectiveQuery,
        errorMessage: null,
      ),
    );

    try {
      final hybrid = _repository is IncidentHybridOperations
          ? _repository as IncidentHybridOperations
          : null;
      final result = hybrid == null
          ? null
          : await hybrid.getAllWithProvenance(query: effectiveQuery);
      final incidents =
          result?.data ?? await _repository.getAll(query: effectiveQuery);
      if (!_isCurrent(revision)) {
        return;
      }
      List<LocalIncidentWorkItem> localWorkItems = const [];
      if (hybrid != null) {
        try {
          localWorkItems = await hybrid.getLocalWorkItems();
        } catch (_) {
          // A valid authoritative or cached read remains usable if only the
          // optional local-draft list cannot be loaded.
        }
      }
      _emitList(
        incidents,
        query: effectiveQuery,
        listProvenance: result?.provenance,
        localWorkItems: localWorkItems,
      );
    } catch (error) {
      if (_isCurrent(revision)) {
        _emitError(error);
      }
    }
  }

  Future<void> updateQuery(IncidentQuery query) {
    return loadIncidents(query: query);
  }

  Future<Incident?> selectIncident(String incidentId) async {
    final revision = _beginOperation();
    try {
      final incident = await _repository.getById(incidentId);
      if (!_isCurrent(revision)) {
        return incident;
      }
      if (incident == null) {
        _emit(
          _state.copyWith(
            status: IncidentStateStatus.error,
            selectedIncident: null,
            errorMessage: 'Incident $incidentId does not exist.',
          ),
        );
        return null;
      }

      _emit(
        _state.copyWith(
          status: _contentStatus(_state.incidents),
          selectedIncident: incident,
          errorMessage: null,
        ),
      );
      return incident;
    } catch (error) {
      if (_isCurrent(revision)) {
        _emitError(error);
      }
      return null;
    }
  }

  Future<bool> createIncident(Incident incident) {
    return _runMutation(() async {
      final created = await _repository.create(incident);
      return created;
    });
  }

  Future<bool> createLocalDraft(LocalIncidentDraft draft) async {
    final hybrid = _repository is IncidentHybridOperations
        ? _repository as IncidentHybridOperations
        : null;
    if (hybrid == null) return false;
    try {
      await hybrid.createLocalDraft(draft);
      await loadIncidents();
      return true;
    } catch (error) {
      _emitError(error);
      return false;
    }
  }

  Future<bool> publishLocalDraft(String localId) async {
    final hybrid = _repository is IncidentHybridOperations
        ? _repository as IncidentHybridOperations
        : null;
    if (hybrid == null) return false;
    try {
      await hybrid.publishLocalDraft(localId);
      await loadIncidents();
      return true;
    } catch (error) {
      _emitError(error);
      return false;
    }
  }

  Future<bool> discardLocalDraft(String localId) async {
    final hybrid = _repository is IncidentHybridOperations
        ? _repository as IncidentHybridOperations
        : null;
    if (hybrid == null) return false;
    try {
      await hybrid.discardLocalDraft(localId);
      await loadIncidents();
      return true;
    } catch (error) {
      _emitError(error);
      return false;
    }
  }

  Future<bool> updateIncident(Incident incident) {
    return _runMutation(() async {
      final updated = await _repository.update(incident);
      return updated;
    });
  }

  Future<bool> changeStatus(
    String incidentId,
    IncidentStatus targetStatus, {
    required String changedBy,
    String? note,
  }) {
    return _runMutation(() async {
      final updated = await _repository.transitionStatus(
        incidentId,
        targetStatus,
        changedBy: changedBy,
        note: note,
      );
      return updated;
    });
  }

  Future<bool> deleteIncident(String incidentId) async {
    final revision = _beginOperation();
    try {
      await _repository.delete(incidentId);
      final normalizedId = incidentId.trim().toLowerCase();
      final selectedId = _state.selectedIncident?.incidentId
          .trim()
          .toLowerCase();
      final incidents = await _repository.getAll(query: _state.query);
      if (!_isCurrent(revision)) {
        return true;
      }
      _emitList(
        incidents,
        selectedIncident: selectedId == normalizedId
            ? null
            : _state.selectedIncident,
      );
      return true;
    } catch (error) {
      if (_isCurrent(revision)) {
        _emitError(error);
      }
      return false;
    }
  }

  void clearSelection() {
    _operationRevision++;
    _emit(_state.copyWith(selectedIncident: null));
  }

  void clearError() {
    if (_state.errorMessage == null) {
      return;
    }
    _emit(
      _state.copyWith(
        status: _contentStatus(_state.incidents),
        errorMessage: null,
      ),
    );
  }

  Future<bool> _runMutation(Future<Incident> Function() operation) async {
    final revision = _beginOperation();
    try {
      final selectedIncident = await operation();
      final incidents = await _repository.getAll(query: _state.query);
      if (!_isCurrent(revision)) {
        return true;
      }
      _emitList(incidents, selectedIncident: selectedIncident);
      return true;
    } catch (error) {
      if (_isCurrent(revision)) {
        _emitError(error);
      }
      return false;
    }
  }

  int _beginOperation([IncidentState? loadingState]) {
    final revision = ++_operationRevision;
    _emit(
      loadingState ??
          _state.copyWith(
            status: IncidentStateStatus.loading,
            errorMessage: null,
          ),
    );
    return revision;
  }

  bool _isCurrent(int revision) =>
      !_isDisposed && revision == _operationRevision;

  void _emitList(
    List<Incident> incidents, {
    IncidentQuery? query,
    Object? selectedIncident = _selectionNotProvided,
    Object? listProvenance = _selectionNotProvided,
    List<LocalIncidentWorkItem>? localWorkItems,
  }) {
    _emit(
      _state.copyWith(
        status: _contentStatus(incidents),
        incidents: incidents,
        query: query,
        selectedIncident: identical(selectedIncident, _selectionNotProvided)
            ? _state.selectedIncident
            : selectedIncident,
        errorMessage: null,
        listProvenance: identical(listProvenance, _selectionNotProvided)
            ? _state.listProvenance
            : listProvenance,
        localWorkItems: localWorkItems,
      ),
    );
  }

  void _emitError(Object error) {
    _emit(
      _state.copyWith(
        status: IncidentStateStatus.error,
        errorMessage: _readableError(error),
      ),
    );
  }

  void _emit(IncidentState nextState) {
    if (_isDisposed) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _operationRevision++;
    super.dispose();
  }

  static IncidentStateStatus _contentStatus(List<Incident> incidents) {
    return incidents.isEmpty
        ? IncidentStateStatus.empty
        : IncidentStateStatus.loaded;
  }

  static String _readableError(Object error) {
    if (error is IncidentDataException) {
      return error.message;
    }
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Invalid incident data.';
    }
    if (error is StateError) {
      return error.message;
    }
    return 'Unable to complete the incident operation.';
  }

  static const Object _selectionNotProvided = Object();
}
