import 'enums.dart';

class Story {
  const Story({
    required this.id,
    required this.authorId,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.expiresAt,
    required this.viewedBy,
    this.mediaUrl,
  });

  final String id;
  final String authorId;
  final String content;
  final StoryType type;
  final String? mediaUrl;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewedBy;
}
