import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppColors.primaryBlue,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(child: Text('CR', style: AppTextStyles.headline.copyWith(color: Colors.white))),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Text('Capt. Rodriguez', style: AppTextStyles.title.copyWith(color: Colors.white)),
                      Text('Mission Operator', style: AppTextStyles.body.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                      const SizedBox(height: AppSpacing.s8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s6),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadius.pill)),
                        child: Text('Coast Guard Command �?INS', style: AppTextStyles.caption.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Mission Stats ──
                Text('Mission Statistics', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.s16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.s12,
                  crossAxisSpacing: AppSpacing.s12,
                  childAspectRatio: 1.6,
                  children: const [
                    _StatTile(value: '142 hrs',  label: 'Hours Surveyed', icon: Icons.access_time_rounded),
                    _StatTile(value: '847',       label: 'Objects Detected', icon: Icons.radar_rounded),
                    _StatTile(value: '1,240 km²', label: 'Area Covered', icon: Icons.map_outlined),
                    _StatTile(value: '23',         label: 'Missions Complete', icon: Icons.check_circle_outline),
                  ],
                ),
                const SizedBox(height: AppSpacing.s32),

                // ── Achievements ──
                Text('Achievements', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.s16),
                Wrap(
                  spacing: AppSpacing.s12,
                  runSpacing: AppSpacing.s12,
                  children: const [
                    _Badge(icon: Icons.star_rounded,         label: 'Eagle Eye',   color: AppColors.warning),
                    _Badge(icon: Icons.rocket_launch_rounded, label: '100 Missions', color: AppColors.primaryBlue),
                    _Badge(icon: Icons.eco_rounded,           label: 'Ocean Guardian', color: AppColors.success),
                    _Badge(icon: Icons.bolt_rounded,          label: 'Speed Analyst',  color: AppColors.information),
                  ],
                ),
                const SizedBox(height: AppSpacing.s32),

                // ── Recent Missions ──
                Text('Recent Missions', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.s16),
                ...['MSN-2024-042', 'MSN-2024-039', 'MSN-2024-037'].map((id) => Container(
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
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.veryLightBlue, borderRadius: BorderRadius.circular(AppRadius.small)),
                        child: const Icon(Icons.explore_rounded, color: AppColors.primaryBlue, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(id, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                            Text('Completed · 12 detections', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    ],
                  ),
                )),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value, label;
  final IconData icon;
  const _StatTile({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.medium), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBlue),
          const Spacer(),
          Text(value, style: AppTextStyles.title.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: AppTextStyles.micro.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: AppSpacing.s6),
          Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
