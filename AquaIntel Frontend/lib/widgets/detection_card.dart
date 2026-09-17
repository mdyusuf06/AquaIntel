import 'package:flutter/material.dart';
import '../models/detection.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'aq_card.dart';
import 'risk_badge.dart';

class DetectionCard extends StatelessWidget {
  final Detection detection;
  final VoidCallback onTap;

  const DetectionCard({
    super.key,
    required this.detection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: AppSpacing.s16),
      child: AqCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Area
            Stack(
              children: [
                Container(
                  height: 140,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
                    image: DecorationImage(
                      image: NetworkImage('https://images.unsplash.com/photo-1621213324637-251f2e825a0b?q=80&w=2938&auto=format&fit=crop'), // Placeholder for sonar/camera
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Gradient overlay
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.s12,
                  left: AppSpacing.s12,
                  child: RiskBadge(tier: detection.riskTier),
                ),
                Positioned(
                  top: AppSpacing.s12,
                  right: AppSpacing.s12,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.s4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                    ),
                    child: const Icon(Icons.more_vert, size: 16, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            // Details Area
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detection.displayType, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.s4),
                  Row(
                    children: [
                      Text(
                        '${_formatTime(detection.detectedAt)} �?Today',
                        style: AppTextStyles.micro.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primaryBlue),
                      const SizedBox(width: AppSpacing.s4),
                      Text('Zone A', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                        child: Text('...', style: TextStyle(color: AppColors.border)),
                      ),
                      Text('${detection.clearanceM.toStringAsFixed(0)}m depth', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                  if (detection.impactType != null) ...[
                    const SizedBox(height: AppSpacing.s8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Text(
                        'Impact: ${detection.impactType} (${detection.impactSeverity})',
                        style: AppTextStyles.micro.copyWith(color: AppColors.danger),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final min = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $period';
  }
}

