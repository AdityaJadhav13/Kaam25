import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/folder.dart';
import '../../data/models/document.dart';
import 'folders_repository.dart';
import 'documents_repository.dart';

// Repository providers
final foldersRepositoryProvider = Provider<FoldersRepository>((ref) {
  return FoldersRepository();
});

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return DocumentsRepository();
});

// Folders stream provider
final foldersStreamProvider = StreamProvider<List<Folder>>((ref) {
  final repository = ref.watch(foldersRepositoryProvider);
  return repository.watchFolders();
});

// Documents stream provider for a specific folder
final documentsStreamProvider =
    StreamProvider.family<List<Document>, String>((ref, folderId) {
  final repository = ref.watch(documentsRepositoryProvider);
  return repository.watchDocuments(folderId);
});

// Document count provider for a specific folder
final folderDocumentCountProvider =
    FutureProvider.family<int, String>((ref, folderId) async {
  final repository = ref.watch(foldersRepositoryProvider);
  return repository.getDocumentCount(folderId);
});

// Folder controller
class FolderController extends StateNotifier<AsyncValue<void>> {
  FolderController(this._repository) : super(const AsyncValue.data(null));

  final FoldersRepository _repository;

  Future<Folder> createFolder({
    required String name,
    String? icon,
  }) async {
    state = const AsyncValue.loading();
    try {
      final folder = await _repository.createFolder(
        name: name,
        icon: icon,
      );
      state = const AsyncValue.data(null);
      return folder;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> renameFolder(String folderId, String newName) async {
    state = const AsyncValue.loading();
    try {
      await _repository.renameFolder(folderId, newName);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateFolderIcon(String folderId, String? icon) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateFolderIcon(folderId, icon);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteFolder(String folderId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteFolder(folderId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final folderControllerProvider =
    StateNotifierProvider<FolderController, AsyncValue<void>>((ref) {
  final repository = ref.watch(foldersRepositoryProvider);
  return FolderController(repository);
});

// Document controller
class DocumentController extends StateNotifier<AsyncValue<void>> {
  DocumentController(this._repository) : super(const AsyncValue.data(null));

  final DocumentsRepository _repository;

  Future<Document> uploadDocument({
    required String folderId,
    required dynamic file,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    state = const AsyncValue.loading();
    try {
      final document = await _repository.uploadDocument(
        folderId: folderId,
        file: file,
        fileName: fileName,
        onProgress: onProgress,
      );
      state = const AsyncValue.data(null);
      return document;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteDocument(String documentId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteDocument(documentId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<String> getDownloadUrl(String documentId) async {
    try {
      return await _repository.getDownloadUrl(documentId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final documentControllerProvider =
    StateNotifierProvider<DocumentController, AsyncValue<void>>((ref) {
  final repository = ref.watch(documentsRepositoryProvider);
  return DocumentController(repository);
});
