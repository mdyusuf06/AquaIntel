import 'package:flutter/material.dart';
import '../theme/app_colors.dart';


class NeumorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? baseColor;

  const NeumorphicButton({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.baseColor,
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isPressed = false;

  void _onPointerDown(PointerDownEvent event) {
    setState(() => _isPressed = true);
  }

  void _onPointerUp(PointerUpEvent event) {
    setState(() => _isPressed = false);
    widget.onTap();
  }
  
  void _onPointerCancel(PointerCancelEvent event) {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.baseColor ?? Colors.white;
    
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    offset: _isPressed ? const Offset(1, 1) : const Offset(4, 4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.white,
                    offset: _isPressed ? const Offset(-1, -1) : const Offset(-4, -4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: widget.child,
      ),
    );
  }
}
