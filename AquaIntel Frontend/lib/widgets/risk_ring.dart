import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Animated circular gauge for confidence/risk display.
class RiskRing extends StatefulWidget {
  final double value; // 0.0 - 1.0
  final String? tier;
  final double size;
  final String? label;

  const RiskRing({
    super.key,
    required this.value,
    this.tier,
    this.size = 100,
    this.label,
  });

  @override
  State<RiskRing> createState() => _RiskRingState();
}

class _RiskRingState extends State<RiskRing> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _anim = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.tier != null
      ? AppTheme.riskColor(widget.tier!)
      : AppColors.primaryBlue;
    final bg = widget.tier != null
      ? AppTheme.riskBg(widget.tier!)
      : AppColors.veryLightBlue;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                value: _anim.value,
                strokeWidth: widget.size * 0.08,
                backgroundColor: bg,
                color: color,
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => Text(
                  '${(_anim.value * 100).toStringAsFixed(0)}%',
                  style: AppTextStyles.title.copyWith(color: color, fontWeight: FontWeight.bold, fontSize: widget.size * 0.2),
                ),
              ),
              if (widget.label != null)
                Text(widget.label!, style: AppTextStyles.micro.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
