import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
import '../pages/privacy_security_page.dart';
import 'router_notifier.dart';

/// Widget that checks if current user is admin before showing AdminPanelPage
/// This is a security gate that prevents non-admins from accessing admin panel
/// even if they somehow navigate to /admin route directly
class _AdminGuard extends ConsumerWidget {
  const _AdminGuard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // User not logged in - redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          // User document doesn't exist - redirect to app
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/app');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final role = userData?['role'] as String? ?? 'member';

        if (role != 'admin') {
          // User is not admin - redirect to app
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/app');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is admin - show admin panel
        return const AdminPanelPage();
      },
    );
  }
}

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
      GoRoute(
        path: '/app',
        builder: (context, state) {
          // Handle deep link query parameters from notifications
          final tab = state.uri.queryParameters['tab'];
          final folderId = state.uri.queryParameters['folderId'];
          return AppShellPage(initialTab: tab, initialFolderId: folderId);
        },
      ),
      GoRoute(path: '/admin', builder: (context, state) => const _AdminGuard()),
      GoRoute(
        path: '/stories',
        builder: (context, state) => const StoriesPage(),
      ),
      GoRoute(path: '/chat', builder: (context, state) => const ChatPage()),
      GoRoute(
        path: '/profile/privacy-security',
        builder: (context, state) => const PrivacySecurityPage(),
      ),
    ],
  );
});
