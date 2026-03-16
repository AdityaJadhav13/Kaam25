import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// UserDataSource - Direct Firestore operations for user documents
/// User creation happens via Cloud Function (NOT client-side)
abstract class UserDataSource {
  Future<bool> userExists(String uid);
  Future<Map<String, dynamic>?> getUser(String uid);
  Future<void> bootstrapUser(User firebaseUser, String deviceId);
  Future<void> createLoginRequest(String uid, String deviceId);
  Stream<Map<String, dynamic>?> streamUser(String uid);
}

/// Firestore implementation of UserDataSource
class FirestoreUserDataSource implements UserDataSource {
  FirestoreUserDataSource({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  }) : _firestore = firestore,
       _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<bool> userExists(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists;
  }

  @override
  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  @override
  Stream<Map<String, dynamic>?> streamUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    });
  }

  @override
  Future<void> bootstrapUser(User firebaseUser, String deviceId) async {
    // Call Cloud Function to create user document
    // Server decides role and approval based on SUPER_ADMIN_UID
    // Client NEVER knows the Super Admin UID
    final callable = _functions.httpsCallable('bootstrapUser');
    await callable.call<Map<String, dynamic>>({
      'uid': firebaseUser.uid,
      'email': firebaseUser.email ?? '',
      'name': firebaseUser.displayName ?? firebaseUser.email ?? 'User',
      'photoUrl': firebaseUser.photoURL,
      'deviceId': deviceId,
      'deviceInfo': {
        'platform': 'flutter',
        'createdAt': DateTime.now().toIso8601String(),
      },
    });
  }

  @override
  Future<void> createLoginRequest(String uid, String deviceId) async {
    // Create a login request for device approval
    // This is called when an approved user logs in from a new device
    final requestRef = _firestore
        .collection('login_requests')
        .doc('${uid}_$deviceId');

    final existing = await requestRef.get();
    if (existing.exists) {
      // Request already exists, don't overwrite
      return;
    }

    await requestRef.set({
      'userId': uid,
      'deviceId': deviceId,
      'deviceInfo': {
        'platform': 'flutter',
        'createdAt': DateTime.now().toIso8601String(),
      },
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
