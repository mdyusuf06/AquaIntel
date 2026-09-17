import 'package:flutter/material.dart';

class AppColors {
  // ── Primary Palette ──────────────────────────────────────────────────────
  static const Color background    = Color(0xFFF6FAFF);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color surfaceGray   = Color(0xFFF1F5F9);

  static const Color primaryBlue   = Color(0xFF2563EB);
  static const Color accentBlue    = Color(0xFF3B82F6);
  static const Color lightBlue     = Color(0xFFDBEAFE);
  static const Color veryLightBlue = Color(0xFFEFF6FF);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textDisabled  = Color(0xFFCBD5E1);

  // ── Border ────────────────────────────────────────────────────────────────
  static const Color border        = Color(0xFFE2E8F0);
  static const Color borderStrong  = Color(0xFFCBD5E1);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success       = Color(0xFF16A34A);
  static const Color warning       = Color(0xFFF59E0B);
  static const Color danger        = Color(0xFFEF4444);
  static const Color information   = Color(0xFF0EA5E9);

  // ── Status Backgrounds ────────────────────────────────────────────────────
  static const Color successBg     = Color(0xFFDCFCE7);
  static const Color warningBg     = Color(0xFFFEF3C7);
  static const Color dangerBg      = Color(0xFFFEE2E2);
  static const Color infoBg        = Color(0xFFE0F2FE);

  // ── Shadow ────────────────────────────────────────────────────────────────
  /// rgba(37,99,235,0.08) — soft blue shadow
  static const Color shadow        = Color(0x142563EB);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const Gradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
  );

  static const Gradient oceanGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
  );
}
