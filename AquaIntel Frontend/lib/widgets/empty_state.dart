import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'aq_button.dart';

enum EmptyStateType {
  noSurveys,
  noDetections,
  offline,
  noInternet,
  processingFailed,
  noAiModel,
  noGps,
}

class EmptyState extends StatelessWidget {
  final EmptyStateType type;
  final String? customTitle;
  final String? customBody;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const EmptyState({
    super.key,
    required this.type,
    this.customTitle,
    this.customBody,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration circle
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.veryLightBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(data.$1, size: 48, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: AppSpacing.s24),
            Text(
              customTitle ?? data.$2,
              style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              customBody ?? data.$3,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onCta != null) ...[
              const SizedBox(height: AppSpacing.s32),
              AqButton(
                label: ctaLabel ?? data.$4,
                icon: data.$5,
                onPressed: onCta!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  (IconData, String, String, String, IconData) get _data => switch (type) {
    EmptyStateType.noSurveys        => (Icons.explore_off_rounded, 'No Active Surveys', 'Start a new survey mission to begin scanning the seafloor for marine debris.', 'Start Survey', Icons.add_rounded),
    EmptyStateType.noDetections     => (Icons.radar_rounded,       'No Detections Yet', 'Upload a sonar log to begin AI-powered debris detection and risk assessment.', 'Upload Sonar Log', Icons.upload_rounded),
    EmptyStateType.offline          => (Icons.cloud_off_rounded,   'You\'re Offline', 'The app is running in offline mode. Cached data is available.', 'Retry Connection', Icons.refresh_rounded),
    EmptyStateType.noInternet       => (Icons.wifi_off_rounded,    'No Internet', 'Check your network connection and try again.', 'Retry', Icons.refresh_rounded),
    EmptyStateType.processingFailed => (Icons.error_outline_rounded,'Processing Failed', 'The sonar pipeline encountered an error. Check your file format and try again.', 'Try Again', Icons.refresh_rounded),
    EmptyStateType.noAiModel        => (Icons.memory_rounded,      'AI Model Not Loaded', 'The on-device AI model is not available. Connect to the backend to enable cloud inference.', 'Check Status', Icons.settings_rounded),
    EmptyStateType.noGps            => (Icons.location_off_rounded, 'No GPS Signal', 'Enable location permissions to track vessel position on the map.', 'Enable Location', Icons.location_on_rounded),
  };
}
