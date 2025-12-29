import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/folder.dart';

class FoldersRepository {
  FoldersRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _foldersCollection =>
      _firestore.collection('folders');

  /// Get real-time stream of all folders
  Stream<List<Folder>> watchFolders() {
    return _foldersCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Folder.fromFirestore(doc)).toList();
        });
  }

  /// Get a single folder by ID
  Future<Folder?> getFolder(String folderId) async {
    try {
      final doc = await _foldersCollection.doc(folderId).get();
      if (!doc.exists) return null;
      return Folder.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ Error getting folder: $e');
      rethrow;
    }
  }

  /// Create a new folder
  Future<Folder> createFolder({required String name, String? icon}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    if (name.trim().isEmpty) {
      throw Exception('Folder name cannot be empty');
    }

    if (name.length > 100) {
      throw Exception('Folder name too long (max 100 characters)');
    }

    try {
      final now = DateTime.now();
      final docRef = _foldersCollection.doc();

      final folder = Folder(
        id: docRef.id,
        name: name.trim(),
        icon: icon,
        createdBy: userId,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(folder.toFirestore());

      debugPrint('✅ Folder created: ${folder.id}');
      return folder;
    } catch (e) {
      debugPrint('❌ Error creating folder: $e');
      rethrow;
    }
  }

  /// Rename a folder
  Future<void> renameFolder(String folderId, String newName) async {
    if (newName.trim().isEmpty) {
      throw Exception('Folder name cannot be empty');
    }

    if (newName.length > 100) {
      throw Exception('Folder name too long (max 100 characters)');
    }

    try {
      await _foldersCollection.doc(folderId).update({
        'name': newName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Folder renamed: $folderId');
    } catch (e) {
      debugPrint('❌ Error renaming folder: $e');
      rethrow;
    }
  }

  /// Update folder icon
  Future<void> updateFolderIcon(String folderId, String? icon) async {
    try {
      await _foldersCollection.doc(folderId).update({
        'icon': icon,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Folder icon updated: $folderId');
    } catch (e) {
      debugPrint('❌ Error updating folder icon: $e');
      rethrow;
    }
  }

  /// Delete a folder (and all its documents - handled by Firestore rules/functions)
  Future<void> deleteFolder(String folderId) async {
    try {
      await _foldersCollection.doc(folderId).delete();
      debugPrint('✅ Folder deleted: $folderId');
    } catch (e) {
      debugPrint('❌ Error deleting folder: $e');
      rethrow;
    }
  }

  /// Touch folder (update updatedAt timestamp)
  Future<void> touchFolder(String folderId) async {
    try {
      await _foldersCollection.doc(folderId).update({
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error touching folder: $e');
      // Don't rethrow - this is not critical
    }
  }

  /// Get document count for a folder
  Future<int> getDocumentCount(String folderId) async {
    try {
      final snapshot = await _firestore
          .collection('documents')
          .where('folderId', isEqualTo: folderId)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting document count: $e');
      return 0;
    }
  }
}
