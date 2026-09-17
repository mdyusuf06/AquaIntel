import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppStyles {
  static TextStyle get h1 => GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get h2 => GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get body => GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 14,
      );

  static TextStyle get bodyMuted => GoogleFonts.inter(
        color: AppColors.textSecondary,
        fontSize: 12,
      );

  static TextStyle get accentCyber => GoogleFonts.inter(
        color: AppColors.primaryBlue,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      );
      
  static BoxDecoration neumorphicBox({double borderRadius = 12}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          offset: Offset(4, 4),
          blurRadius: 10,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: Colors.white,
          offset: Offset(-4, -4),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ],
    );
  }
}
