import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted onboarding state provider
/// Uses SharedPreferences to remember if user has completed onboarding
/// This ensures onboarding is only shown ONCE per device installation
class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier() : super(false) {
    _loadFromPrefs();
  }

  static const String _key = 'has_seen_onboarding';

  /// Load persisted state on initialization
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool(_key) ?? false;
      state = hasSeen;
    } catch (e) {
      // If SharedPreferences fails, default to false
      state = false;
    }
  }

  /// Mark onboarding as seen and persist to disk
  Future<void> markSeen() async {
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (e) {
      // State is already updated in memory, disk save failed but that's ok
    }
  }

  /// Reset onboarding state (for testing or re-onboarding)
  Future<void> reset() async {
    state = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      // Ignore errors
    }
  }
}

final hasSeenOnboardingProvider =
    StateNotifierProvider<OnboardingNotifier, bool>(
      (ref) => OnboardingNotifier(),
    );
