import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  AuthRepository(this._auth, this._googleSignIn);

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      // Sign out first to ensure clean state and force account selection
      await _googleSignIn.signOut();

      // Attempt sign in
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw FirebaseAuthException(
          code: 'google-cancelled',
          message: 'Sign-in was cancelled.',
        );
      }

      final auth = await account.authentication;

      // Verify we have the required tokens
      if (auth.accessToken == null || auth.idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-google-tokens',
          message: 'Failed to get Google authentication tokens.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      return _auth.signInWithCredential(credential);
    } catch (e) {
      // If it's already a FirebaseAuthException, rethrow it
      if (e is FirebaseAuthException) {
        rethrow;
      }
      // Otherwise wrap it in a FirebaseAuthException
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: 'Google sign-in failed: ${e.toString()}',
      );
    }
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }
}
