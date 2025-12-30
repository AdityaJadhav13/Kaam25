import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Theme mode provider that syncs with Firestore
final themeModeProvider = StateNotifierProvider<ThemeController, ThemeMode>((
  ref,
) {
  return ThemeController(FirebaseFirestore.instance, FirebaseAuth.instance);
});

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController(this._firestore, this._auth) : super(ThemeMode.system) {
    _initialize();
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> _initialize() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final preference =
            doc.data()?['themePreference'] as String? ?? 'system';
        state = _themeFromString(preference);
      }
    } catch (e) {
      debugPrint('❌ Error loading theme preference: $e');
    }
  }

  Future<void> setTheme(String preference) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Update UI immediately
      state = _themeFromString(preference);

      // Persist to Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'themePreference': preference,
      });

      debugPrint('✅ Theme updated to: $preference');
    } catch (e) {
      debugPrint('❌ Error updating theme: $e');
      // Revert on error
      _initialize();
    }
  }

  ThemeMode _themeFromString(String preference) {
    switch (preference) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String get currentPreference {
    switch (state) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }
}
