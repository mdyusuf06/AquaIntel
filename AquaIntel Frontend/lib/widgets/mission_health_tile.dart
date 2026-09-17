import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_animations.dart';

enum HealthStatus { ok, warning, error, offline }

extension HealthStatusStyle on HealthStatus {
  Color get color => switch (this) {
    HealthStatus.ok      => AppColors.success,
    HealthStatus.warning => AppColors.warning,
    HealthStatus.error   => AppColors.danger,
    HealthStatus.offline => AppColors.textSecondary,
  };
  String get label => switch (this) {
    HealthStatus.ok      => 'Online',
    HealthStatus.warning => 'Degraded',
    HealthStatus.error   => 'Error',
    HealthStatus.offline => 'Offline',
  };
  IconData get icon => switch (this) {
    HealthStatus.ok      => Icons.check_circle_rounded,
    HealthStatus.warning => Icons.warning_amber_rounded,
    HealthStatus.error   => Icons.error_rounded,
    HealthStatus.offline => Icons.cloud_off_rounded,
  };
}

class MissionHealthTile extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final HealthStatus status;

  const MissionHealthTile({
    super.key,
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: AppColors.textSecondary),
              AnimatedContainer(
                duration: AppAnimations.normal,
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: status.color,
                  shape: BoxShape.circle,
                  boxShadow: status == HealthStatus.ok
                    ? [BoxShadow(color: status.color.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)]
                    : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.s4),
          Text(sublabel, style: AppTextStyles.micro.copyWith(color: status.color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
