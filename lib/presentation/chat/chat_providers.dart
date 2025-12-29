import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_message.dart';
import 'chat_repository.dart';

/// Provider for ChatRepository
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
    FirebaseStorage.instance,
  );
});

/// Stream provider for real-time chat messages
final chatMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.watchMessages();
});

/// Provider for current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

/// Controller for chat actions
class ChatController extends StateNotifier<AsyncValue<void>> {
  final ChatRepository _repository;

  ChatController(this._repository) : super(const AsyncValue.data(null));

  /// Send a text message
  Future<void> sendTextMessage(String message) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.sendTextMessage(message);
    });
  }

  /// Load older messages
  Future<List<ChatMessage>> loadOlderMessages(DateTime before) async {
    return await _repository.loadOlderMessages(before: before);
  }
}

/// Provider for chat controller
final chatControllerProvider =
    StateNotifierProvider<ChatController, AsyncValue<void>>((ref) {
      final repository = ref.watch(chatRepositoryProvider);
      return ChatController(repository);
    });

/// Provider for online user count
final onlineUsersCountProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('presence')
      .where('online', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});
