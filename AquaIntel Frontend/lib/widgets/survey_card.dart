import 'package:flutter/material.dart';
import '../models/survey.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'aq_card.dart';
import 'aq_button.dart';

class SurveyCard extends StatelessWidget {
  final Survey survey;
  final int redAlerts;
  final VoidCallback onViewLive;

  const SurveyCard({
    super.key,
    required this.survey,
    required this.redAlerts,
    required this.onViewLive,
  });

  @override
  Widget build(BuildContext context) {
    return AqCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Map/Progress Circle Placeholder
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Fake map rings
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                      ),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Progress Ring
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: survey.progressPct,
                          backgroundColor: Colors.transparent,
                          color: AppColors.primaryBlue,
                          strokeWidth: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s24),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Text(
                            'Backend unreachable',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Is the server running?',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AqButton(
                        label: 'Retry',
                        icon: Icons.refresh,
                        onPressed: onViewLive, // Reuse action for demo
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.veryLightBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.dns_outlined, color: AppColors.primaryBlue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

