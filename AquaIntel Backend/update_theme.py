import os

frontend_dir = r"c:\Users\asus\Downloads\AquaIntel"

# 1. Update App Theme
app_theme_code = """import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand ──────────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF6B4EE6); // Purple
  static const Color darkNavy      = Color(0xFF0D0D0D);
  static const Color skyAccent     = Color(0xFF3B9CF0); // Blue
  static const Color background    = Color(0xFF0F172A); // Dark modern bg
  static const Color surface       = Color(0xFF1E293B); // Dark surface
  static const Color onPrimary     = Colors.white;
  static const Color onSurface     = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color border        = Color(0xFF334155);
  static const Color inputFill     = Color(0xFF1E293B);

  // ── CTA ────────────────────────────────────────────────────────────────
  static const Color ctaBlack = Color(0xFF8B5CF6);

  // ── Risk palette ────────────────────────────────────────────────────────
  static const Color red     = Color(0xFFEF4444);
  static const Color amber   = Color(0xFFF59E0B);
  static const Color green   = Color(0xFF10B981);
  static const Color redBg   = Color(0x33EF4444);
  static const Color amberBg = Color(0x33F59E0B);
  static const Color greenBg = Color(0x3310B981);

  static Color riskColor(String tier) {
    if (tier.toLowerCase() == 'red') return red;
    if (tier.toLowerCase() == 'amber') return amber;
    return green;
  }
  
  static Color riskBg(String tier) {
    if (tier.toLowerCase() == 'red') return redBg;
    if (tier.toLowerCase() == 'amber') return amberBg;
    return greenBg;
  }

  // ── Gradients ─────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF3B9CF0), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Theme ───────────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      secondary: skyAccent,
      surface: surface,
      onSurface: onSurface,
    ),
    scaffoldBackgroundColor: background,
    textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
      titleLarge:   GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
      titleMedium:  GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
      bodyLarge:    GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.white),
      bodyMedium:   GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary),
      labelSmall:   GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w500, color: textSecondary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      titleTextStyle: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: border),
      ),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ctaBlack,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 15),
        elevation: 0,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primary,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}
"""

with open(os.path.join(frontend_dir, "lib", "theme", "app_theme.dart"), "w", encoding="utf-8") as f:
    f.write(app_theme_code)

print("Updated theme.")
