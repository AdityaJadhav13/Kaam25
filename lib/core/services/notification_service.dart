import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notification preferences service provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
    FirebaseMessaging.instance,
  );
});

class NotificationService {
  NotificationService(this._firestore, this._auth, this._messaging);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseMessaging _messaging;

  /// Initialize notification service and load user preference
  Future<void> initialize() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Request permission first
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        debugPrint('⚠️ Notification permission not granted');
        return;
      }

      // Get and save FCM token
      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ FCM token saved: ${token.substring(0, 20)}...');
      }

      // Subscribe to topics by default (notifications enabled by default)
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final enabled = doc.data()?['notificationsEnabled'] as bool? ?? true;
      
      if (enabled) {
        await _subscribeToTopics();
      } else {
        await _unsubscribeFromTopics();
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _firestore.collection('users').doc(user.uid).update({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }

  /// Toggle notification preference
  Future<void> setNotificationsEnabled(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Get FCM token if enabling
      String? token;
      if (enabled) {
        token = await _messaging.getToken();
      }

      // Update Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'notificationsEnabled': enabled,
        if (token != null) 'fcmToken': token,
        if (token != null) 'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Subscribe or unsubscribe from topics
      if (enabled) {
        await _subscribeToTopics();
      } else {
        await _unsubscribeFromTopics();
      }

      debugPrint('✅ Notifications ${enabled ? "enabled" : "disabled"}');
    } catch (e) {
      debugPrint('❌ Error updating notification preference: $e');
      rethrow;
    }
  }

  /// Get current notification permission status
  Future<bool> get hasPermission async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Subscribe to relevant FCM topics
  Future<void> _subscribeToTopics() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // For iOS, wait for APNS token
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('⏳ Waiting for APNS token...');
          // Wait a bit for APNS token to be available
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      // Get user's role
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final role = doc.data()?['role'] as String? ?? 'member';

      // Subscribe to general topics
      await _messaging.subscribeToTopic('all_users');
      debugPrint('✅ Subscribed to all_users');
      
      await _messaging.subscribeToTopic('announcements');
      debugPrint('✅ Subscribed to announcements');

      // Subscribe to role-specific topics
      if (role == 'admin') {
        await _messaging.subscribeToTopic('admin_notifications');
        debugPrint('✅ Subscribed to admin_notifications');
        
        await _messaging.subscribeToTopic('device_approvals');
        debugPrint('✅ Subscribed to device_approvals');
      }

      debugPrint('✅ Subscribed to all notification topics');
    } catch (e) {
      debugPrint('❌ Error subscribing to topics: $e');
    }
  }

  /// Unsubscribe from all FCM topics
  Future<void> _unsubscribeFromTopics() async {
    try {
      await _messaging.unsubscribeFromTopic('all_users');
      await _messaging.unsubscribeFromTopic('announcements');
      await _messaging.unsubscribeFromTopic('admin_notifications');
      await _messaging.unsubscribeFromTopic('device_approvals');

      debugPrint('✅ Unsubscribed from all topics');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topics: $e');
    }
  }

  /// Get FCM token for this device
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }
}
