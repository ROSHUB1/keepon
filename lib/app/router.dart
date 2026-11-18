import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/activity/presentation/activity_screen.dart';
import '../features/alarm/presentation/alarm_screen.dart';
import '../features/activity/presentation/event_detail_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/onboarding/presentation/permission_guide_screen.dart';
import '../features/protection/presentation/protection_screen.dart';
import '../features/recovery/presentation/recovery_screen.dart';
import '../features/settings/presentation/info_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'shell_scaffold.dart';

/// false until the intro and permission guide are finished (set in main()).
final ValueNotifier<bool> onboardingGate = ValueNotifier<bool>(true);

final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  refreshListenable: onboardingGate,
  redirect: (context, state) {
    final loc = state.matchedLocation;
    final inFlow = loc.startsWith('/onboarding') || loc.startsWith('/setup');
    if (!onboardingGate.value && !inFlow) return '/onboarding';
    return null;
  },
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => ShellScaffold(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/protection', builder: (context, state) => const ProtectionScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/activity', builder: (context, state) => const ActivityScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/recovery', builder: (context, state) => const RecoveryScreen()),
        ]),
      ],
    ),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/alarm', builder: (context, state) => const AlarmScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/setup', builder: (context, state) => const PermissionGuideScreen()),
    GoRoute(
      path: '/event/:id',
      builder: (context, state) => EventDetailScreen(eventId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/info/:topic',
      builder: (context, state) => InfoScreen(topic: state.pathParameters['topic'] ?? ''),
    ),
  ],
);
