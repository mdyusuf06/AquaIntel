import 'package:go_router/go_router.dart';

import 'screens/shell/main_shell.dart';
import 'screens/home/home_screen.dart';
import 'screens/upload/upload_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/detail/detection_detail_screen.dart';
import 'screens/advisor/advisor_screen.dart';
import 'screens/fleet/fleet_screen.dart';
import 'screens/visualizer/visualizer_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/survey/new_survey_screen.dart';
import 'screens/scan/scan_screen.dart';
import 'screens/copilot/copilot_screen.dart';
import 'screens/reports/reports_screen.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // ── Shell routes (with bottom nav) ──────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (c, s) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/map',
            pageBuilder: (c, s) => const NoTransitionPage(child: MapScreen()),
            routes: [
              GoRoute(
                path: 'detail/:id',
                builder: (c, s) =>
                    DetectionDetailScreen(id: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/advisor',
            pageBuilder: (c, s) {
              final targetId = s.uri.queryParameters['target'];
              return NoTransitionPage(
                child: AdvisorScreen(preloadedTargetId: targetId),
              );
            },
          ),
          GoRoute(
            path: '/visualizer',
            pageBuilder: (c, s) => const NoTransitionPage(child: VisualizerScreen()),
          ),
          GoRoute(
            path: '/fleet',
            pageBuilder: (c, s) => const NoTransitionPage(child: FleetScreen()),
          ),
          GoRoute(
            path: '/scan',
            pageBuilder: (c, s) => const NoTransitionPage(child: ScanScreen()),
          ),
          GoRoute(
            path: '/copilot',
            pageBuilder: (c, s) => const NoTransitionPage(child: CopilotScreen()),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (c, s) => const NoTransitionPage(child: ReportsScreen()),
          ),
        ],
      ),

      // ── Top-level routes (no bottom nav) ────────────────────────────
      GoRoute(
        path: '/upload',
        builder: (c, s) => const UploadScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (c, s) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/survey/new',
        builder: (c, s) => const NewSurveyScreen(),
      ),
    ],
  );
}

