import 'package:firebase_auth/firebase_auth.dart';

import 'auth_data_source.dart';

/// AuthRepository - Business logic layer for authentication
/// Uses AuthDataSource for Firebase operations
/// Handles error transformation to user-friendly messages
class AuthRepository {
  AuthRepository({required AuthDataSource dataSource})
    : _dataSource = dataSource;

  final AuthDataSource _dataSource;

  /// Stream of auth state changes
  Stream<User?> authStateChanges() => _dataSource.authStateChanges();

  /// Get current user (synchronous)
  User? get currentUser => _dataSource.currentUser;

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _dataSource.signInWithEmailPassword(email, password);
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(
        code: e.code,
        message: _getReadableErrorMessage(e.code),
      );
    }
  }

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      return await _dataSource.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(
        code: e.code,
        message: _getReadableErrorMessage(e.code),
      );
    } catch (e) {
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: 'Google sign-in failed: ${e.toString()}',
      );
    }
  }

  /// Sign out from both Firebase and Google
  Future<void> signOut() async {
    await _dataSource.signOut();
  }

  /// Get readable error message from Firebase error code
  String _getReadableErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'sign-in-cancelled':
        return 'Sign-in was cancelled.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
