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

  // ────────────────────────── STREAMS ──────────────────────────

  /// Watch root-level folders (parentId == null).
  Stream<List<Folder>> watchRootFolders() {
    return _foldersCollection
        .where('parentId', isNull: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Folder.fromFirestore(d)).toList());
  }

  /// Watch sub-folders of a given parent.
  Stream<List<Folder>> watchSubFolders(String parentId) {
    return _foldersCollection
        .where('parentId', isEqualTo: parentId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Folder.fromFirestore(d)).toList());
  }

  /// Watch ALL folders (used for legacy code / search).
  Stream<List<Folder>> watchFolders() {
    return _foldersCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Folder.fromFirestore(d)).toList());
  }

  // ────────────────────────── READS ──────────────────────────

  /// Get a single folder by ID.
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

  /// Build the ancestor chain from a folder up to the root.
  /// Returns list from root → ... → current folder (inclusive).
  Future<List<Folder>> getBreadcrumbTrail(String folderId) async {
    final trail = <Folder>[];
    String? currentId = folderId;

    // Safety cap to avoid infinite loops on data corruption.
    int depth = 0;
    const maxDepth = 20;

    while (currentId != null && depth < maxDepth) {
      final folder = await getFolder(currentId);
      if (folder == null) break;
      trail.insert(0, folder);
      currentId = folder.parentId;
      depth++;
    }
    return trail;
  }

  // ────────────────────────── WRITES ──────────────────────────

  /// Create a new folder. [parentId] = null creates a root folder.
  Future<Folder> createFolder({
    required String name,
    String? parentId,
    String? icon,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final trimmed = name.trim();
    if (trimmed.isEmpty) throw Exception('Folder name cannot be empty');
    if (trimmed.length > 100) {
      throw Exception('Folder name too long (max 100 characters)');
    }

    // Duplicate name check inside the same parent.
    final isDuplicate = await _hasDuplicateName(trimmed, parentId);
    if (isDuplicate) {
      throw Exception('A folder with that name already exists here');
    }

    try {
      final now = DateTime.now();
      final docRef = _foldersCollection.doc();

      final folder = Folder(
        id: docRef.id,
        name: trimmed,
        parentId: parentId,
        icon: icon,
        createdBy: userId,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(folder.toFirestore());
      debugPrint('✅ Folder created: ${folder.id} (parent=$parentId)');
      return folder;
    } catch (e) {
      debugPrint('❌ Error creating folder: $e');
      rethrow;
    }
  }

  /// Rename a folder — updates ONLY name + updatedAt.
  Future<void> renameFolder(String folderId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw Exception('Folder name cannot be empty');
    if (trimmed.length > 100) {
      throw Exception('Folder name too long (max 100 characters)');
    }

    // Get folder to know its parentId for duplicate check.
    final folder = await getFolder(folderId);
    if (folder == null) throw Exception('Folder not found');

    final isDuplicate = await _hasDuplicateName(
      trimmed,
      folder.parentId,
      excludeId: folderId,
    );
    if (isDuplicate) {
      throw Exception('A folder with that name already exists here');
    }

    try {
      await _foldersCollection.doc(folderId).update({
        'name': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Folder renamed: $folderId → $trimmed');
    } catch (e) {
      debugPrint('❌ Error renaming folder: $e');
      rethrow;
    }
  }

  /// Update folder icon.
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

  /// Safe delete — only allows deletion if the folder has no files AND no
  /// sub-folders. Caller must handle the error message.
  Future<void> deleteFolder(String folderId) async {
    // Check for sub-folders.
    final subFolders = await _foldersCollection
        .where('parentId', isEqualTo: folderId)
        .limit(1)
        .get();
    if (subFolders.docs.isNotEmpty) {
      throw Exception(
        'Cannot delete: folder contains sub-folders. '
        'Remove them first.',
      );
    }

    // Check for files.
    final files = await _firestore
        .collection('documents')
        .where('folderId', isEqualTo: folderId)
        .limit(1)
        .get();
    if (files.docs.isNotEmpty) {
      throw Exception(
        'Cannot delete: folder contains files. '
        'Remove them first.',
      );
    }

    try {
      await _foldersCollection.doc(folderId).delete();
      debugPrint('✅ Folder deleted: $folderId');
    } catch (e) {
      debugPrint('❌ Error deleting folder: $e');
      rethrow;
    }
  }

  /// Touch folder (update updatedAt timestamp).
  Future<void> touchFolder(String folderId) async {
    try {
      await _foldersCollection.doc(folderId).update({
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error touching folder: $e');
    }
  }

  // ────────────────────────── COUNTS ──────────────────────────

  /// Count documents inside a folder.
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

  /// Count sub-folders inside a folder.
  Future<int> getSubFolderCount(String folderId) async {
    try {
      final snapshot = await _foldersCollection
          .where('parentId', isEqualTo: folderId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting sub-folder count: $e');
      return 0;
    }
  }

  // ────────────────────────── HELPERS ──────────────────────────

  /// Returns true if a folder with [name] already exists under [parentId].
  Future<bool> _hasDuplicateName(
    String name,
    String? parentId, {
    String? excludeId,
  }) async {
    try {
      Query<Map<String, dynamic>> query;
      if (parentId == null) {
        query = _foldersCollection.where('parentId', isNull: true);
      } else {
        query = _foldersCollection.where('parentId', isEqualTo: parentId);
      }

      final snap = await query.get();
      return snap.docs.any(
        (d) =>
            d.id != excludeId &&
            (d.data()['name'] as String).toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      debugPrint('❌ Duplicate check error: $e');
      return false; // Fail open so creation still works.
    }
  }
}
