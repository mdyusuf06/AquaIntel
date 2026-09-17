import 'package:flutter/material.dart';

/// Standardized animation constants for spring-like, premium interactions.
class AppAnimations {
  // Durations
  static const Duration fast   = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow   = Duration(milliseconds: 500);
  static const Duration xSlow  = Duration(milliseconds: 800);

  // Page transitions
  static const Duration pageTransition = Duration(milliseconds: 350);

  // Spring curve (mimics iOS spring)
  static const Curve spring      = Curves.easeOutCubic;
  static const Curve springBounce = Curves.elasticOut;
  static const Curve ease         = Curves.easeInOut;
  static const Curve easeOut      = Curves.easeOut;
  static const Curve easeIn       = Curves.easeIn;

  // Scale factors for press animations
  static const double pressScale = 0.96;
  static const double liftScale  = 1.02;
}
