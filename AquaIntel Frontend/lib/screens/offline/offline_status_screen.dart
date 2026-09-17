import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/mission_health_tile.dart';

class OfflineStatusScreen extends StatelessWidget {
  const OfflineStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Text('Offline Edge Status', style: AppTextStyles.title),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── AI Systems ──
                _SectionHeader('AI Inference Engine'),
                const SizedBox(height: AppSpacing.s12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.s12,
                  crossAxisSpacing: AppSpacing.s12,
                  childAspectRatio: 1.4,
                  children: const [
                    MissionHealthTile(icon: Icons.memory_rounded,   label: 'FAISS Index',       sublabel: 'Loaded · 1,240 vectors', status: HealthStatus.ok),
                    MissionHealthTile(icon: Icons.psychology_rounded, label: 'Tiny U-Net',       sublabel: 'Running · ONNX',         status: HealthStatus.ok),
                    MissionHealthTile(icon: Icons.precision_manufacturing_rounded, label: 'ONNX Runtime', sublabel: 'v1.17.3',       status: HealthStatus.ok),
                    MissionHealthTile(icon: Icons.storage_rounded,  label: 'AI Cache',           sublabel: '2.4 GB / 8 GB',          status: HealthStatus.warning),
                  ],
                ),
                const SizedBox(height: AppSpacing.s32),

                // ── Hardware ──
                _SectionHeader('Hardware & Location'),
                const SizedBox(height: AppSpacing.s12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.s12,
                  crossAxisSpacing: AppSpacing.s12,
                  childAspectRatio: 1.4,
                  children: const [
                    MissionHealthTile(icon: Icons.gps_fixed_rounded,     label: 'GPS Lock',         sublabel: 'Online · 8 sats',       status: HealthStatus.ok),
                    MissionHealthTile(icon: Icons.battery_charging_full_rounded, label: 'Battery',  sublabel: '87% · Charging',         status: HealthStatus.ok),
                    MissionHealthTile(icon: Icons.thermostat_rounded,    label: 'CPU Temperature',  sublabel: '42°C — Normal',          status: HealthStatus.ok),
                    MissionHealthTile(icon: Icons.compress_rounded,      label: 'Pressure Seal',    sublabel: 'Nominal · IP68',         status: HealthStatus.ok),
                  ],
                ),
                const SizedBox(height: AppSpacing.s32),

                // ── Connectivity ──
                _SectionHeader('Connectivity'),
                const SizedBox(height: AppSpacing.s12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.s12,
                  crossAxisSpacing: AppSpacing.s12,
                  childAspectRatio: 1.4,
                  children: const [
                    MissionHealthTile(icon: Icons.cloud_done_rounded,   label: 'Backend API',       sublabel: 'Connected · 192.168.1.4',  status: HealthStatus.ok),
                    MissionHealthTile(icon: Icons.wifi_rounded,         label: 'Network',            sublabel: 'WiFi · -62 dBm',         status: HealthStatus.ok),
                    MissionHealthTile(icon: Icons.map_rounded,          label: 'Offline Maps',       sublabel: 'Downloaded · 1.2 GB',    status: HealthStatus.ok),
                    MissionHealthTile(icon: Icons.sync_rounded,         label: 'Data Sync',          sublabel: 'Last sync 4m ago',        status: HealthStatus.ok),
                  ],
                ),
                const SizedBox(height: AppSpacing.s32),

                // ── Storage ──
                _SectionHeader('Storage'),
                const SizedBox(height: AppSpacing.s12),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.large), border: Border.all(color: AppColors.border)),
                  child: Column(
                    children: [
                      _StorageRow(label: 'Sonar Logs',   value: 4.2, total: 32.0, color: AppColors.primaryBlue),
                      const SizedBox(height: AppSpacing.s16),
                      _StorageRow(label: 'AI Cache',      value: 2.4, total: 32.0, color: AppColors.warning),
                      const SizedBox(height: AppSpacing.s16),
                      _StorageRow(label: 'Offline Maps',  value: 1.2, total: 32.0, color: AppColors.success),
                      const SizedBox(height: AppSpacing.s16),
                      _StorageRow(label: 'Reports',       value: 0.3, total: 32.0, color: AppColors.information),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title.toUpperCase(), style: AppTextStyles.micro.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2, fontWeight: FontWeight.bold));
  }
}

class _StorageRow extends StatelessWidget {
  final String label;
  final double value, total;
  final Color color;
  const _StorageRow({required this.label, required this.value, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = value / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
            Text('${value.toStringAsFixed(1)} GB', style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: AppColors.surfaceGray, color: color),
        ),
      ],
    );
  }
}
