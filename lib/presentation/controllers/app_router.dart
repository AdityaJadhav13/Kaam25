import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../pages/admin_panel_page.dart';
import '../pages/app_shell_page.dart';
import '../pages/blocked_page.dart';
import '../pages/chat_page.dart';
import '../pages/device_pending_page.dart';
import '../pages/login_page.dart';
import '../pages/onboarding_page.dart';
import '../pages/pending_approval_page.dart';
import '../pages/splash_page.dart';
import '../pages/stories_page.dart';
import 'router_notifier.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) => notifier.redirect(state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/pending',
        builder: (context, state) => const PendingApprovalPage(),
      ),
      GoRoute(
        path: '/device-pending',
        builder: (context, state) => const DevicePendingPage(),
      ),
      GoRoute(
        path: '/blocked',
        builder: (context, state) => const BlockedPage(),
      ),
      GoRoute(path: '/app', builder: (context, state) => const AppShellPage()),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminPanelPage(),
      ),
      GoRoute(
        path: '/stories',
        builder: (context, state) => const StoriesPage(),
      ),
      GoRoute(path: '/chat', builder: (context, state) => const ChatPage()),
    ],
  );
});
