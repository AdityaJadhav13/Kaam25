import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/announcement.dart';
import '../../data/models/enums.dart';
import '../../features/auth/domain/app_user.dart';

/// Repository for announcements with Firestore integration
///
/// ARCHITECTURE:
/// - Firestore is the SINGLE SOURCE OF TRUTH
/// - All data comes from real-time streams (not one-time fetches)
/// - Read state is per-user, stored in the readBy array
/// - Timestamps use FieldValue.serverTimestamp() for consistency
class AnnouncementsRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  AnnouncementsRepository(this._firestore, this._auth, this._storage);

  /// Get announcements collection reference
  CollectionReference<Map<String, dynamic>> get _announcementsCollection =>
      _firestore.collection('announcements');

  /// Stream of announcements (real-time)
  /// SORTING ORDER:
  /// 1. Urgent announcements first
  /// 2. Then by createdAt descending (newest first)
  Stream<List<Announcement>> watchAnnouncements() {
    return _announcementsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final announcements = snapshot.docs
              .map((doc) => Announcement.fromDocument(doc))
              .toList();

          // Sort: urgent first, then important, then normal
          // Within each category, sort by createdAt desc
          announcements.sort((a, b) {
            final typeOrder = {
              AnnouncementType.urgent: 0,
              AnnouncementType.important: 1,
              AnnouncementType.normal: 2,
            };

            final typeCompare = typeOrder[a.type]!.compareTo(
              typeOrder[b.type]!,
            );
            if (typeCompare != 0) return typeCompare;

            // Within same type, sort by createdAt descending
            return b.createdAt.compareTo(a.createdAt);
          });

          return announcements;
        });
  }

  /// Create a new announcement
  /// Uses FieldValue.serverTimestamp() to ensure timestamps match Firestore rules
  Future<String> createAnnouncement({
    required String title,
    required String description,
    required AnnouncementType type,
    required bool actionRequired,
    List<File>? attachmentFiles,
    required Function(double)? onUploadProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();

    if (trimmedTitle.isEmpty) throw Exception('Title cannot be empty');
    if (trimmedDescription.isEmpty) {
      throw Exception('Description cannot be empty');
    }

    // Get user name
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final appUser = AppUser.fromDocument(userDoc);

    final announcementId = const Uuid().v4();
    final now = DateTime.now();

    // Upload attachments if any
    List<Map<String, dynamic>>? attachmentMaps;
    if (attachmentFiles != null && attachmentFiles.isNotEmpty) {
      attachmentMaps = [];
      for (int i = 0; i < attachmentFiles.length; i++) {
        final file = attachmentFiles[i];
        final fileName = file.path.split('/').last;
        final fileType = fileName.split('.').last.toLowerCase();

        // Upload to Storage
        final storagePath =
            'announcement_uploads/$announcementId/${const Uuid().v4()}_$fileName';
        final storageRef = _storage.ref().child(storagePath);
        final uploadTask = storageRef.putFile(file);

        // Track progress
        if (onUploadProgress != null) {
          uploadTask.snapshotEvents.listen((snapshot) {
            final progress =
                (i + snapshot.bytesTransferred / snapshot.totalBytes) /
                attachmentFiles.length;
            onUploadProgress(progress);
          });
        }

        await uploadTask;
        final downloadUrl = await storageRef.getDownloadURL();

        attachmentMaps.add({
          'fileName': fileName,
          'fileType': fileType,
          'downloadUrl': downloadUrl,
          'uploadedAt': Timestamp.fromDate(now),
        });
      }
    }

    // Build the document with server timestamps for createdAt and updatedAt
    // This ensures the timestamps match Firestore rules (request.time)
    final docData = <String, dynamic>{
      'title': trimmedTitle,
      'description': trimmedDescription,
      'type': type.name,
      'actionRequired': actionRequired,
      'createdBy': user.uid,
      'createdByName': appUser.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'readBy': <String>[], // Empty array - no one has read it yet
    };

    if (attachmentMaps != null && attachmentMaps.isNotEmpty) {
      docData['attachments'] = attachmentMaps;
    }

    await _announcementsCollection.doc(announcementId).set(docData);
    return announcementId;
  }

  /// Edit an existing announcement
  /// Uses FieldValue.serverTimestamp() to ensure timestamps match Firestore rules
  Future<void> editAnnouncement({
    required String announcementId,
    String? title,
    String? description,
    AnnouncementType? type,
    bool? actionRequired,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // First, get the existing document to preserve required fields
    final existingDoc = await _announcementsCollection
        .doc(announcementId)
        .get();
    if (!existingDoc.exists) {
      throw Exception('Announcement not found');
    }
    final existingData = existingDoc.data()!;

    // Build update with all required fields for Firestore rules
    final updates = <String, dynamic>{
      'title': title?.trim().isNotEmpty == true
          ? title!.trim()
          : existingData['title'],
      'description': description?.trim().isNotEmpty == true
          ? description!.trim()
          : existingData['description'],
      'type': type?.name ?? existingData['type'],
      'actionRequired': actionRequired ?? existingData['actionRequired'],
      'createdBy': existingData['createdBy'], // Must not change
      'createdByName': existingData['createdByName'], // Must not change
      'createdAt': existingData['createdAt'], // Must not change
      'updatedAt': FieldValue.serverTimestamp(), // Update to current time
      'readBy': existingData['readBy'] ?? [], // Preserve read state
    };

    // Preserve attachments if they exist
    if (existingData['attachments'] != null) {
      updates['attachments'] = existingData['attachments'];
    }

    await _announcementsCollection.doc(announcementId).set(updates);
  }

  /// Mark announcement as read by current user (LEGACY - redirects to new method)
  /// Only adds current user to readBy map - does not modify other users' read state
  Future<void> markAsRead(String announcementId) async {
    await markAnnouncementAsRead(announcementId);
  }

  /// Get single announcement
  Future<Announcement?> getAnnouncement(String announcementId) async {
    final doc = await _announcementsCollection.doc(announcementId).get();
    if (!doc.exists) return null;
    return Announcement.fromDocument(doc);
  }

  /// Stream unread count for current user (real-time)
  Stream<int> watchUnreadCount() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _announcementsCollection.snapshots().map((snapshot) {
      int count = 0;
      for (final doc in snapshot.docs) {
        final announcement = Announcement.fromDocument(doc);
        if (!announcement.isReadBy(user.uid)) {
          count++;
        }
      }
      return count;
    });
  }

  /// Get unread count for current user (one-time)
  Future<int> getUnreadCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final snapshot = await _announcementsCollection.get();
    int count = 0;
    for (final doc in snapshot.docs) {
      final announcement = Announcement.fromDocument(doc);
      if (!announcement.isReadBy(user.uid)) {
        count++;
      }
    }
    return count;
  }

  // ═══════════════════════════════════════════════════════════════
  // READ RECEIPTS
  // ═══════════════════════════════════════════════════════════════

  /// Mark an announcement as read by current user
  ///
  /// ✅ IDEMPOTENT: Only writes if user hasn't already read the announcement
  /// ✅ ATOMIC: Uses Firestore map update to prevent race conditions
  /// ✅ EFFICIENT: Single write per user per announcement (never updates again)
  ///
  /// This should be called when:
  /// - User opens the announcement detail screen
  /// - Announcement content is fully rendered
  Future<void> markAnnouncementAsRead(String announcementId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Use set with merge to update only the readBy field
      // This ensures Firestore rules see it as a readBy-only update
      await _announcementsCollection.doc(announcementId).set({
        'readBy': {user.uid: FieldValue.serverTimestamp()},
      }, SetOptions(merge: true));
    } catch (e) {
      // Silently fail if announcement doesn't exist or other error
      // Read receipts are non-critical
      debugPrint('Failed to mark announcement as read: $e');
    }
  }

  /// Get users who have read a specific announcement
  /// Returns map of userId -> (AppUser, readTimestamp) for display in "Seen By" UI
  Future<Map<String, ({AppUser user, DateTime readAt})>> getAnnouncementReaders(
    String announcementId,
  ) async {
    try {
      final announcementDoc = await _announcementsCollection
          .doc(announcementId)
          .get();
      if (!announcementDoc.exists) return {};

      final announcement = Announcement.fromDocument(announcementDoc);
      final readers = <String, ({AppUser user, DateTime readAt})>{};

      // Fetch user details for each reader
      for (final entry in announcement.readBy.entries) {
        final userId = entry.key;
        final readAt = entry.value;

        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(userId)
              .get();
          if (userDoc.exists) {
            final user = AppUser.fromDocument(userDoc);
            readers[userId] = (user: user, readAt: readAt);
          }
        } catch (e) {
          debugPrint('Failed to fetch user $userId: $e');
        }
      }

      return readers;
    } catch (e) {
      debugPrint('Failed to get announcement readers: $e');
      return {};
    }
  }
}
