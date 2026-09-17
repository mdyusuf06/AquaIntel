import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode      = false;
  bool _offlineAI     = true;
  bool _voiceAssistant = true;
  bool _gpsTracking   = true;
  bool _heatmapLayer  = true;
  bool _shippingRoutes = false;
  bool _bathymetry    = true;
  String _language    = 'English';
  String _mapStyle    = 'OpenStreetMap';

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
            title: Text('Settings', style: AppTextStyles.title),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: AppSpacing.s8),
              _Section('Appearance', [
                _SwitchTile(icon: Icons.dark_mode_outlined, label: 'Dark Mode',
                  subtitle: 'Switch to dark theme', value: _darkMode, onChanged: (v) => setState(() => _darkMode = v)),
                _DropdownTile(icon: Icons.map_outlined, label: 'Map Style',
                  subtitle: 'Choose base map', value: _mapStyle,
                  options: ['OpenStreetMap', 'Satellite', 'Dark Ocean', 'Minimal'],
                  onChanged: (v) => setState(() => _mapStyle = v!)),
              ]),
              _Section('AI & Processing', [
                _SwitchTile(icon: Icons.memory_rounded, label: 'Offline AI', subtitle: 'Run ONNX model on-device', value: _offlineAI, onChanged: (v) => setState(() => _offlineAI = v)),
                _ActionTile(icon: Icons.update_rounded, label: 'Update AI Models', subtitle: 'Check for new model versions', onTap: () {}),
                _ActionTile(icon: Icons.delete_outline, label: 'Clear AI Cache', subtitle: 'Free local storage', onTap: () {}),
              ]),
              _Section('Language', [
                _DropdownTile(icon: Icons.language_rounded, label: 'Interface Language',
                  subtitle: 'App display language', value: _language,
                  options: ['English', 'Hindi', 'Tamil', 'Telugu', 'Malayalam'],
                  onChanged: (v) => setState(() => _language = v!)),
              ]),
              _Section('Voice Assistant', [
                _SwitchTile(icon: Icons.mic_rounded, label: 'Voice Commands', subtitle: 'Enable Sarvam STT/TTS', value: _voiceAssistant, onChanged: (v) => setState(() => _voiceAssistant = v)),
                _ActionTile(icon: Icons.tune_rounded, label: 'Voice Sensitivity', subtitle: 'Adjust mic sensitivity', onTap: () {}),
              ]),
              _Section('Map Layers', [
                _SwitchTile(icon: Icons.layers_rounded, label: 'Heatmap Overlay', subtitle: 'Show detection density heatmap', value: _heatmapLayer, onChanged: (v) => setState(() => _heatmapLayer = v)),
                _SwitchTile(icon: Icons.directions_boat_outlined, label: 'Shipping Routes', subtitle: 'Display maritime lanes', value: _shippingRoutes, onChanged: (v) => setState(() => _shippingRoutes = v)),
                _SwitchTile(icon: Icons.water_rounded, label: 'Bathymetry', subtitle: 'Show seafloor depth contours', value: _bathymetry, onChanged: (v) => setState(() => _bathymetry = v)),
              ]),
              _Section('GPS & Location', [
                _SwitchTile(icon: Icons.gps_fixed_rounded, label: 'GPS Tracking', subtitle: 'Track vessel position', value: _gpsTracking, onChanged: (v) => setState(() => _gpsTracking = v)),
                _ActionTile(icon: Icons.explore_outlined, label: 'Calibrate Compass', subtitle: 'Improve heading accuracy', onTap: () {}),
              ]),
              _Section('Export', [
                _ActionTile(icon: Icons.storage_rounded, label: 'Export All Data', subtitle: 'Download full survey archive', onTap: () {}),
                _ActionTile(icon: Icons.delete_forever_rounded, label: 'Clear All Surveys', subtitle: 'Remove local survey data', onTap: () {}, isDestructive: true),
              ]),
              _Section('Security', [
                _ActionTile(icon: Icons.fingerprint_rounded, label: 'Biometric Lock', subtitle: 'Require biometrics on open', onTap: () {}),
                _ActionTile(icon: Icons.lock_reset_rounded,  label: 'Change PIN',       subtitle: '4-digit access PIN', onTap: () {}),
              ]),
              _Section('About', [
                _InfoTile(label: 'AquaIntel', value: 'v4.0.0 (Build 240901)'),
                _InfoTile(label: 'Backend',   value: AppConfig.baseUrl),
                _InfoTile(label: 'AI Model',  value: 'TinyUNet v2.1 · FAISS v1.7'),
                _ActionTile(icon: Icons.open_in_new_rounded, label: 'View Licenses', subtitle: 'Open source licenses', onTap: () {}),
              ]),
              const SizedBox(height: 120),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s24, AppSpacing.s24, AppSpacing.s24, AppSpacing.s8),
          child: Text(title.toUpperCase(), style: AppTextStyles.micro.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.medium), border: Border.all(color: AppColors.border)),
          child: Column(
            children: children.asMap().entries.map((e) {
              return Column(children: [
                e.value,
                if (e.key < children.length - 1) const Divider(height: 1, indent: 56),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.icon, required this.label, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.textSecondary, size: 20),
      title:     Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
      subtitle:  Text(subtitle, style: AppTextStyles.micro),
      value:     value,
      activeColor: AppColors.primaryBlue,
      onChanged: onChanged,
    );
  }
}

class _DropdownTile extends StatelessWidget {
  final IconData icon;
  final String label, subtitle, value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  const _DropdownTile({required this.icon, required this.label, required this.subtitle, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title:    Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: AppTextStyles.micro),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
        style: AppTextStyles.caption.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  const _ActionTile({required this.icon, required this.label, required this.subtitle, required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.danger : AppColors.textSecondary;
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500, color: isDestructive ? AppColors.danger : AppColors.textPrimary)),
      subtitle: Text(subtitle, style: AppTextStyles.micro),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
      onTap: onTap,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title:   Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
      trailing: Text(value, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
    );
  }
}
