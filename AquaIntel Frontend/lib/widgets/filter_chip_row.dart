import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class FilterChipRow extends StatelessWidget {
  final Map<String, String> chips;
  final String selected;
  final ValueChanged<String> onChanged;

  const FilterChipRow({
    super.key,
    required this.chips,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final keys = chips.keys.toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: Row(
        children: keys.map((key) {
          final isSelected = key == selected;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s8),
            child: GestureDetector(
              onTap: () => onChanged(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s20,
                  vertical: AppSpacing.s12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: isSelected ? AppColors.primaryBlue : AppColors.border,
                  ),
                ),
                child: Text(
                  chips[key]!,
                  style: AppTextStyles.body.copyWith(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
