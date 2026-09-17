import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';

class ConfidenceBar extends StatelessWidget {
  final double value; // 0.0 - 1.0
  final String? tier;
  final double height;
  const ConfidenceBar({super.key, required this.value, this.tier, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final barColor = tier != null ? AppTheme.riskColor(tier!) : AppColors.primaryBlue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Confidence', style: Theme.of(context).textTheme.labelSmall),
            Text('${(value * 100).round()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: barColor)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: LinearProgressIndicator(
            value: value,
            minHeight: height,
            backgroundColor: barColor.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}
