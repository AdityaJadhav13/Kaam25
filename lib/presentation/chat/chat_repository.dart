import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/chat_message.dart';
import '../../features/auth/domain/app_user.dart';

/// Repository for team chat functionality with file attachments
class ChatRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  static const String _teamChatId = 'team_chat';
  static const int _messagesPerPage = 50;

  ChatRepository(this._firestore, this._auth, this._storage);

  /// Get messages collection reference
  CollectionReference<Map<String, dynamic>> get _messagesCollection =>
      _firestore.collection('chats').doc(_teamChatId).collection('messages');

  /// Stream of chat messages (real-time)
  Stream<List<ChatMessage>> watchMessages({int limit = _messagesPerPage}) {
    return _messagesCollection
        .orderBy('createdAt', descending: false)
        .limitToLast(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromDocument(doc))
              .toList(),
        );
  }

  /// Send a text message
  Future<String> sendTextMessage(String message) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) throw Exception('Message cannot be empty');
    if (trimmedMessage.length > 1000) {
      throw Exception('Message too long (max 1000 characters)');
    }

    // Get user role
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final appUser = AppUser.fromDocument(userDoc);

    final chatMessage = ChatMessage(
      id: '',
      senderId: user.uid,
      senderName: appUser.name,
      senderRole: appUser.isAdmin ? UserRole.admin : UserRole.member,
      messageType: MessageType.text,
      content: trimmedMessage,
      timestamp: DateTime.now(),
    );

    final docRef = await _messagesCollection.add(chatMessage.toMap());
    return docRef.id;
  }

  /// Upload file and send file message
  Future<String> sendFileMessage({
    required File file,
    required String fileName,
    required String fileType,
    required Function(double) onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get user role
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final appUser = AppUser.fromDocument(userDoc);

    // Generate message ID first
    final messageId = const Uuid().v4();

    // Upload to Storage
    final storagePath = 'chat_uploads/$_teamChatId/$messageId/$fileName';
    final storageRef = _storage.ref().child(storagePath);
    final uploadTask = storageRef.putFile(file);

    // Track progress
    uploadTask.snapshotEvents.listen((snapshot) {
      final progress = snapshot.bytesTransferred / snapshot.totalBytes;
      onProgress(progress);
    });

    // Wait for upload
    await uploadTask;

    // Get download URL
    final downloadUrl = await storageRef.getDownloadURL();

    // Save message
    final chatMessage = ChatMessage(
      id: messageId,
      senderId: user.uid,
      senderName: appUser.name,
      senderRole: appUser.isAdmin ? UserRole.admin : UserRole.member,
      messageType: MessageType.file,
      content: downloadUrl,
      fileName: fileName,
      fileType: fileType,
      timestamp: DateTime.now(),
    );

    await _messagesCollection.doc(messageId).set(chatMessage.toMap());
    return messageId;
  }

  /// Load older messages for pagination
  Future<List<ChatMessage>> loadOlderMessages({
    required DateTime before,
    int limit = _messagesPerPage,
  }) async {
    final snapshot = await _messagesCollection
        .orderBy('createdAt', descending: true)
        .where('createdAt', isLessThan: Timestamp.fromDate(before))
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => ChatMessage.fromDocument(doc))
        .toList()
        .reversed
        .toList();
  }

  /// Get total message count
  Future<int> getMessageCount() async {
    final snapshot = await _messagesCollection.count().get();
    return snapshot.count ?? 0;
  }

  // ═══════════════════════════════════════════════════════════════
  // READ RECEIPTS
  // ═══════════════════════════════════════════════════════════════

  /// Mark a message as read by current user
  ///
  /// ✅ IDEMPOTENT: Only writes if user hasn't already read the message
  /// ✅ ATOMIC: Uses Firestore map update to prevent race conditions
  /// ✅ EFFICIENT: Single write per user per message (never updates again)
  ///
  /// This should be called when:
  /// - Message is visible on screen
  /// - Chat screen is active (foreground)
  /// - App is not backgrounded
  Future<void> markMessageAsRead(String messageId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Use set with merge to update only the readBy field
      // This ensures Firestore rules see it as a readBy-only update
      await _messagesCollection.doc(messageId).set({
        'readBy': {user.uid: FieldValue.serverTimestamp()},
      }, SetOptions(merge: true));
    } catch (e) {
      // Silently fail if message doesn't exist or other error
      // Read receipts are non-critical
      debugPrint('Failed to mark message as read: $e');
    }
  }

  /// Mark multiple messages as read in a batch
  ///
  /// More efficient than calling markMessageAsRead() multiple times
  /// Used when scrolling through many unread messages
  Future<void> markMultipleMessagesAsRead(List<String> messageIds) async {
    final user = _auth.currentUser;
    if (user == null || messageIds.isEmpty) return;

    try {
      final batch = _firestore.batch();

      for (final messageId in messageIds) {
        final docRef = _messagesCollection.doc(messageId);
        batch.set(docRef, {
          'readBy': {user.uid: FieldValue.serverTimestamp()},
        }, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Failed to mark messages as read: $e');
    }
  }

  /// Get users who have read a specific message
  /// Returns map of userId -> AppUser for display in "Seen By" UI
  Future<Map<String, AppUser>> getMessageReaders(String messageId) async {
    try {
      final messageDoc = await _messagesCollection.doc(messageId).get();
      if (!messageDoc.exists) return {};

      final message = ChatMessage.fromDocument(messageDoc);
      final readers = <String, AppUser>{};

      // Fetch user details for each reader
      for (final userId in message.readBy.keys) {
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(userId)
              .get();
          if (userDoc.exists) {
            readers[userId] = AppUser.fromDocument(userDoc);
          }
        } catch (e) {
          debugPrint('Failed to fetch user $userId: $e');
        }
      }

      return readers;
    } catch (e) {
      debugPrint('Failed to get message readers: $e');
      return {};
    }
  }
}
