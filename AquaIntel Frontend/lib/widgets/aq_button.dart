import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_shadows.dart';

enum AqButtonType { primary, secondary, ghost }

class AqButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final AqButtonType type;
  final bool isFullWidth;

  const AqButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.type = AqButtonType.primary,
    this.isFullWidth = false,
  });

  @override
  State<AqButton> createState() => _AqButtonState();
}

class _AqButtonState extends State<AqButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onPressed();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color fgColor;
    Border? border;
    List<BoxShadow>? shadow;

    switch (widget.type) {
      case AqButtonType.primary:
        bgColor = AppColors.primaryBlue;
        fgColor = Colors.white;
        shadow = AppShadows.soft;
        break;
      case AqButtonType.secondary:
        bgColor = Colors.white;
        fgColor = AppColors.primaryBlue;
        border = Border.all(color: AppColors.primaryBlue, width: 2);
        shadow = AppShadows.soft;
        break;
      case AqButtonType.ghost:
        bgColor = Colors.transparent;
        fgColor = AppColors.primaryBlue;
        break;
    }

    Widget buttonContent = Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: border,
        boxShadow: shadow,
      ),
      child: Row(
        mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, color: fgColor, size: 20),
            const SizedBox(width: AppSpacing.s8),
          ],
          Text(
            widget.label,
            style: AppTextStyles.bodyLarge.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: buttonContent,
      ),
    );
  }
}
