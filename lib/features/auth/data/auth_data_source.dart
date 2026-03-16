import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// AuthDataSource - Direct Firebase Authentication operations
/// No business logic, only raw Firebase calls
abstract class AuthDataSource {
  Stream<User?> authStateChanges();
  User? get currentUser;
  Future<UserCredential> signInWithEmailPassword(String email, String password);
  Future<UserCredential> signInWithGoogle();
  Future<void> signOut();
}

/// Firebase implementation of AuthDataSource
class FirebaseAuthDataSource implements AuthDataSource {
  FirebaseAuthDataSource({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
  }) : _firebaseAuth = firebaseAuth,
       _googleSignIn = googleSignIn;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  @override
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<UserCredential> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    return await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'sign-in-cancelled',
          message: 'Sign-in was cancelled by user.',
        );
      }

      // Obtain auth details from Google Sign-In
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Validate tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-auth-token',
          message: 'Failed to obtain authentication tokens from Google.',
        );
      }

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credential
      return await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException {
      // Re-throw Firebase exceptions
      rethrow;
    } catch (e) {
      // Convert any other errors to Firebase exceptions
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: 'Google sign-in error: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
  }
}
