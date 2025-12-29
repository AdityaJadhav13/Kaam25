class Message {
  const Message({
    required this.id,
    required this.authorId,
    required this.content,
    required this.timestamp,
    required this.isEdited,
    required this.readBy,
    this.fileAttachment,
  });

  final String id;
  final String authorId;
  final String content;
  final DateTime timestamp;
  final bool isEdited;
  final List<String> readBy;
  final String? fileAttachment;
}
