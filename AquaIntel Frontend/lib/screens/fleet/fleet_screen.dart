import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/survey_provider.dart';
import '../../theme/app_colors.dart';

class FleetScreen extends StatefulWidget {
  const FleetScreen({super.key});
  @override State<FleetScreen> createState() => _FleetScreenState();
}

class _FleetScreenState extends State<FleetScreen> {
  bool _useMetric = true;
  double _riskThreshold = 0.65;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SurveyProvider>();
    final vessels = prov.vessels;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Fleet & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Vessel list ──
          Text('Active Fleet', style: tt.titleMedium),
          const SizedBox(height: 12),
          ...vessels.map((v) {
            final synced = v.syncStatus == 'synced';
            final ago = _timeAgo(v.lastSync);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                  child: Text(v.type, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                ),
                title: Text(v.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('Last sync: $ago', style: tt.labelSmall),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: synced ? AppColors.successBg : AppColors.warningBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: (synced ? AppColors.success : AppColors.warning).withValues(alpha: 0.4)),
                      ),
                      child: Text(synced ? 'Synced' : 'Pending',
                        style: TextStyle(color: synced ? AppColors.success : AppColors.warning, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          // ── Storage mode ──
          Text('Storage Mode', style: tt.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(prov.offlineMode ? Icons.storage : Icons.cloud_sync, color: AppColors.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(prov.offlineMode ? 'Offline (SQLite)' : 'Cloud Sync', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(prov.offlineMode ? 'Data stored locally' : 'Syncing to backend', style: tt.labelSmall),
                  ])),
                  Switch(
                    value: prov.offlineMode,
                    activeColor: AppColors.primaryBlue,
                    onChanged: (_) => prov.toggleOfflineMode(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // ── App Settings ──
          Text('App Settings', style: tt.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Metric Units (m)', style: TextStyle(fontSize: 14)),
                  subtitle: Text(_useMetric ? 'Using metres' : 'Using feet', style: tt.labelSmall),
                  value: _useMetric,
                  activeColor: AppColors.primaryBlue,
                  onChanged: (v) => setState(() => _useMetric = v),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('Risk Threshold', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text('${(_riskThreshold * 100).round()}%', style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                      ]),
                      Slider(
                        value: _riskThreshold,
                        min: 0.3, max: 0.95, divisions: 13,
                        activeColor: AppColors.primaryBlue,
                        onChanged: (v) => setState(() => _riskThreshold = v),
                      ),
                      Text('Detections below this confidence are deprioritized', style: tt.labelSmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: AppColors.primaryBlue),
              title: const Text('AquaIntel v4.0.0', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('AI-Powered Sonar Debris Detection', style: TextStyle(fontSize: 12)),
              trailing: const Text('Build 240831', style: TextStyle(fontSize: 11, color: Color(0xFF90A4AE))),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day${diff.inDays != 1 ? "s" : ""} ago';
  }
}

