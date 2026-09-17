import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/detection_provider.dart';
import '../../providers/survey_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/aq_card.dart';
import '../../widgets/empty_state.dart';
import '../../data/api_client.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final detProv = context.watch<DetectionProvider>();
    final surProv = context.watch<SurveyProvider>();
    final survey  = surProv.activeSurvey;
    final dets    = detProv.allDetections;

    // Category breakdown
    final cats = <String, int>{};
    for (final d in dets) { cats[d.displayType] = (cats[d.displayType] ?? 0) + 1; }

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Text('Reports', style: AppTextStyles.title),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s24, 0, AppSpacing.s24, 160),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: AppSpacing.s16),

                // ── Mission Summary Header ──
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment_outlined, color: Colors.white, size: 20),
                          const SizedBox(width: AppSpacing.s8),
                          Text('Mission Report', style: AppTextStyles.body.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(survey?.id ?? 'MSN-2024-042', style: AppTextStyles.headline.copyWith(color: Colors.white)),
                      const SizedBox(height: AppSpacing.s16),
                      Row(
                        children: [
                          _HeaderStat(label: 'Targets', value: '${dets.length}'),
                          const SizedBox(width: AppSpacing.s32),
                          _HeaderStat(label: 'Red Alerts', value: '${dets.where((d) => d.riskTier == "red").length}'),
                          const SizedBox(width: AppSpacing.s32),
                          _HeaderStat(label: 'Coverage', value: '${(survey?.progressPct ?? 0.85) * 100 ~/ 1}%'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s32),

                // ── Debris Category Chart ──
                Text('Debris Categories', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.s16),
                if (cats.isEmpty)
                  const EmptyState(type: EmptyStateType.noDetections)
                else
                  AqCard(
                    padding: const EdgeInsets.all(AppSpacing.s20),
                    child: Column(
                      children: cats.entries.map((e) {
                        final pct = dets.isEmpty ? 0.0 : e.value / dets.length;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(e.key, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
                                  Text('${e.value} (${(pct * 100).toStringAsFixed(0)}%)', style: AppTextStyles.caption.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.s6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 8,
                                  backgroundColor: AppColors.lightBlue,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: AppSpacing.s32),

                // ── Survey Timeline ──
                Text('Mission Timeline', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.s16),
                AqCard(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    children: [
                      _TimelineEvent(icon: Icons.play_circle_outline, label: 'Mission Started', time: 'Aug 29 · 06:00 IST', color: AppColors.primaryBlue, isDone: true),
                      _TimelineEvent(icon: Icons.upload_rounded,        label: 'Sonar Uploaded',  time: 'Aug 29 · 09:15 IST', color: AppColors.primaryBlue, isDone: true),
                      _TimelineEvent(icon: Icons.analytics_outlined,    label: 'AI Processing Complete', time: 'Aug 29 · 09:18 IST', color: AppColors.success, isDone: true),
                      _TimelineEvent(icon: Icons.warning_amber_rounded, label: '2 Red Alerts Generated', time: 'Aug 29 · 09:19 IST', color: AppColors.danger, isDone: true),
                      _TimelineEvent(icon: Icons.check_circle_outline,  label: 'Operator Review', time: 'Pending', color: AppColors.textSecondary, isDone: false, isLast: true),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s32),

                // ── Export Buttons ──
                Text('Export Report', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.s16),
                Wrap(
                  spacing: AppSpacing.s12,
                  runSpacing: AppSpacing.s12,
                  children: [
                    _ExportButton(label: 'CSV',     icon: Icons.table_chart_outlined, onTap: () => _export(context, 'csv')),
                    _ExportButton(label: 'JSON',    icon: Icons.code_rounded,          onTap: () => _export(context, 'json')),
                    _ExportButton(label: 'GeoJSON', icon: Icons.map_outlined,          onTap: () => _export(context, 'geojson')),
                    _ExportButton(label: 'PDF',     icon: Icons.picture_as_pdf_outlined, onTap: () => _export(context, 'pdf')),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _export(BuildContext context, String format) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 12),
          Text('Generating $format report...'),
        ],
      ),
      backgroundColor: AppColors.textPrimary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.small)),
    ));
    
    try {
      // Simulate network delay if API takes a moment
      await Future.delayed(const Duration(seconds: 1));
      await ApiClient.instance.get('/api/v1/targets/export', queryParameters: {'format': format});
      
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Export Successful'),
          content: Text('Your $format report has been generated and saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: AppColors.danger,
      ));
    }
  }
}

class _HeaderStat extends StatelessWidget {
  final String label, value;
  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTextStyles.headline.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(label, style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.7))),
      ],
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  final IconData icon;
  final String label, time;
  final Color color;
  final bool isDone, isLast;
  const _TimelineEvent({required this.icon, required this.label, required this.time, required this.color, required this.isDone, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          if (!isLast) Container(width: 2, height: 32, color: AppColors.border),
        ]),
        const SizedBox(width: AppSpacing.s16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.s6),
            Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
            Text(time, style: AppTextStyles.micro.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.s16),
          ],
        )),
      ],
    );
  }
}

class _ExportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ExportButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: AppColors.shadow.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primaryBlue, size: 28),
            const SizedBox(height: AppSpacing.s8),
            Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}


