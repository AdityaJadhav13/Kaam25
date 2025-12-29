import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// Service to track user online/offline presence
class PresenceService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  PresenceService(this._firestore, this._auth);

  /// Initialize presence tracking for current user
  /// Call this when app becomes active
  Future<void> goOnline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('presence').doc(user.uid).set({
      'online': true,
      'lastSeen': FieldValue.serverTimestamp(),
      'userId': user.uid,
      'userName': user.displayName ?? user.email ?? 'Unknown',
    }, SetOptions(merge: true));
  }

  /// Mark user as offline
  /// Call this when app goes to background or user logs out
  Future<void> goOffline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('presence').doc(user.uid).set({
      'online': false,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Set up automatic presence management based on app lifecycle
  void setupLifecycleTracking() {
    WidgetsBinding.instance.addObserver(_PresenceLifecycleObserver(this));
  }
}

/// Observer to track app lifecycle for presence
class _PresenceLifecycleObserver extends WidgetsBindingObserver {
  final PresenceService _service;

  _PresenceLifecycleObserver(this._service);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _service.goOnline();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _service.goOffline();
        break;
    }
  }
}
