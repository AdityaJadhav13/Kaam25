import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../../data/models/announcement.dart';
import '../../data/models/enums.dart';
import '../../features/announcements/announcements_repository.dart';

/// Repository provider
final announcementsRepositoryProvider = Provider<AnnouncementsRepository>((
  ref,
) {
  return AnnouncementsRepository(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
    FirebaseStorage.instance,
  );
});

/// Stream of all announcements (real-time)
final announcementsStreamProvider = StreamProvider<List<Announcement>>((ref) {
  final repository = ref.watch(announcementsRepositoryProvider);
  return repository.watchAnnouncements();
});

/// Controller for announcements operations
class AnnouncementsController extends StateNotifier<AsyncValue<void>> {
  AnnouncementsController(this._repository)
    : super(const AsyncValue.data(null));

  final AnnouncementsRepository _repository;

  /// Create new announcement
  Future<void> createAnnouncement({
    required String title,
    required String description,
    required AnnouncementType type,
    required bool actionRequired,
    List<File>? attachmentFiles,
    Function(double)? onUploadProgress,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.createAnnouncement(
        title: title,
        description: description,
        type: type,
        actionRequired: actionRequired,
        attachmentFiles: attachmentFiles,
        onUploadProgress: onUploadProgress,
      );
    });
  }

  /// Edit announcement
  Future<void> editAnnouncement({
    required String announcementId,
    String? title,
    String? description,
    AnnouncementType? type,
    bool? actionRequired,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.editAnnouncement(
        announcementId: announcementId,
        title: title,
        description: description,
        type: type,
        actionRequired: actionRequired,
      );
    });
  }

  /// Mark announcement as read
  Future<void> markAsRead(String announcementId) async {
    try {
      await _repository.markAsRead(announcementId);
    } catch (e) {
      // Silent fail for read tracking
    }
  }
}

final announcementsControllerProvider =
    StateNotifierProvider<AnnouncementsController, AsyncValue<void>>((ref) {
      final repository = ref.watch(announcementsRepositoryProvider);
      return AnnouncementsController(repository);
    });

/// Get unread announcements count for current user
final unreadAnnouncementsCountProvider = Provider<int>((ref) {
  final announcementsAsync = ref.watch(announcementsStreamProvider);
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) return 0;

  return announcementsAsync.when(
    data: (announcements) {
      return announcements.where((a) => !a.isReadBy(user.uid)).length;
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});
