import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppShadows {
  static List<BoxShadow> get soft {
    return [
      BoxShadow(
        color: AppColors.shadow,
        blurRadius: 16,
        offset: const Offset(0, 4),
        spreadRadius: 0,
      ),
    ];
  }
  
  static List<BoxShadow> get medium {
    return [
      BoxShadow(
        color: AppColors.shadow,
        blurRadius: 24,
        offset: const Offset(0, 8),
        spreadRadius: 0,
      ),
    ];
  }
}
