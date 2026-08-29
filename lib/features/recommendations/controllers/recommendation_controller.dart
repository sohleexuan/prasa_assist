import 'package:flutter/foundation.dart';

import '../data/dto/recommendation_record_dto.dart';
import '../repositories/recommendation_data_exception.dart';
import '../repositories/recommendation_repository.dart';

class RecommendationController extends ChangeNotifier {
  RecommendationController(this._repository);
  final RecommendationRepository _repository;
  List<RecommendationRecordDto> _records = const [];
  bool _loading = false;
  final Set<String> _busy = {};
  String? _error;

  List<RecommendationRecordDto> get records => List.unmodifiable(_records);
  bool get isLoading => _loading;
  String? get errorMessage => _error;
  bool isBusy(String id) => _busy.contains(id);
  RecommendationRecordDto? find(String id) {
    for (final record in _records) {
      if (record.recommendation.id == id) return record;
    }
    return null;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _records = await _repository.readAll();
    } on RecommendationDataException catch (error) {
      _error = error.safeMessage;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> decide(String id, String decision, {String? note}) =>
      _operate(id, () async {
        final current = find(id);
        if (current == null) throw StateError('Recommendation not found.');
        final updated = await _repository.decide(
          id,
          decision: decision,
          note: note,
          expectedVersion: current.recommendation.remoteVersion,
        );
        _replace(updated);
      });

  Future<void> generateAnalysis(String id) => _operate(id, () async {
    final updated = await _repository.generateAnalysis(id);
    _replace(updated);
  });

  Future<void> _operate(String id, Future<void> Function() operation) async {
    if (!_busy.add(id)) return;
    _error = null;
    notifyListeners();
    try {
      await operation();
    } on RecommendationDataException catch (error) {
      _error = error.safeMessage;
    } finally {
      _busy.remove(id);
      notifyListeners();
    }
  }

  void _replace(RecommendationRecordDto record) {
    _records = [
      for (final current in _records)
        if (current.recommendation.id == record.recommendation.id)
          record
        else
          current,
    ];
  }
}
