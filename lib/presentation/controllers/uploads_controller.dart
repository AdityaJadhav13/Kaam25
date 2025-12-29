import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/file_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/upload_progress.dart';
import '../../data/models/uploaded_file.dart';

class UploadsState {
  const UploadsState({required this.files, required this.uploads});

  final List<UploadedFile> files;
  final List<UploadProgress> uploads;

  UploadsState copyWith({
    List<UploadedFile>? files,
    List<UploadProgress>? uploads,
  }) {
    return UploadsState(
      files: files ?? this.files,
      uploads: uploads ?? this.uploads,
    );
  }
}

class UploadsController extends StateNotifier<UploadsState> {
  UploadsController() : super(const UploadsState(files: [], uploads: []));

  void addFile(UploadedFile file) {
    state = state.copyWith(files: [...state.files, file]);
  }

  UploadedFile? getFile(String fileId) {
    for (final f in state.files) {
      if (f.id == fileId) return f;
    }
    return null;
  }

  List<UploadedFile> getFilesByContext(FileContext context, String contextId) {
    return state.files.where((f) => f.context == context && f.contextId == contextId).toList();
  }

  void startUpload({required String fileId, required String fileName}) {
    state = state.copyWith(
      uploads: [
        ...state.uploads,
        UploadProgress(
          fileId: fileId,
          fileName: fileName,
          progress: 0,
          status: UploadStatus.uploading,
        ),
      ],
    );
  }

  void updateUploadProgress({required String fileId, required int progress}) {
    state = state.copyWith(
      uploads: state.uploads
          .map(
            (u) => u.fileId == fileId
                ? u.copyWith(progress: progress, status: UploadStatus.uploading)
                : u,
          )
          .toList(),
    );
  }

  void completeUpload({required String fileId}) {
    state = state.copyWith(
      uploads: state.uploads
          .map(
            (u) => u.fileId == fileId
                ? u.copyWith(progress: 100, status: UploadStatus.completed)
                : u,
          )
          .toList(),
    );
  }

  void failUpload({required String fileId, required String error}) {
    state = state.copyWith(
      uploads: state.uploads
          .map(
            (u) => u.fileId == fileId
                ? u.copyWith(status: UploadStatus.failed, error: error)
                : u,
          )
          .toList(),
    );
  }

  void cancelUpload(String fileId) {
    state = state.copyWith(uploads: state.uploads.where((u) => u.fileId != fileId).toList());
  }

  void dismissUpload(String fileId) {
    state = state.copyWith(uploads: state.uploads.where((u) => u.fileId != fileId).toList());
  }

  /// UI-only helper to demonstrate the upload progress overlay before Firebase.
  ///
  /// Creates a simulated upload and records it as an UploadedFile.
  Future<void> simulateUpload({
    required String fileName,
    required int size,
    required String uploadedBy,
    required FileContext context,
    required String contextId,
  }) async {
    final type = FileUtils.fileTypeFromName(fileName);
    if (type == null) {
      return;
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    startUpload(fileId: id, fileName: fileName);

    var progress = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      progress += 10;
      if (progress >= 100) {
        t.cancel();
        addFile(
          UploadedFile(
            id: id,
            name: fileName,
            type: type,
            size: size,
            uploadedBy: uploadedBy,
            uploadedAt: DateTime.now(),
            context: context,
            contextId: contextId,
          ),
        );
        completeUpload(fileId: id);
      } else {
        updateUploadProgress(fileId: id, progress: progress);
      }
    });

    // Ensure timer gets canceled when no longer needed by letting it run to completion.
    await Future<void>.delayed(const Duration(milliseconds: 2600));
    if (timer.isActive) {
      timer.cancel();
    }
  }
}

final uploadsControllerProvider = StateNotifierProvider<UploadsController, UploadsState>(
  (ref) => UploadsController(),
);
