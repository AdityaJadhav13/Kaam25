class Note {
  const Note({
    required this.id,
    required this.folderId,
    required this.title,
    required this.content,
    required this.authorId,
    required this.createdAt,
    required this.updatedAt,
    required this.isNew,
    this.attachments,
  });

  final String id;
  final String folderId;
  final String title;
  final String content;
  final String authorId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isNew;
  final List<String>? attachments;
}
