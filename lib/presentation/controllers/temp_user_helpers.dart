import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Temporary helper during auth reset
/// Provides direct access to Firebase User
/// TODO: Replace with proper AppUser after reset is complete

// Current Firebase Auth user
final currentFirebaseUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// User ID helper (returns null if not authenticated)
final currentUserIdProvider = Provider<String?>((ref) {
  final firebaseUser = FirebaseAuth.instance.currentUser;
  return firebaseUser?.uid;
});

// User email helper
final currentUserEmailProvider = Provider<String?>((ref) {
  final firebaseUser = FirebaseAuth.instance.currentUser;
  return firebaseUser?.email;
});

// User display name helper
final currentUserNameProvider = Provider<String?>((ref) {
  final firebaseUser = FirebaseAuth.instance.currentUser;
  return firebaseUser?.displayName ?? firebaseUser?.email;
});

// Photo URL helper
final currentUserPhotoProvider = Provider<String?>((ref) {
  final firebaseUser = FirebaseAuth.instance.currentUser;
  return firebaseUser?.photoURL;
});
