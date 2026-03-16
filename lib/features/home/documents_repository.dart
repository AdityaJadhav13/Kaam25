import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../../data/models/document.dart';

class DocumentsRepository {
  DocumentsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _documentsCollection =>
      _firestore.collection('documents');

  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50 MB

  static const List<String> supportedExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'jpg',
    'jpeg',
    'png',
    'txt',
    'csv',
  ];

  // ────────────────────────── STREAMS ──────────────────────────

  /// Get real-time stream of documents in a folder.
  Stream<List<Document>> watchDocuments(String folderId) {
    return _documentsCollection
        .where('folderId', isEqualTo: folderId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Document.fromFirestore(d)).toList());
  }

  // ────────────────────────── READS ──────────────────────────

  /// Get a single document by ID.
  Future<Document?> getDocument(String documentId) async {
    try {
      final doc = await _documentsCollection.doc(documentId).get();
      if (!doc.exists) return null;
      return Document.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ Error getting document: $e');
      rethrow;
    }
  }

  // ────────────────────────── UPLOAD ──────────────────────────

  /// Upload a document to Firebase Storage and save metadata to Firestore.
  ///
  /// Storage path is **fileId-based** (`files/{fileId}/original`) so that
  /// renaming the file or its parent folder never breaks the path.
  Future<Document> uploadDocument({
    required String folderId,
    required File file,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Validate file size
    final fileSize = await file.length();
    if (fileSize > maxFileSizeBytes) {
      throw Exception('File too large (max 50 MB)');
    }

    // Validate file type
    final extension = path
        .extension(fileName)
        .toLowerCase()
        .replaceAll('.', '');
    if (!supportedExtensions.contains(extension)) {
      throw Exception(
        'Unsupported file type. Supported: ${supportedExtensions.join(", ")}',
      );
    }

    try {
      // Generate a Firestore doc first so we have the ID for the storage path.
      final docRef = _documentsCollection.doc();
      final fileId = docRef.id;

      // ── STORAGE PATH: fileId-based, never folder-name-based ──
      final storagePath = 'files/$fileId/original';

      // Upload to Firebase Storage
      final storageRef = _storage.ref().child(storagePath);
      final uploadTask = storageRef.putFile(file);

      // Track upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      final snapshot = await uploadTask;
      if (snapshot.state != TaskState.success) {
        throw Exception('Upload failed');
      }

      // Get download URL (internal use only — never exposed publicly)
      final downloadUrl = await storageRef.getDownloadURL();

      final now = DateTime.now();
      final document = Document(
        id: fileId,
        folderId: folderId,
        fileName: fileName,
        fileType: extension,
        fileSize: fileSize,
        storagePath: storagePath,
        uploadedBy: userId,
        uploadedAt: now,
        updatedAt: now,
        downloadUrl: downloadUrl,
      );

      await docRef.set(document.toFirestore());

      // Touch parent folder
      await _firestore.collection('folders').doc(folderId).update({
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Document uploaded: $fileId (storage=$storagePath)');
      return document;
    } catch (e) {
      debugPrint('❌ Error uploading document: $e');
      rethrow;
    }
  }

  // ────────────────────────── RENAME ──────────────────────────

  /// Rename a document — updates ONLY metadata. Storage path is untouched.
  Future<void> renameDocument(String documentId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw Exception('File name cannot be empty');
    if (trimmed.length > 200) {
      throw Exception('File name too long (max 200 characters)');
    }

    try {
      await _documentsCollection.doc(documentId).update({
        'fileName': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Document renamed: $documentId → $trimmed');
    } catch (e) {
      debugPrint('❌ Error renaming document: $e');
      rethrow;
    }
  }

  // ────────────────────────── DELETE ──────────────────────────

  /// Delete a document (removes from Storage and Firestore).
  Future<void> deleteDocument(String documentId) async {
    try {
      final doc = await getDocument(documentId);
      if (doc == null) throw Exception('Document not found');

      // Delete from Storage
      try {
        final storageRef = _storage.ref().child(doc.storagePath);
        await storageRef.delete();
      } catch (e) {
        debugPrint('⚠️  Error deleting from storage (may not exist): $e');
      }

      // Delete from Firestore
      await _documentsCollection.doc(documentId).delete();

      // Touch parent folder
      await _firestore.collection('folders').doc(doc.folderId).update({
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Document deleted: $documentId');
    } catch (e) {
      debugPrint('❌ Error deleting document: $e');
      rethrow;
    }
  }

  // ────────────────────────── URL ──────────────────────────

  /// Get download URL for a document (internal use only).
  Future<String> getDownloadUrl(String documentId) async {
    try {
      final doc = await getDocument(documentId);
      if (doc == null) throw Exception('Document not found');

      if (doc.downloadUrl != null) return doc.downloadUrl!;

      final storageRef = _storage.ref().child(doc.storagePath);
      final url = await storageRef.getDownloadURL();

      // Cache the URL
      await _documentsCollection.doc(documentId).update({'downloadUrl': url});
      return url;
    } catch (e) {
      debugPrint('❌ Error getting download URL: $e');
      rethrow;
    }
  }

  // ────────────────────────── HELPERS ──────────────────────────

  /// Check if file type is supported.
  static bool isFileTypeSupported(String fileName) {
    final extension = path
        .extension(fileName)
        .toLowerCase()
        .replaceAll('.', '');
    return supportedExtensions.contains(extension);
  }

  /// Get emoji icon for a file type.
  static String getFileIcon(String fileName) {
    final extension = path
        .extension(fileName)
        .toLowerCase()
        .replaceAll('.', '');
    switch (extension) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      case 'xls':
      case 'xlsx':
      case 'csv':
        return '📊';
      case 'ppt':
      case 'pptx':
        return '📽️';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return '🖼️';
      case 'txt':
        return '📋';
      default:
        return '📎';
    }
  }
}
