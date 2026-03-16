import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'auth_state.dart';
import 'onboarding_provider.dart';

/// RouterNotifier with approval workflow
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    ref.listen(hasSeenOnboardingProvider, (prev, next) {
      notifyListeners();
    });
    ref.listen(authControllerProvider, (prev, next) {
      notifyListeners();
    });
  }

  final Ref ref;

  String? redirect(String location) {
    final hasSeenOnboarding = ref.read(hasSeenOnboardingProvider);
    final auth = ref.read(authControllerProvider);

    final isOnboarding = location == '/onboarding';
    final isLogin = location == '/login';
    final isBlocked = location == '/blocked';
    final isPending = location == '/pending';
    final isDevicePending = location == '/device-pending';
    final isSplash = location == '/splash';

    // First check: Onboarding
    if (!hasSeenOnboarding) {
      return isOnboarding ? null : '/onboarding';
    }

    // ========== ROUTING ORDER (NON-NEGOTIABLE) ==========
    // Matches authorization order in auth_controller.dart
    // 1. loading → splash
    // 2. unauthenticated → login
    // 3. blocked → blocked screen
    // 4. pendingApproval → pending screen
    // 5. devicePending → device-pending screen
    // 6. authenticated → app (or allow current route)
    // ====================================================

    switch (auth.gate) {
      case AuthGate.loading:
        return isSplash ? null : '/splash';

      case AuthGate.unauthenticated:
        return isLogin ? null : '/login';

      case AuthGate.blocked:
        return isBlocked ? null : '/blocked';

      case AuthGate.pendingApproval:
        return isPending ? null : '/pending';

      case AuthGate.devicePending:
        return isDevicePending ? null : '/device-pending';

      case AuthGate.authenticated:
        // Redirect away from auth/pending screens to app
        if (isOnboarding ||
            isLogin ||
            isBlocked ||
            isPending ||
            isDevicePending ||
            isSplash) {
          return '/app';
        }
        // Allow navigation to any other route
        return null;
    }
  }
}

final routerNotifierProvider = Provider<RouterNotifier>(
  (ref) => RouterNotifier(ref),
);
