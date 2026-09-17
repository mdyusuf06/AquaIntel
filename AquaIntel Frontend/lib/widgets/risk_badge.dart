import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class RiskBadge extends StatelessWidget {
  final String tier;

  const RiskBadge({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.riskColor(tier);
    final bgColor = AppTheme.riskBg(tier);
    
    String label = 'Low';
    if (tier.toLowerCase() == 'red') label = 'High';
    if (tier.toLowerCase() == 'amber') label = 'Medium';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.micro.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

