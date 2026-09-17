import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static Color riskColor(String tier) {
    if (tier.toLowerCase() == 'red') return AppColors.danger;
    if (tier.toLowerCase() == 'amber') return AppColors.warning;
    return AppColors.success;
  }
  
  static Color riskBg(String tier) {
    if (tier.toLowerCase() == 'red') return AppColors.dangerBg;
    if (tier.toLowerCase() == 'amber') return AppColors.warningBg;
    return AppColors.successBg;
  }

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.light,
      primary: AppColors.primaryBlue,
      secondary: AppColors.accentBlue,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: AppColors.background,
    textTheme: GoogleFonts.interTextTheme().copyWith(
      displayLarge: AppTextStyles.displayLarge,
      headlineLarge: AppTextStyles.headline,
      titleLarge: AppTextStyles.title,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.caption,
      labelSmall: AppTextStyles.micro,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      titleTextStyle: AppTextStyles.title.copyWith(fontSize: 18),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
  );
}

