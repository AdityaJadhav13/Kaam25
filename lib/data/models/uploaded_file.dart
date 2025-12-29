import 'enums.dart';

class UploadedFile {
  const UploadedFile({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.context,
    required this.contextId,
    this.url,
  });

  final String id;
  final String name;
  final FileType type;
  final int size;
  final String uploadedBy;
  final DateTime uploadedAt;
  final FileContext context;
  final String contextId;
  final String? url;
}
