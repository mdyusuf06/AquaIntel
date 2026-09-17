import '../models/detection.dart';
import 'api_client.dart';

// ── Abstract interface ────────────────────────────────────────────────────────
abstract class DetectionRepository {
  Future<List<Detection>> getAll({String? surveyId});
  Future<Detection?> getById(String id);
  Future<void> update(Detection updated);
}

// ── HTTP implementation (talks to FastAPI /api/v1/detections) ────────────────
class ApiDetectionRepository implements DetectionRepository {
  final List<Detection> _cache = [];

  @override
  Future<List<Detection>> getAll({String? surveyId}) async {
    final query = surveyId != null ? '?survey_id=$surveyId' : '';
    final res  = await ApiClient.instance.get('/api/v1/detections$query');
    final list = res.data as List<dynamic>;
    _cache
      ..clear()
      ..addAll(list.map((j) => Detection.fromJson(j as Map<String, dynamic>)));
    return List.unmodifiable(_cache);
  }

  @override
  Future<Detection?> getById(String id) async {
    // Try cache first
    try {
      return _cache.firstWhere((d) => d.id == id);
    } catch (_) {}
    // Fallback: refresh from API
    await getAll();
    try {
      return _cache.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Local optimistic update — a real backend would have PATCH /detections/:id
  @override
  Future<void> update(Detection updated) async {
    final idx = _cache.indexWhere((d) => d.id == updated.id);
    if (idx >= 0) _cache[idx] = updated;
  }
}
