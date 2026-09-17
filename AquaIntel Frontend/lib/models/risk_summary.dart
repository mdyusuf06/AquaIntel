import '../models/detection.dart';

class RiskSummary {
  final int redCount;
  final int amberCount;
  final int greenCount;
  final double avgConfidence;
  final int totalDetections;
  final List<RiskTrendPoint> trend; // last 7 days
  final List<Detection> priorityList; // sorted by risk score

  const RiskSummary({
    required this.redCount,
    required this.amberCount,
    required this.greenCount,
    required this.avgConfidence,
    required this.totalDetections,
    required this.trend,
    required this.priorityList,
  });

  factory RiskSummary.fromDetections(List<Detection> detections) {
    final reds   = detections.where((d) => d.riskTier == 'red').toList();
    final ambers = detections.where((d) => d.riskTier == 'amber').toList();
    final greens = detections.where((d) => d.riskTier == 'green').toList();

    final avgConf = detections.isEmpty
        ? 0.0
        : detections.map((d) => d.confidence).reduce((a, b) => a + b) / detections.length;

    // Sort priority: red first, then by clearance ascending (most hazardous on top)
    final sorted = [...detections]..sort((a, b) {
        const order = {'red': 0, 'amber': 1, 'green': 2};
        final tierCmp = (order[a.riskTier] ?? 3).compareTo(order[b.riskTier] ?? 3);
        if (tierCmp != 0) return tierCmp;
        return a.clearanceM.compareTo(b.clearanceM);
      });

    // Fake 7-day trend from existing data
    final now = DateTime.now();
    final trend = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final dayDets = detections.where((d) =>
        d.detectedAt.year  == day.year &&
        d.detectedAt.month == day.month &&
        d.detectedAt.day   == day.day
      ).toList();
      return RiskTrendPoint(
        date:     day,
        redCount: dayDets.where((d) => d.riskTier == 'red').length,
        total:    dayDets.length,
      );
    });

    return RiskSummary(
      redCount:       reds.length,
      amberCount:     ambers.length,
      greenCount:     greens.length,
      avgConfidence:  avgConf,
      totalDetections: detections.length,
      trend:          trend,
      priorityList:   sorted.take(10).toList(),
    );
  }
}

class RiskTrendPoint {
  final DateTime date;
  final int redCount;
  final int total;
  const RiskTrendPoint({required this.date, required this.redCount, required this.total});
}
