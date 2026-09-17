import 'package:flutter/material.dart';
import '../models/scan_result.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class PipelineStepTile extends StatelessWidget {
  final PipelineStep step;
  final bool isDone;
  final bool isActive;
  final double progress; // 0.0–1.0
  final Duration? elapsed;

  const PipelineStepTile({
    super.key,
    required this.step,
    required this.isDone,
    required this.isActive,
    required this.progress,
    this.elapsed,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone
        ? AppColors.success
        : isActive
            ? AppColors.primaryBlue
            : AppColors.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator + vertical line
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDone
                    ? AppColors.success.withValues(alpha: 0.12)
                    : isActive
                      ? AppColors.veryLightBlue
                      : AppColors.surfaceGray,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color,
                    width: isActive ? 2 : 1.5,
                  ),
                ),
                child: Icon(
                  isDone
                    ? Icons.check_rounded
                    : isActive
                      ? Icons.sync_rounded
                      : Icons.circle_outlined,
                  size: 16,
                  color: color,
                ),
              ),
              if (step != PipelineStep.missionReady)
                Container(width: 2, height: 24, color: color.withValues(alpha: 0.3)),
            ],
          ),
          const SizedBox(width: AppSpacing.s16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      step.label,
                      style: AppTextStyles.body.copyWith(
                        color: isDone ? AppColors.textPrimary : isActive ? AppColors.primaryBlue : AppColors.textSecondary,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    if (elapsed != null && (isDone || isActive))
                      Text(
                        _formatElapsed(elapsed!),
                        style: AppTextStyles.micro.copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
                if (isActive) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(step.description, style: AppTextStyles.micro),
                  const SizedBox(height: AppSpacing.s8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: AppColors.lightBlue,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ] else if (isDone) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text('Completed', style: AppTextStyles.micro.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatElapsed(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }
}
