import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated sonar ripple loading indicator.
class SonarLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const SonarLoader({super.key, this.size = 80, this.color});

  @override
  State<SonarLoader> createState() => _SonarLoaderState();
}

class _SonarLoaderState extends State<SonarLoader> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    ));
    _anims = _controllers.map((c) =>
      CurvedAnimation(parent: c, curve: Curves.easeOut)
    ).toList();

    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 500), () {
        if (mounted) _controllers[i].repeat();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primaryBlue;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple rings
          for (int i = 0; i < 3; i++)
            AnimatedBuilder(
              animation: _anims[i],
              builder: (_, __) => Container(
                width:  widget.size * _anims[i].value,
                height: widget.size * _anims[i].value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: (1 - _anims[i].value) * 0.5),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          // Center dot
          Container(
            width: widget.size * 0.2,
            height: widget.size * 0.2,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

