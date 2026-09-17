import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class VoicePill extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onTap;

  const VoicePill({
    super.key,
    required this.isRecording,
    required this.onTap,
  });

  @override
  State<VoicePill> createState() => _VoicePillState();
}

class _VoicePillState extends State<VoicePill> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _glowAnimation = Tween<double>(begin: 4.0, end: 15.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VoicePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.animateTo(0.0);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
              boxShadow: [
                if (widget.isRecording)
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                    blurRadius: _glowAnimation.value,
                    spreadRadius: _glowAnimation.value / 2,
                  ),
                BoxShadow(
                  color: AppColors.shadow,
                  offset: const Offset(4, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              widget.isRecording ? Icons.mic : Icons.add,
              color: Colors.white,
              size: 28,
            ),
          );
        },
      ),
    );
  }
}

