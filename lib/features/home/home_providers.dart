import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/folder.dart';
import '../../data/models/document.dart';
import 'folders_repository.dart';
import 'documents_repository.dart';

// ─────────────────── REPOSITORY PROVIDERS ───────────────────

final foldersRepositoryProvider = Provider<FoldersRepository>((ref) {
  return FoldersRepository();
});

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return DocumentsRepository();
});

// ─────────────────── FOLDER STREAMS ───────────────────

/// Root-level folders (parentId == null).
final rootFoldersStreamProvider = StreamProvider<List<Folder>>((ref) {
  final repository = ref.watch(foldersRepositoryProvider);
  return repository.watchRootFolders();
});

/// Sub-folders of a given parent folder.
final subFoldersStreamProvider = StreamProvider.family<List<Folder>, String>((
  ref,
  parentId,
) {
  final repository = ref.watch(foldersRepositoryProvider);
  return repository.watchSubFolders(parentId);
});

/// All folders (legacy / search).
final foldersStreamProvider = StreamProvider<List<Folder>>((ref) {
  final repository = ref.watch(foldersRepositoryProvider);
  return repository.watchFolders();
});

// ─────────────────── DOCUMENT STREAMS ───────────────────

/// Documents stream for a specific folder.
final documentsStreamProvider = StreamProvider.family<List<Document>, String>((
  ref,
  folderId,
) {
  final repository = ref.watch(documentsRepositoryProvider);
  return repository.watchDocuments(folderId);
});

// ─────────────────── COUNTS ───────────────────

final folderDocumentCountProvider = FutureProvider.family<int, String>((
  ref,
  folderId,
) async {
  final repository = ref.watch(foldersRepositoryProvider);
  return repository.getDocumentCount(folderId);
});

final folderSubFolderCountProvider = FutureProvider.family<int, String>((
  ref,
  folderId,
) async {
  final repository = ref.watch(foldersRepositoryProvider);
  return repository.getSubFolderCount(folderId);
});

// ─────────────────── BREADCRUMB TRAIL ───────────────────

final breadcrumbTrailProvider = FutureProvider.family<List<Folder>, String>((
  ref,
  folderId,
) async {
  final repository = ref.watch(foldersRepositoryProvider);
  return repository.getBreadcrumbTrail(folderId);
});

// ─────────────────── NAVIGATION STATE ───────────────────

/// Tracks the folder navigation stack.
/// null means we're at the root. A String means we're inside that folder.
final currentFolderIdProvider = StateProvider<String?>((ref) => null);

// ─────────────────── FOLDER CONTROLLER ───────────────────

class FolderController extends StateNotifier<AsyncValue<void>> {
  FolderController(this._repository) : super(const AsyncValue.data(null));

  final FoldersRepository _repository;

  Future<Folder> createFolder({
    required String name,
    String? parentId,
    String? icon,
  }) async {
    state = const AsyncValue.loading();
    try {
      final folder = await _repository.createFolder(
        name: name,
        parentId: parentId,
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

// ─────────────────── DOCUMENT CONTROLLER ───────────────────

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

  Future<void> renameDocument(String documentId, String newName) async {
    state = const AsyncValue.loading();
    try {
      await _repository.renameDocument(documentId, newName);
      state = const AsyncValue.data(null);
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
