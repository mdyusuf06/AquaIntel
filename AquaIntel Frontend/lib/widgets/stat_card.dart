
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_animations.dart';

/// Animated stat card with value, label, icon, and sparkline.
class StatCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final Color? bgColor;
  final List<double>? sparklineData;
  final String? subtitle;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.bgColor,
    this.sparklineData,
    this.subtitle,
    this.onTap,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _valueAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppAnimations.slow);
    _valueAnim = CurvedAnimation(parent: _ctrl, curve: AppAnimations.spring);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color  = widget.color ?? AppColors.primaryBlue;
    final bgColor = widget.bgColor ?? AppColors.veryLightBlue;

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap?.call(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? AppAnimations.pressScale : 1.0,
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(AppRadius.small)),
                    child: Icon(widget.icon, color: color, size: 20),
                  ),
                  if (widget.sparklineData != null)
                    SizedBox(
                      width: 48,
                      height: 24,
                      child: AnimatedBuilder(
                        animation: _valueAnim,
                        builder: (_, __) => CustomPaint(
                          painter: _SparklinePainter(
                            data:     widget.sparklineData!,
                            color:    color,
                            progress: _valueAnim.value,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              AnimatedBuilder(
                animation: _valueAnim,
                builder: (_, __) => Text(widget.value, style: AppTextStyles.headline.copyWith(color: AppColors.textPrimary)),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(widget.label, style: AppTextStyles.caption),
              if (widget.subtitle != null) ...[
                const SizedBox(height: AppSpacing.s4),
                Text(widget.subtitle!, style: AppTextStyles.micro.copyWith(color: color, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double progress;
  _SparklinePainter({required this.data, required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs() < 0.001 ? 1.0 : max - min;

    final points = data.asMap().entries.map((e) {
      final x = e.key / (data.length - 1) * size.width;
      final y = size.height - ((e.value - min) / range) * size.height;
      return Offset(x, y);
    }).toList();

    // Clip to animated progress
    final clipPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    canvas.clipPath(clipPath);

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      path.cubicTo(
        prev.dx + (curr.dx - prev.dx) / 2, prev.dy,
        prev.dx + (curr.dx - prev.dx) / 2, curr.dy,
        curr.dx, curr.dy,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.progress != progress;
}
