import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/detection.dart';
import '../../providers/detection_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/aq_button.dart';
import '../../widgets/aq_card.dart';
import '../../widgets/risk_badge.dart';

class DetectionDetailScreen extends StatelessWidget {
  final String id;
  const DetectionDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DetectionProvider>();
    final d = prov.getById(id);
    
    if (d == null) return Scaffold(appBar: AppBar(title: const Text('Not Found')), body: const Center(child: Text('Detection not found.')));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar with Image ──
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: BackButton(onPressed: () => context.pop(), color: AppColors.textPrimary),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(Icons.mic, color: AppColors.textPrimary),
                    tooltip: 'Ask Advisor',
                    onPressed: () => context.go('/advisor?target=${d.id}'),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1621213324637-251f2e825a0b?q=80&w=2938&auto=format&fit=crop',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                      ),
                    ),
                  ),
                  // Centered 3D Proxy / Sonar visualization
                  Center(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: d.confidence,
                            color: AppTheme.riskColor(d.riskTier),
                            strokeWidth: 4,
                          ),
                          Icon(Icons.radar, color: Colors.white.withValues(alpha: 0.8), size: 48),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Title Area
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.displayType, style: AppTextStyles.headline),
                        const SizedBox(height: AppSpacing.s4),
                        Text('Target ID: ${d.id}', style: AppTextStyles.bodySecondary),
                      ],
                    ),
                    RiskBadge(tier: d.riskTier),
                  ],
                ),
                const SizedBox(height: AppSpacing.s32),
                
                // Metadata Grid
                Text('Metadata', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.s16),
                AqCard(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    children: [
                      _InfoRow(icon: Icons.height, label: 'Real Height', value: '${d.heightM} m'),
                      const Divider(height: AppSpacing.s24),
                      _InfoRow(icon: Icons.water, label: 'Draft Clearance', value: '${d.clearanceM} m'),
                      const Divider(height: AppSpacing.s24),
                      _InfoRow(icon: Icons.location_on, label: 'Position', value: '${d.lat.toStringAsFixed(4)}, ${d.lon.toStringAsFixed(4)}'),
                      const Divider(height: AppSpacing.s24),
                      _InfoRow(icon: Icons.directions_boat, label: 'Nearest Lane', value: '1.2 km SSW'),
                      if (d.impactType != null) ...[
                        const Divider(height: AppSpacing.s24),
                        _InfoRow(
                          icon: Icons.warning_amber_rounded,
                          label: 'Marine Impact',
                          value: '${d.impactType} (${d.impactSeverity})',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s32),

                // AI Analysis
                Text('AI Analysis', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.s16),
                AqCard(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Confidence Score', style: AppTextStyles.bodyLarge),
                          Text('${(d.confidence * 100).toStringAsFixed(0)}%', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: d.confidence,
                          backgroundColor: AppColors.lightBlue,
                          color: AppColors.primaryBlue,
                          minHeight: 12,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s20),
                      Text(
                        'The model has identified this as a potential ${d.displayType.toLowerCase()} with high confidence. Proceed with caution as draft clearance is only ${d.clearanceM}m.',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s32),

                // Actions
                Text('Operator Actions', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.s16),
                Row(
                  children: [
                    Expanded(
                      child: AqButton(
                        label: 'Reject',
                        icon: Icons.close_rounded,
                        type: AqButtonType.secondary,
                        onPressed: () { prov.reject(d.id); context.pop(); },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: AqButton(
                        label: 'Uncertain',
                        icon: Icons.help_outline_rounded,
                        type: AqButtonType.secondary,
                        onPressed: () { prov.markUncertain(d.id); context.pop(); },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: AqButton(
                        label: 'Verify',
                        icon: Icons.check_rounded,
                        onPressed: () { prov.verify(d.id); context.pop(); },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                AqButton(
                  label: 'Relabel Target',
                  icon: Icons.label_outline,
                  type: AqButtonType.ghost,
                  isFullWidth: true,
                  onPressed: () => _showRelabelSheet(context, prov, d),
                ),
                const SizedBox(height: 100), // padding for bottom nav
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showRelabelSheet(BuildContext context, DetectionProvider prov, Detection d) {
    final types = ['ghost_net', 'tire', 'drum', 'wreck', 'unknown'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 48, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: AppSpacing.s24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Relabel as...', style: AppTextStyles.title),
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              ...types.map((t) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
                title: Text(t.replaceAll('_', ' ').replaceFirst(t[0], t[0].toUpperCase()), style: AppTextStyles.bodyLarge),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () { prov.relabel(d.id, t); Navigator.pop(context); },
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.s12),
        Expanded(child: Text(label, style: AppTextStyles.bodySecondary)),
        Text(value, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

