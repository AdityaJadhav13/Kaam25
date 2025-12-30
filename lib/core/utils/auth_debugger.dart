import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Debug utility class for authentication troubleshooting
class AuthDebugger {
  static void logAuthState() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('🔍 Auth Debug: No user signed in');
      return;
    }

    debugPrint('🔍 Auth Debug:');
    debugPrint('  UID: ${user.uid}');
    debugPrint('  Email: ${user.email}');
    debugPrint('  Display Name: ${user.displayName}');
    debugPrint('  Email Verified: ${user.emailVerified}');
    debugPrint('  Phone Number: ${user.phoneNumber}');
    debugPrint('  Photo URL: ${user.photoURL}');
    debugPrint(
      '  Provider Data: ${user.providerData.map((p) => p.providerId).join(', ')}',
    );
    debugPrint('  Creation Time: ${user.metadata.creationTime}');
    debugPrint('  Last Sign In: ${user.metadata.lastSignInTime}');
  }

  static Future<void> logFirestoreUserState(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!doc.exists) {
        debugPrint('🔍 Firestore Debug: User document does not exist');
        return;
      }

      final data = doc.data();
      debugPrint('🔍 Firestore Debug:');
      debugPrint('  Name: ${data?['name']}');
      debugPrint('  Email: ${data?['email']}');
      debugPrint('  Role: ${data?['role']}');
      debugPrint('  Approved: ${data?['approved']}');
      debugPrint('  Blocked: ${data?['blocked']}');
      debugPrint('  Devices: ${data?['devices']}');
      debugPrint('  Created At: ${data?['createdAt']}');
      debugPrint('  Last Login: ${data?['lastLogin']}');
    } catch (e) {
      debugPrint('🔍 Firestore Debug Error: $e');
    }
  }

  static void logAuthError(String context, dynamic error) {
    debugPrint('❌ Auth Error ($context):');
    if (error is FirebaseAuthException) {
      debugPrint('  Code: ${error.code}');
      debugPrint('  Message: ${error.message}');
      debugPrint('  Plugin: ${error.plugin}');
      debugPrint('  Stack Trace: ${error.stackTrace}');
    } else {
      debugPrint('  Error: $error');
    }
  }

  static String getReadableAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'No account found with this email. Please contact admin.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact admin.';
      case 'too-many-requests':
        return 'Too many failed login attempts. Please wait and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Please contact admin.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check and try again.';
      case 'account-exists-with-different-credential':
        return 'An account with this email already exists. Try signing in with a different method.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in instead.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please sign in again.';
      case 'provider-already-linked':
        return 'This account is already linked to this provider.';
      case 'credential-already-in-use':
        return 'This credential is already associated with a different account.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return error.message ??
            'Authentication failed. Please try again or contact support.';
    }
  }
}
