import 'package:flutter/material.dart';
import '../models/detection.dart';
import '../models/load_state.dart';
import '../data/detection_repository.dart';

class DetectionProvider extends ChangeNotifier {
  final DetectionRepository _repo;

  DetectionProvider(this._repo);

  List<Detection> _detections = [];
  LoadState _state = LoadState.idle;
  String _error    = '';
  String _riskFilter = 'all';
  String _typeFilter = 'all';

  List<Detection> get allDetections  => List.unmodifiable(_detections);
  LoadState       get state          => _state;
  String          get errorMessage   => _error;
  String          get riskFilter     => _riskFilter;
  String          get typeFilter     => _typeFilter;
  bool            get isLoading      => _state == LoadState.loading;

  List<Detection> get filteredDetections {
    var list = _detections;
    if (_riskFilter != 'all') list = list.where((d) => d.riskTier == _riskFilter).toList();
    if (_typeFilter != 'all') list = list.where((d) => d.type == _typeFilter).toList();
    return list;
  }

  Detection? getById(String id) {
    try { return _detections.firstWhere((d) => d.id == id); }
    catch (_) { return null; }
  }

  Future<void> load({String? surveyId}) async {
    _state = LoadState.loading;
    _error = '';
    notifyListeners();
    try {
      _detections = await _repo.getAll(surveyId: surveyId);
      _state = LoadState.idle;
    } catch (e) {
      _state = LoadState.error;
      _error = e.toString();
    }
    notifyListeners();
  }

  void setRiskFilter(String tier) { _riskFilter = tier; notifyListeners(); }
  void setTypeFilter(String type) { _typeFilter = type; notifyListeners(); }

  void verify(String id) => _updateTier(id, 'green');
  void reject(String id) => _updateTier(id, 'red');
  void markUncertain(String id) => _updateTier(id, 'amber');

  void relabel(String id, String newLabel) {
    final d = getById(id);
    if (d != null) {
      final idx = _detections.indexWhere((x) => x.id == id);
      if (idx >= 0) {
        _detections[idx] = d.copyWith(operatorLabel: newLabel);
        _repo.update(_detections[idx]);
        notifyListeners();
      }
    }
  }

  void _updateTier(String id, String tier) {
    final idx = _detections.indexWhere((d) => d.id == id);
    if (idx >= 0) {
      _detections[idx] = _detections[idx].copyWith(riskTier: tier);
      _repo.update(_detections[idx]);
      notifyListeners();
    }
  }
}
