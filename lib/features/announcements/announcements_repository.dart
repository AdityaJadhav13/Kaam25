import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/announcement.dart';
import '../../data/models/enums.dart';
import '../../features/auth/domain/app_user.dart';

/// Repository for announcements with Firestore integration
class AnnouncementsRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  AnnouncementsRepository(this._firestore, this._auth, this._storage);

  /// Get announcements collection reference
  CollectionReference<Map<String, dynamic>> get _announcementsCollection =>
      _firestore.collection('announcements');

  /// Stream of announcements (real-time)
  Stream<List<Announcement>> watchAnnouncements() {
    return _announcementsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Announcement.fromDocument(doc))
              .toList(),
        );
  }

  /// Create a new announcement
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
    List<AnnouncementAttachment>? attachments;
    if (attachmentFiles != null && attachmentFiles.isNotEmpty) {
      attachments = [];
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

        attachments.add(
          AnnouncementAttachment(
            fileName: fileName,
            fileType: fileType,
            downloadUrl: downloadUrl,
            uploadedAt: now,
          ),
        );
      }
    }

    final announcement = Announcement(
      id: announcementId,
      title: trimmedTitle,
      description: trimmedDescription,
      type: type,
      actionRequired: actionRequired,
      createdBy: user.uid,
      createdByName: appUser.name,
      createdAt: now,
      updatedAt: now,
      readBy: [], // No one has read it yet
      attachments: attachments,
    );

    await _announcementsCollection
        .doc(announcementId)
        .set(announcement.toMap());
    return announcementId;
  }

  /// Edit an existing announcement
  Future<void> editAnnouncement({
    required String announcementId,
    String? title,
    String? description,
    AnnouncementType? type,
    bool? actionRequired,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final updates = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (title != null) {
      final trimmed = title.trim();
      if (trimmed.isEmpty) throw Exception('Title cannot be empty');
      updates['title'] = trimmed;
    }

    if (description != null) {
      final trimmed = description.trim();
      if (trimmed.isEmpty) throw Exception('Description cannot be empty');
      updates['description'] = trimmed;
    }

    if (type != null) {
      updates['type'] = type.name;
    }

    if (actionRequired != null) {
      updates['actionRequired'] = actionRequired;
    }

    await _announcementsCollection.doc(announcementId).update(updates);
  }

  /// Mark announcement as read by current user
  Future<void> markAsRead(String announcementId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _announcementsCollection.doc(announcementId).update({
      'readBy': FieldValue.arrayUnion([user.uid]),
    });
  }

  /// Get single announcement
  Future<Announcement?> getAnnouncement(String announcementId) async {
    final doc = await _announcementsCollection.doc(announcementId).get();
    if (!doc.exists) return null;
    return Announcement.fromDocument(doc);
  }

  /// Get unread count for current user
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
}
