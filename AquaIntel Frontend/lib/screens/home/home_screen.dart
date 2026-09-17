import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/load_state.dart';
import '../../providers/detection_provider.dart';
import '../../providers/survey_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_animations.dart';

import '../../widgets/aq_button.dart';
import '../../widgets/aq_card.dart';
import '../../widgets/detection_card.dart';
import '../../widgets/filter_chip_row.dart';
import '../../widgets/shimmer_card.dart';
import '../../widgets/mission_health_tile.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stat_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  bool _searchFocused = false;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final detProv  = context.watch<DetectionProvider>();
    final surProv  = context.watch<SurveyProvider>();
    final notifProv = context.watch<NotificationProvider>();
    final dets     = detProv.filteredDetections;
    final survey   = surProv.activeSurvey;
    final weather  = surProv.weather;
    final unread   = notifProv.unreadCount;

    final isLoading = detProv.isLoading || surProv.isLoading;
    final reds   = detProv.allDetections.where((d) => d.riskTier == 'red').length;
    final ambers = detProv.allDetections.where((d) => d.riskTier == 'amber').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([detProv.load(), surProv.load()]);
        },
        color: AppColors.primaryBlue,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(AppSpacing.s24, MediaQuery.of(context).padding.top + AppSpacing.s16, AppSpacing.s24, AppSpacing.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Drawer avatar
                        Builder(builder: (ctx) => GestureDetector(
                          onTap: () => Scaffold.of(ctx).openDrawer(),
                          child: Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text('CR', style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold))),
                          ),
                        )),
                        const SizedBox(width: AppSpacing.s14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Good morning,', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                              Text('Capt. Rodriguez', style: AppTextStyles.title),
                            ],
                          ),
                        ),
                        // Red alert badge
                        if (reds > 0)
                          GestureDetector(
                            onTap: () => context.go('/risk'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s6),
                              decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(AppRadius.pill), border: Border.all(color: AppColors.danger.withValues(alpha: 0.3))),
                              child: Row(children: [
                                const Icon(Icons.warning_rounded, color: AppColors.danger, size: 14),
                                const SizedBox(width: 4),
                                Text('$reds Red', style: AppTextStyles.micro.copyWith(color: AppColors.danger, fontWeight: FontWeight.bold)),
                              ]),
                            ),
                          ),
                        const SizedBox(width: AppSpacing.s8),
                        // Notification bell
                        GestureDetector(
                          onTap: () => context.go('/notifications'),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(color: AppColors.surfaceGray, shape: BoxShape.circle),
                                child: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary, size: 22),
                              ),
                              if (unread > 0)
                                Positioned(
                                  top: 0, right: 0,
                                  child: Container(
                                    width: 16, height: 16,
                                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                                    child: Center(child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    // ── Search Bar ──
                    AnimatedContainer(
                      duration: AppAnimations.fast,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGray,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: _searchFocused ? AppColors.primaryBlue : AppColors.border, width: _searchFocused ? 1.5 : 1),
                      ),
                      child: Row(
                        children: [
                          const Padding(padding: EdgeInsets.only(left: AppSpacing.s16), child: Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20)),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              style: AppTextStyles.body,
                              onChanged: (_) => setState(() {}),
                              onTap: () => setState(() => _searchFocused = true),
                              onTapOutside: (_) => setState(() => _searchFocused = false),
                              decoration: InputDecoration(
                                hintText: 'Search detections, locations...',
                                hintStyle: AppTextStyles.body.copyWith(color: AppColors.textDisabled),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s14),
                              ),
                            ),
                          ),
                          if (_searchCtrl.text.isNotEmpty)
                            GestureDetector(
                              onTap: () { _searchCtrl.clear(); setState(() {}); },
                              child: const Padding(padding: EdgeInsets.only(right: AppSpacing.s12), child: Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary)),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.s8),
                            child: IconButton(
                              icon: const Icon(Icons.mic_rounded, size: 20),
                              color: AppColors.primaryBlue,
                              onPressed: () => context.go('/copilot'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Filter Chips ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                      child: FilterChipRow(
                        selected: detProv.typeFilter,
                        onChanged: detProv.setTypeFilter,
                        chips: const {
                          'all':       'All',
                          'ghost_net': 'Ghost Nets',
                          'rope':      'Ropes',
                          'drum':      'Drums',
                          'wreck':     'Wrecks',
                          'plastic':   'Plastic',
                          'pipeline':  'Pipeline',
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s24, AppSpacing.s24, AppSpacing.s24, 140),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Weather Card ──
                  if (surProv.weatherState == LoadState.loading)
                    const ShimmerCard(height: 140)
                  else if (weather != null)
                    _WeatherCard(weather: weather),
                  const SizedBox(height: AppSpacing.s24),

                  // ── Today's Mission ──
                  Text('Today\'s Mission', style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.s12),
                  if (survey != null)
                    _MissionCard(survey: survey)
                  else
                    AqCard(
                      padding: const EdgeInsets.all(AppSpacing.s20),
                      child: Row(
                        children: [
                          const Icon(Icons.explore_off_rounded, size: 32, color: AppColors.textSecondary),
                          const SizedBox(width: AppSpacing.s16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('No active mission', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                                Text('Start a new survey to begin scanning', style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                           AqButton(label: 'New Survey', onPressed: () => context.go('/scan')),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.s32),

                  // ── AI Insights ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('AI Insights', style: AppTextStyles.title),
                      TextButton(onPressed: () => context.go('/copilot'), child: Text('Ask AI', style: AppTextStyles.caption.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _InsightCard(icon: Icons.warning_rounded,        label: 'High Risk Zone',          sublabel: reds > 0 ? '$reds active' : 'None', color: reds > 0 ? AppColors.danger : AppColors.success),
                        _InsightCard(icon: Icons.radar_rounded,           label: 'Ghost Net Cluster',       sublabel: 'Zone B detected', color: AppColors.warning),
                        _InsightCard(icon: Icons.visibility_off_rounded,  label: 'Poor Visibility',          sublabel: weather != null ? '${(weather.visibilityM / 1000).toStringAsFixed(1)} km' : 'N/A', color: AppColors.information),
                        _InsightCard(icon: Icons.air_rounded,             label: 'Strong Current',           sublabel: weather != null ? '${weather.windSpeedKmh.toStringAsFixed(0)} km/h' : 'N/A', color: AppColors.primaryBlue),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s32),

                  // ── Recent Detections ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Detections', style: AppTextStyles.title),
                      GestureDetector(
                        onTap: () => context.go('/map'),
                        child: Text('View all', style: AppTextStyles.caption.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  if (isLoading)
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 3,
                        itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(right: AppSpacing.s12), child: ShimmerCard(width: 200, height: 160)),
                      ),
                    )
                  else if (dets.isEmpty)
                    const EmptyState(type: EmptyStateType.noDetections)
                  else
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: dets.take(6).length,
                        itemBuilder: (_, i) {
                          final d = dets[i];
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.s12),
                            child: DetectionCard(
                              detection: d,
                              onTap: () => context.go('/map/detail/${d.id}'),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: AppSpacing.s32),

                  // ── Mission Stats ──
                  Text('Mission Stats', style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.s12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.s12,
                    crossAxisSpacing: AppSpacing.s12,
                    childAspectRatio: 1.3,
                    children: [
                      StatCard(label: 'Total Targets', value: '${detProv.allDetections.length}', icon: Icons.radar_rounded, sparklineData: const [3,5,4,7,6,8,9]),
                      StatCard(label: 'Red Alerts',   value: '$reds',   icon: Icons.warning_rounded, color: AppColors.danger, bgColor: AppColors.dangerBg, sparklineData: const [1,2,1,3,2,4,5]),
                      StatCard(label: 'Amber Alerts', value: '$ambers', icon: Icons.error_outline_rounded, color: AppColors.warning, bgColor: AppColors.warningBg, sparklineData: const [2,3,4,2,5,3,4]),
                      StatCard(label: 'Coverage',     value: '${survey != null ? (survey.progressPct * 100).toStringAsFixed(0) : 0}%', icon: Icons.map_outlined, sparklineData: const [20,35,50,60,75,80,85]),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s32),

                  // ── Mission Health ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('System Health', style: AppTextStyles.title),
                      GestureDetector(
                        onTap: () => context.go('/offline-status'),
                        child: Text('Details', style: AppTextStyles.caption.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: AppSpacing.s8,
                    crossAxisSpacing: AppSpacing.s8,
                    childAspectRatio: 1.15,
                    children: const [
                      MissionHealthTile(icon: Icons.storage_rounded,     label: 'Storage',    sublabel: 'Online',   status: HealthStatus.ok),
                      MissionHealthTile(icon: Icons.gps_fixed_rounded,   label: 'GPS',        sublabel: '8 sats',   status: HealthStatus.ok),
                      MissionHealthTile(icon: Icons.memory_rounded,      label: 'AI Engine',  sublabel: 'Running',  status: HealthStatus.ok),
                      MissionHealthTile(icon: Icons.battery_4_bar_rounded, label: 'Battery',  sublabel: '87%',      status: HealthStatus.ok),
                      MissionHealthTile(icon: Icons.wifi_rounded,        label: 'Network',    sublabel: '-62 dBm',  status: HealthStatus.ok),
                      MissionHealthTile(icon: Icons.device_hub_rounded,  label: 'Edge Device', sublabel: 'Online',  status: HealthStatus.ok),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Weather Card ─────────────────────────────────────────────────────────────
class _WeatherCard extends StatelessWidget {
  final dynamic weather; // WeatherData
  const _WeatherCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    return AqCard(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_rounded, color: AppColors.warning, size: 18),
              const SizedBox(width: AppSpacing.s8),
              Text('Sea Conditions', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('Updated now', style: AppTextStyles.micro.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          Row(
            children: [
              Text('${weather.tempC.toStringAsFixed(0)}°C', style: AppTextStyles.display.copyWith(color: AppColors.textPrimary)),
              const Spacer(),
              Wrap(
                spacing: AppSpacing.s16,
                children: [
                  _WeatherStat(icon: Icons.air_rounded,       label: '${weather.windSpeedKmh.toStringAsFixed(0)} km/h', sublabel: 'Wind'),
                  _WeatherStat(icon: Icons.visibility_rounded, label: '${(weather.visibilityM / 1000).toStringAsFixed(1)} km', sublabel: 'Vis'),
                  _WeatherStat(icon: Icons.waves_rounded,      label: '1.2m',                       sublabel: 'Wave'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherStat extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  const _WeatherStat({required this.icon, required this.label, required this.sublabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryBlue),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
        Text(sublabel, style: AppTextStyles.micro.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Mission Progress Card ─────────────────────────────────────────────────────
class _MissionCard extends StatelessWidget {
  final dynamic survey;
  const _MissionCard({required this.survey});

  @override
  Widget build(BuildContext context) {
    final pct = (survey.progressPct as num?)?.toDouble() ?? 0.85;
    return AqCard(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Row(
        children: [
          // Progress ring
          SizedBox(
            width: 64, height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: pct,
                  strokeWidth: 6,
                  backgroundColor: AppColors.lightBlue,
                  color: AppColors.primaryBlue,
                  strokeCap: StrokeCap.round,
                ),
                Text('${(pct * 100).toStringAsFixed(0)}%', style: AppTextStyles.micro.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(survey.id, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.s4),
                Text('${(survey.areaKm2).toStringAsFixed(1)} km² covered', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.s8),
                AqButton(label: 'Resume', onPressed: () => context.go('/scan')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI Insight Card ───────────────────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  final Color color;
  const _InsightCard({required this.icon, required this.label, required this.sublabel, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadow.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.small)),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text(sublabel, style: AppTextStyles.micro.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

