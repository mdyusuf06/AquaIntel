import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/detection_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_animations.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  late AnimationController _micCtrl;
  bool _micActive = false;

  @override
  void initState() {
    super.initState();
    _micCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  }

  @override
  void dispose() { _micCtrl.dispose(); super.dispose(); }

  int _navIndex(String path) {
    if (path.startsWith('/map'))     return 1;
    if (path.startsWith('/scan'))    return 2;
    if (path.startsWith('/copilot')) return 3;
    if (path.startsWith('/reports')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final path  = GoRouterState.of(context).uri.path;
    final idx   = _navIndex(path);
    final reds  = context.watch<DetectionProvider>().allDetections.where((d) => d.riskTier == 'red').length;
    final unread = context.watch<NotificationProvider>().unreadCount;

    return Scaffold(
      extendBody: true,
      drawer: _AppDrawer(unread: unread),
      body: widget.child,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(color: AppColors.shadow.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(icon: Icons.home_rounded,     label: 'Home',    selected: idx == 0, onTap: () => context.go('/'),         badge: 0),
                    _NavItem(icon: Icons.map_outlined,      label: 'Map',     selected: idx == 1, onTap: () => context.go('/map'),      badge: reds),
                    // Center Scan FAB
                    _ScanFab(onTap: () => context.go('/scan')),
                    _NavItem(icon: Icons.smart_toy_outlined, label: 'Copilot', selected: idx == 3, onTap: () => context.go('/copilot'), badge: 0),
                    _NavItem(icon: Icons.bar_chart_rounded,  label: 'Reports', selected: idx == 4, onTap: () => context.go('/reports'), badge: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanFab extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: const Icon(Icons.radar_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: AppAnimations.fast,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.veryLightBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Icon(icon, size: 22, color: selected ? AppColors.primaryBlue : AppColors.textSecondary),
                ),
                if (badge > 0)
                  Positioned(
                    top: -2, right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(AppRadius.pill)),
                      child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: AppAnimations.fast,
              style: AppTextStyles.micro.copyWith(
                color: selected ? AppColors.primaryBlue : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Drawer ────────────────────────────────────────────────────────────────────
class _AppDrawer extends StatelessWidget {
  final int unread;
  const _AppDrawer({this.unread = 0});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 300,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
                    child: Center(child: Text('CR', style: AppTextStyles.title.copyWith(color: Colors.white))),
                  ),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Capt. Rodriguez', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                        Text('Mission Operator', style: AppTextStyles.caption.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                        Row(children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('Online', style: AppTextStyles.micro.copyWith(color: AppColors.success)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.s8),
            // Nav items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                children: [
                  _DrawerSection('Mission', [
                    _DrawerTile(icon: Icons.bar_chart_rounded, label: 'Analytics',    route: '/analytics'),
                    _DrawerTile(icon: Icons.view_in_ar_rounded, label: '3D Viewer',   route: '/visualizer'),
                    _DrawerTile(icon: Icons.map_outlined,        label: 'Offline Maps', route: '/offline'),
                  ]),
                  _DrawerSection('System', [
                    _DrawerTile(icon: Icons.notifications_outlined, label: 'Notifications', route: '/notifications', badge: unread),
                    _DrawerTile(icon: Icons.devices_rounded,         label: 'Fleet Devices', route: '/fleet'),
                    _DrawerTile(icon: Icons.memory_rounded,          label: 'Offline Status', route: '/offline-status'),
                  ]),
                  _DrawerSection('Account', [
                    _DrawerTile(icon: Icons.person_outline_rounded,  label: 'Profile',    route: '/profile'),
                    _DrawerTile(icon: Icons.settings_outlined,       label: 'Settings',   route: '/settings'),
                    _DrawerTile(icon: Icons.info_outline_rounded,    label: 'About',      route: '/settings'),
                  ]),
                ],
              ),
            ),
            // Footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Row(
                children: [
                  const Icon(Icons.rocket_launch_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.s8),
                  Text('AquaIntel v4.0.0', style: AppTextStyles.micro.copyWith(color: AppColors.textSecondary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text('LIVE', style: AppTextStyles.micro.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String title;
  final List<_DrawerTile> tiles;
  const _DrawerSection(this.title, this.tiles);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 0, 4),
          child: Text(title.toUpperCase(), style: AppTextStyles.micro.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
        ),
        ...tiles,
        const SizedBox(height: 4),
      ],
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final int badge;
  const _DrawerTile({required this.icon, required this.label, required this.route, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final current = GoRouterState.of(context).uri.path;
    final selected = current == route;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
      tileColor: selected ? AppColors.veryLightBlue : null,
      leading: Icon(icon, size: 20, color: selected ? AppColors.primaryBlue : AppColors.textSecondary),
      title: Text(label, style: AppTextStyles.body.copyWith(
        color: selected ? AppColors.primaryBlue : AppColors.textPrimary,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
      )),
      trailing: badge > 0
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          )
        : null,
      onTap: () { Navigator.pop(context); context.go(route); },
    );
  }
}

