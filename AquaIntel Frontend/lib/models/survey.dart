class Survey {
  final String id;
  final String name;
  final String status; // in_progress, complete
  final double areaKm2;
  final double progressPct;
  final int targetCount;
  final int redAlertCount;
  final double avgConfidence;
  final double baseLat;
  final double baseLon;

  const Survey({
    required this.id,
    required this.name,
    required this.status,
    required this.areaKm2,
    required this.progressPct,
    required this.targetCount,
    required this.redAlertCount,
    required this.avgConfidence,
    this.baseLat = 0.0,
    this.baseLon  = 0.0,
  });

  factory Survey.fromJson(Map<String, dynamic> j) => Survey(
    id:             j['id'] as String,
    name:           j['name'] as String,
    status:         j['status'] as String,
    areaKm2:        (j['area_km2'] as num).toDouble(),
    progressPct:    (j['progress_pct'] as num).toDouble(),
    targetCount:    (j['target_count'] as num).toInt(),
    redAlertCount:  (j['red_alert_count'] as num).toInt(),
    avgConfidence:  (j['avg_confidence'] as num).toDouble(),
    baseLat:        (j['base_lat'] as num?)?.toDouble() ?? 0.0,
    baseLon:        (j['base_lon'] as num?)?.toDouble() ?? 0.0,
  );
}

class Vessel {
  final String id;
  final String name;
  final String type;
  final String syncStatus;
  final DateTime lastSync;

  const Vessel({
    required this.id,
    required this.name,
    required this.type,
    required this.syncStatus,
    required this.lastSync,
  });
}
