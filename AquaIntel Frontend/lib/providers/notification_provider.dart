import 'package:flutter/material.dart';
import '../models/notification_item.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationItem> _items = NotificationItem.mockData;

  List<NotificationItem> get items  => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.isRead).length;

  Map<String, List<NotificationItem>> get grouped {
    final map = <String, List<NotificationItem>>{};
    for (final n in _items) {
      map.putIfAbsent(n.group, () => []).add(n);
    }
    return map;
  }

  void markRead(String id) {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _items = List.from(_items)..[idx] = _items[idx].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markAllRead() {
    _items = _items.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  void dismiss(String id) {
    _items = _items.where((n) => n.id != id).toList();
    notifyListeners();
  }
}
