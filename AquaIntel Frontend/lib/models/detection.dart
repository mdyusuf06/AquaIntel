class Detection {
  final String id;
  final String type;
  final double lat;
  final double lon;
  final double heightM;
  final double clearanceM;
  final double confidence;
  final String riskTier; // red, amber, green
  final DateTime detectedAt;
  final String? operatorLabel;
  final String? impactType;
  final String? impactSeverity;

  const Detection({
    required this.id,
    required this.type,
    required this.lat,
    required this.lon,
    required this.heightM,
    required this.clearanceM,
    required this.confidence,
    required this.riskTier,
    required this.detectedAt,
    this.operatorLabel,
    this.impactType,
    this.impactSeverity,
  });

  factory Detection.fromJson(Map<String, dynamic> j) {
    return Detection(
      id: j['id']?.toString() ?? 'local-${DateTime.now().millisecondsSinceEpoch}',
      type: (j['class'] ?? j['type'] ?? j['object_type'] ?? 'Unknown').toString(),
      lat: (j['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (j['lon'] as num?)?.toDouble() ?? 0.0,
      heightM: (j['height_m'] as num?)?.toDouble() ?? 0.0,
      clearanceM: ((j['depth_clearance_m'] as num?) ?? (j['clearance_m'] as num?) ?? 0.0).toDouble(),
      confidence: (j['similarity_pct'] != null) 
          ? ((j['similarity_pct'] as num).toDouble() / 100.0) 
          : ((j['confidence'] as num?) ?? 0.0).toDouble(),
      riskTier: (j['risk_tier']?.toString() ?? 'unknown').toLowerCase(),
      detectedAt: j['detected_at'] != null
          ? DateTime.tryParse(j['detected_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      operatorLabel: j['operator_label']?.toString(),
      impactType: (j['impact_profile'] != null && j['impact_profile'] is Map) 
          ? j['impact_profile']['impact_type']?.toString() 
          : j['impact_type']?.toString(),
      impactSeverity: (j['impact_profile'] != null && j['impact_profile'] is Map) 
          ? j['impact_profile']['impact_severity']?.toString() 
          : j['impact_severity']?.toString(),
    );
  }

  String get displayType =>
      type.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  Detection copyWith({String? riskTier, double? confidence, String? operatorLabel, String? impactType, String? impactSeverity}) =>
      Detection(
        id: id, type: type, lat: lat, lon: lon,
        heightM: heightM, clearanceM: clearanceM,
        confidence: confidence ?? this.confidence,
        riskTier: riskTier ?? this.riskTier,
        detectedAt: detectedAt,
        operatorLabel: operatorLabel ?? this.operatorLabel,
        impactType: impactType ?? this.impactType,
        impactSeverity: impactSeverity ?? this.impactSeverity,
      );
}
