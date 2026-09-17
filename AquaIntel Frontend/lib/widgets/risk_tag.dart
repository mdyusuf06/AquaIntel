import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RiskTag extends StatelessWidget {
  final String tier; // red, amber, green
  final bool small;
  const RiskTag({super.key, required this.tier, this.small = false});

  String get _label => tier.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.riskColor(tier);
    final bg = AppTheme.riskBg(tier);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 3 : 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: small ? 6 : 8, height: small ? 6 : 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(_label, style: TextStyle(color: color, fontSize: small ? 10 : 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}
