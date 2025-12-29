import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'auth_state.dart';
import 'onboarding_provider.dart';

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    // Listen to provider changes and notify GoRouter to refresh
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
    final isPending = location == '/pending';
    final isBlocked = location == '/blocked';
    final isDevicePending = location == '/device-pending';
    final isSplash = location == '/splash';

    if (!hasSeenOnboarding) {
      return isOnboarding ? null : '/onboarding';
    }

    switch (auth.gate) {
      case AuthGate.loading:
        return isSplash ? null : '/splash';
      case AuthGate.unauthenticated:
        return isLogin ? null : '/login';
      case AuthGate.pendingApproval:
        return isPending ? null : '/pending';
      case AuthGate.blocked:
        return isBlocked ? null : '/blocked';
      case AuthGate.devicePending:
        return isDevicePending ? null : '/device-pending';
      case AuthGate.authorized:
        if (isOnboarding ||
            isLogin ||
            isPending ||
            isBlocked ||
            isDevicePending ||
            isSplash) {
          return '/app';
        }
        return null;
    }
  }
}

final routerNotifierProvider = Provider<RouterNotifier>(
  (ref) => RouterNotifier(ref),
);
