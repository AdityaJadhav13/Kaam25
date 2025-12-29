import 'package:cloud_firestore/cloud_firestore.dart';

class Document {
  const Document({
    required this.id,
    required this.folderId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.storagePath,
    required this.uploadedBy,
    required this.uploadedAt,
    this.downloadUrl,
  });

  final String id;
  final String folderId;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String storagePath;
  final String uploadedBy;
  final DateTime uploadedAt;
  final String? downloadUrl;

  factory Document.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Document(
      id: doc.id,
      folderId: data['folderId'] as String,
      fileName: data['fileName'] as String,
      fileType: data['fileType'] as String,
      fileSize: data['fileSize'] as int,
      storagePath: data['storagePath'] as String,
      uploadedBy: data['uploadedBy'] as String,
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      downloadUrl: data['downloadUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'folderId': folderId,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'storagePath': storagePath,
      'uploadedBy': uploadedBy,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'downloadUrl': downloadUrl,
    };
  }

  Document copyWith({
    String? id,
    String? folderId,
    String? fileName,
    String? fileType,
    int? fileSize,
    String? storagePath,
    String? uploadedBy,
    DateTime? uploadedAt,
    String? downloadUrl,
  }) {
    return Document(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      storagePath: storagePath ?? this.storagePath,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }

  String get fileExtension {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
