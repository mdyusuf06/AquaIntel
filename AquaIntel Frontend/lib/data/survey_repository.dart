import '../models/survey.dart';
import 'api_client.dart';

// ── Abstract interface ────────────────────────────────────────────────────────
abstract class SurveyRepository {
  Future<List<Survey>> getAll();
  Future<Survey?> getActive();
  Future<List<Vessel>> getVessels();
  Future<void> update(Survey updated);
}

// ── HTTP implementation (talks to FastAPI /api/v1/surveys) ───────────────────
class ApiSurveyRepository implements SurveyRepository {
  @override
  Future<List<Survey>> getAll() async {
    final res = await ApiClient.instance.get('/api/v1/surveys');
    final list = res.data as List<dynamic>;
    return list.map((j) => Survey.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<Survey?> getActive() async {
    final all = await getAll();
    try {
      return all.firstWhere((s) => s.status == 'in_progress');
    } catch (_) {
      return null;
    }
  }

  /// Vessels come from a static list for now — no backend endpoint yet.
  @override
  Future<List<Vessel>> getVessels() async => _staticVessels;

  @override
  Future<void> update(Survey updated) async {
    try {
      await ApiClient.instance.patch('/api/v1/surveys/${updated.id}', data: {
        'baseLat': updated.baseLat,
        'baseLon': updated.baseLon,
      });
    } catch (_) {
      // Ignore if backend doesn't support it yet
    }
  }
}

// Static vessel list (no backend endpoint — replace with API call when ready)
final _staticVessels = [
  Vessel(id: 'AUV-01', name: 'AquaScout Alpha', type: 'AUV', syncStatus: 'synced',  lastSync: DateTime.now().subtract(const Duration(minutes: 3))),
  Vessel(id: 'USV-01', name: 'SeaMapper Bravo', type: 'USV', syncStatus: 'pending', lastSync: DateTime.now().subtract(const Duration(hours: 2))),
  Vessel(id: 'ROV-01', name: 'DeepEye Charlie',  type: 'ROV', syncStatus: 'synced',  lastSync: DateTime.now().subtract(const Duration(minutes: 45))),
  Vessel(id: 'AUV-02', name: 'Triton Delta',     type: 'AUV', syncStatus: 'pending', lastSync: DateTime.now().subtract(const Duration(hours: 5))),
];
