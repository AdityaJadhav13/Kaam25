import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/app_user.dart';

class UserRepository {
  UserRepository(this._firestore, this._functions);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<AppUser?> fetchUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDocument(doc);
  }

  Stream<AppUser?> streamUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromDocument(doc);
    });
  }

  Future<void> bootstrapUser({
    required User authUser,
    required String deviceId,
    required Map<String, dynamic> deviceInfo,
  }) async {
    try {
      debugPrint('🔄 Calling bootstrapUser function...');
      final callable = _functions.httpsCallable('bootstrapUser');
      final result = await callable.call({
        'uid': authUser.uid,
        'email': authUser.email,
        'name': authUser.displayName,
        'photoUrl': authUser.photoURL,
        'deviceId': deviceId,
        'deviceInfo': deviceInfo,
      });
      debugPrint('✅ bootstrapUser result: ${result.data}');
    } catch (e, stackTrace) {
      debugPrint('❌ bootstrapUser error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> updateLastLogin(String uid) async {
    await _users.doc(uid).update({'lastLogin': FieldValue.serverTimestamp()});
  }

  Future<void> enqueueDeviceApproval({
    required String uid,
    required String deviceId,
    required Map<String, dynamic> deviceInfo,
  }) async {
    final docId = '${uid}_$deviceId';
    final requests = _firestore.collection('login_requests');
    await requests.doc(docId).set({
      'userId': uid,
      'deviceId': deviceId,
      'deviceInfo': deviceInfo,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Update user preferences (theme, notifications)
  Future<void> updatePreferences({
    required String uid,
    String? themePreference,
    bool? notificationsEnabled,
  }) async {
    final updates = <String, dynamic>{};
    if (themePreference != null) updates['themePreference'] = themePreference;
    if (notificationsEnabled != null) {
      updates['notificationsEnabled'] = notificationsEnabled;
    }

    if (updates.isEmpty) return;

    await _users.doc(uid).update(updates);
  }
}
