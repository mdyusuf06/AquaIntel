import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  static TextStyle get display => displayLarge;
  static TextStyle displayLarge = GoogleFonts.inter(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle headline = GoogleFonts.inter(
    fontSize: 30,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle title = GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500, // Medium
    color: AppColors.textPrimary,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.textPrimary,
  );
  
  static TextStyle bodySecondary = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.textSecondary,
  );

  static TextStyle caption = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500, // Medium
    color: AppColors.textSecondary,
  );

  static TextStyle micro = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
  );
}
