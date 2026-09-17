import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/risk_summary.dart';
import '../../providers/detection_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/aq_card.dart';
import '../../widgets/empty_state.dart';

class RiskScreen extends StatelessWidget {
  const RiskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov    = context.watch<DetectionProvider>();
    final summary = RiskSummary.fromDetections(prov.allDetections);

    if (prov.allDetections.isEmpty) {
      return Scaffold(
        body: SafeArea(child: EmptyState(type: EmptyStateType.noDetections, onCta: () {})),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Text('Risk Dashboard', style: AppTextStyles.title),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s24, 0, AppSpacing.s24, 160),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: AppSpacing.s16),

                // ── Stat Cards ──
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.s16,
                  crossAxisSpacing: AppSpacing.s16,
                  childAspectRatio: 1.3,
                  children: [
                    StatCard(label: 'Red Alerts',    value: '${summary.redCount}',   icon: Icons.warning_rounded, color: AppColors.danger,  bgColor: AppColors.dangerBg, sparklineData: [1,2,1,3,2,4,summary.redCount.toDouble()]),
                    StatCard(label: 'Amber Alerts',  value: '${summary.amberCount}', icon: Icons.error_outline,   color: AppColors.warning, bgColor: AppColors.warningBg, sparklineData: const [2,3,4,2,5,3,4]),
                    StatCard(label: 'Green Objects', value: '${summary.greenCount}', icon: Icons.check_circle,    color: AppColors.success, bgColor: AppColors.successBg, sparklineData: [5,6,5,7,6,8,summary.greenCount.toDouble()]),
                    StatCard(label: 'Avg Confidence', value: '${(summary.avgConfidence * 100).toStringAsFixed(0)}%', icon: Icons.analytics_rounded, sparklineData: const [72,74,71,78,75,80,82]),
                  ],
                ),
                const SizedBox(height: AppSpacing.s32),

                // ── Risk Distribution Donut ──
                Text('Risk Distribution', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.s16),
                AqCard(
                  padding: const EdgeInsets.all(AppSpacing.s24),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140, height: 140,
                        child: PieChart(PieChartData(
                          sections: [
                            PieChartSectionData(value: summary.redCount.toDouble(),   color: AppColors.danger,  title: '${summary.redCount}',   titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            PieChartSectionData(value: summary.amberCount.toDouble(), color: AppColors.warning, title: '${summary.amberCount}', titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            PieChartSectionData(value: summary.greenCount.toDouble(), color: AppColors.success, title: '${summary.greenCount}', titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                          sectionsSpace: 3,
                          centerSpaceRadius: 32,
                        )),
                      ),
                      const SizedBox(width: AppSpacing.s24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Legend(color: AppColors.danger,  label: 'Red — Immediate action'),
                            const SizedBox(height: AppSpacing.s12),
                            _Legend(color: AppColors.warning, label: 'Amber — Monitor'),
                            const SizedBox(height: AppSpacing.s12),
                            _Legend(color: AppColors.success, label: 'Green — Cleared'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s32),

                // ── Risk Trend Chart ──
                Text('7-Day Risk Trend', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.s16),
                AqCard(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s8, AppSpacing.s24, AppSpacing.s16, AppSpacing.s8),
                  child: SizedBox(
                    height: 180,
                    child: LineChart(LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles:  AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: AppTextStyles.micro))),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                          final days = ['M','T','W','T','F','S','S'];
                          final idx = v.toInt();
                          if (idx < 0 || idx >= days.length) return const SizedBox();
                          return Text(days[idx], style: AppTextStyles.micro);
                        })),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: summary.trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.total.toDouble())).toList(),
                          color: AppColors.primaryBlue,
                          isCurved: true,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: true, color: AppColors.primaryBlue.withValues(alpha: 0.08)),
                        ),
                        LineChartBarData(
                          spots: summary.trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.redCount.toDouble())).toList(),
                          color: AppColors.danger,
                          isCurved: true,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    )),
                  ),
                ),
                const SizedBox(height: AppSpacing.s32),

                // ── Priority List ──
                Text('Priority Targets', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.s16),
                ...summary.priorityList.map((d) => Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.s12),
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(color: AppTheme.riskColor(d.riskTier), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: AppSpacing.s16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.displayType, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                            Text('${d.clearanceM.toStringAsFixed(1)}m clearance · ${(d.confidence * 100).toStringAsFixed(0)}% conf', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Text(d.id, style: AppTextStyles.micro.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                )),

                // ── AI Recommendations ──
                const SizedBox(height: AppSpacing.s32),
                AqCard(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.smart_toy_outlined, color: AppColors.primaryBlue),
                        const SizedBox(width: AppSpacing.s12),
                        Text('AI Recommendations', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: AppSpacing.s16),
                      _AiRec(icon: Icons.warning_amber_rounded, color: AppColors.danger,
                        text: summary.redCount > 0
                          ? 'Halt vessel transit. ${summary.redCount} red-tier object(s) require immediate operator verification before re-entry.'
                          : 'No immediate red-tier threats detected. Maintain standard survey protocols.',
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      _AiRec(icon: Icons.route_rounded, color: AppColors.warning,
                        text: 'Recommend diverging survey path by 200m SW to avoid the amber cluster in Zone B.',
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: AppSpacing.s8),
        Expanded(child: Text(label, style: AppTextStyles.caption)),
      ],
    );
  }
}

class _AiRec extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _AiRec({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: AppSpacing.s8),
        Expanded(child: Text(text, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary))),
      ],
    );
  }
}
