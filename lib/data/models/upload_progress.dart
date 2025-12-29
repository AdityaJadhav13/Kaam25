import 'enums.dart';

class UploadProgress {
  const UploadProgress({
    required this.fileId,
    required this.fileName,
    required this.progress,
    required this.status,
    this.error,
  });

  final String fileId;
  final String fileName;
  final int progress;
  final UploadStatus status;
  final String? error;

  UploadProgress copyWith({
    int? progress,
    UploadStatus? status,
    String? error,
  }) {
    return UploadProgress(
      fileId: fileId,
      fileName: fileName,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      error: error,
    );
  }
}
