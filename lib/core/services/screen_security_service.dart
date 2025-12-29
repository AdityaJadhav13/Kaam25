import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

/// Screen security service
/// - Android: Screenshots and screen recording are BLOCKED via FLAG_SECURE
/// - iOS: Screenshots and screen recording are DETECTED and logged
/// - Tracks violations and enforces automatic suspension
class ScreenSecurityService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  
  static const int _violationThreshold = 3;
  
  ScreenSecurityService(this._firestore, this._auth);

  /// Initialize screen security
  /// - Android: Already blocked via FLAG_SECURE in MainActivity
  /// - iOS: Set up detection listeners
  Future<void> initialize() async {
    if (Platform.isIOS) {
      // Enable iOS screenshot detection
      await ScreenProtector.protectDataLeakageOn();
    }
    // Android: Screenshots and screen recording already blocked via FLAG_SECURE
    // No need for additional setup
  }

  /// Handle screenshot attempt (iOS only, called from screenshot detector)
  Future<void> onScreenshotDetected() async {
    if (Platform.isIOS) {
      await _handleViolation(ViolationType.screenshot);
    }
  }

  /// Handle security violation
  Future<void> _handleViolation(ViolationType type) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      
      // Increment violation counter atomically
      await userRef.update({
        'screenshotAttempts': FieldValue.increment(1),
        'lastViolation': FieldValue.serverTimestamp(),
        'violations': FieldValue.arrayUnion([
          {
            'type': type.name,
            'timestamp': FieldValue.serverTimestamp(),
            'platform': Platform.operatingSystem,
          }
        ]),
      });

      // Check if threshold exceeded
      final userDoc = await userRef.get();
      final attempts = userDoc.data()?['screenshotAttempts'] as int? ?? 0;
      
      if (attempts >= _violationThreshold) {
        // Auto-block user
        await userRef.update({
          'blocked': true,
          'blockedAt': FieldValue.serverTimestamp(),
          'blockedReason': 'Automatic suspension: $attempts security violations',
        });
        
        // Force logout
        await _auth.signOut();
        
        // Trigger admin notification (will be handled by Cloud Function)
      }
    } catch (e) {
      debugPrint('❌ Failed to handle violation: $e');
    }
  }

  /// Show violation warning to user
  void showViolationWarning(BuildContext context) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Screenshots and screen recordings are not allowed in this app.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Dispose resources
  void dispose() {
    // Cleanup if needed
  }
}

enum ViolationType {
  screenshot,
  screenRecording,
}
