enum NotificationSeverity { critical, info, success, warning }

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationSeverity severity;
  final bool isRead;
  final String? actionRoute;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.severity,
    this.isRead      = false,
    this.actionRoute,
  });

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
    id:           id,
    title:        title,
    body:         body,
    timestamp:    timestamp,
    severity:     severity,
    isRead:       isRead ?? this.isRead,
    actionRoute:  actionRoute,
  );

  String get group {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (severity == NotificationSeverity.critical) return 'Critical';
    if (diff.inHours < 24) return 'Today';
    return 'Earlier';
  }

  static List<NotificationItem> get mockData => [
    NotificationItem(id: 'n1', title: '🔴 Ghost Net Near Vessel', body: 'Target T-003 detected 0.3 nautical miles from FV-Horizon. Clearance: 2.1m. Immediate action required.', timestamp: DateTime.now().subtract(const Duration(minutes: 4)), severity: NotificationSeverity.critical, actionRoute: '/map/detail/T-003'),
    NotificationItem(id: 'n2', title: '⚠️ Weather Alert', body: 'Wave height exceeding 2.5m in survey zone. Consider halting operations.', timestamp: DateTime.now().subtract(const Duration(minutes: 23)), severity: NotificationSeverity.warning),
    NotificationItem(id: 'n3', title: '✅ AI Processing Complete', body: 'harbor_scan_042.xtf processed successfully. 7 detections found, 2 red alerts.', timestamp: DateTime.now().subtract(const Duration(hours: 2)), severity: NotificationSeverity.success, actionRoute: '/map'),
    NotificationItem(id: 'n4', title: '📡 Backend Processing Done', body: 'Mission MSN-2024-042 pipeline complete. Risk report ready for download.', timestamp: DateTime.now().subtract(const Duration(hours: 5)), severity: NotificationSeverity.info, actionRoute: '/reports'),
    NotificationItem(id: 'n5', title: '🔴 High Risk Cluster Detected', body: '3 red-tier objects clustered in Zone B. Recommend immediate survey halt.', timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)), severity: NotificationSeverity.critical),
    NotificationItem(id: 'n6', title: '🗺️ Offline Maps Updated', body: 'Survey zone tiles downloaded for offline use.', timestamp: DateTime.now().subtract(const Duration(days: 2)), severity: NotificationSeverity.info),
  ];
}
