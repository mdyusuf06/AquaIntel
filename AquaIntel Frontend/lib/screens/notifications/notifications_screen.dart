import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notification_item.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';


class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov    = context.watch<NotificationProvider>();
    final grouped = prov.grouped;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Text('Notifications', style: AppTextStyles.title),
            actions: [
              TextButton(
                onPressed: prov.markAllRead,
                child: Text('Mark all read', style: AppTextStyles.caption.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (grouped.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No notifications', style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s24, AppSpacing.s8, AppSpacing.s24, 160),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  for (final group in ['Critical', 'Today', 'Earlier'])
                    if (grouped.containsKey(group)) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                        child: Text(group.toUpperCase(), style: AppTextStyles.micro.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                      ),
                      ...grouped[group]!.map((n) => _NotificationTile(item: n, onDismiss: () => prov.dismiss(n.id), onTap: () => prov.markRead(n.id))),
                    ],
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onDismiss, required this.onTap});

  Color get _iconBg => switch (item.severity) {
    NotificationSeverity.critical => AppColors.dangerBg,
    NotificationSeverity.warning  => AppColors.warningBg,
    NotificationSeverity.success  => AppColors.successBg,
    NotificationSeverity.info     => AppColors.infoBg,
  };

  Color get _iconColor => switch (item.severity) {
    NotificationSeverity.critical => AppColors.danger,
    NotificationSeverity.warning  => AppColors.warning,
    NotificationSeverity.success  => AppColors.success,
    NotificationSeverity.info     => AppColors.information,
  };

  IconData get _icon => switch (item.severity) {
    NotificationSeverity.critical => Icons.warning_rounded,
    NotificationSeverity.warning  => Icons.error_outline_rounded,
    NotificationSeverity.success  => Icons.check_circle_rounded,
    NotificationSeverity.info     => Icons.info_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.s24),
        decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(AppRadius.medium)),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.s12),
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: item.isRead ? Colors.white : AppColors.veryLightBlue,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: item.isRead ? AppColors.border : AppColors.primaryBlue.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: _iconBg, shape: BoxShape.circle),
                child: Icon(_icon, color: _iconColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: AppTextStyles.body.copyWith(fontWeight: item.isRead ? FontWeight.w500 : FontWeight.bold)),
                    const SizedBox(height: AppSpacing.s4),
                    Text(item.body, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.s4),
                    Text(_timeAgo(item.timestamp), style: AppTextStyles.micro.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (!item.isRead)
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
