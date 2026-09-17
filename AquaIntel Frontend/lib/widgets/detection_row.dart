import 'package:flutter/material.dart';
import '../models/detection.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'risk_badge.dart';
import 'aq_card.dart';

class DetectionRow extends StatelessWidget {
  final Detection detection;
  final VoidCallback onTap;

  const DetectionRow({
    super.key,
    required this.detection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: AqCard(
        padding: const EdgeInsets.all(AppSpacing.s16),
        onTap: onTap,
        child: Row(
          children: [
            // Icon / Image placeholder
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.veryLightBlue,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: const Icon(Icons.waves_rounded, color: AppColors.primaryBlue),
            ),
            const SizedBox(width: AppSpacing.s16),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${detection.displayType} — ${(detection.confidence * 100).toStringAsFixed(0)}% match',
                        style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                      RiskBadge(tier: detection.riskTier),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Row(
                    children: [
                      if (detection.impactType != null) ...[
                        const Icon(Icons.info_outline, size: 14, color: AppColors.danger),
                        const SizedBox(width: AppSpacing.s4),
                        Expanded(
                          child: Text(
                            'Marine Impact: ${detection.impactType}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else ...[
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.s4),
                        Text(
                          '${detection.clearanceM.toStringAsFixed(1)}m depth',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            const Icon(Icons.chevron_right, color: AppColors.border),
          ],
        ),
      ),
    );
  }
}
