import 'package:cloud_firestore/cloud_firestore.dart';

/// Message type enum
enum MessageType {
  text,
  file;

  String toJson() => name;
  static MessageType fromJson(String json) {
    return MessageType.values.firstWhere((e) => e.name == json);
  }
}

/// User role enum
enum UserRole {
  admin,
  member;

  String toJson() => name;
  static UserRole fromJson(String json) {
    return UserRole.values.firstWhere((e) => e.name == json);
  }
}

/// Chat message model with file attachment support
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.messageType,
    required this.content, // text OR file URL
    this.fileName,
    this.fileType, // pdf, image, docx, etc
    required this.timestamp,
    this.readBy = const {}, // Map of userId -> timestamp when read
  });

  final String id;
  final String senderId;
  final String senderName;
  final UserRole senderRole;
  final MessageType messageType;
  final String content;
  final String? fileName;
  final String? fileType;
  final DateTime timestamp;
  final Map<String, DateTime> readBy; // userId -> first read timestamp

  /// Check if message is from current user
  bool isOwnMessage(String currentUserId) => senderId == currentUserId;

  /// Check if message is a file
  bool get isFile => messageType == MessageType.file;

  /// Check if message is text
  bool get isText => messageType == MessageType.text;

  /// Check if message has been read by a user
  bool isReadBy(String userId) => readBy.containsKey(userId);

  /// Get count of users who read this message
  int get readCount => readBy.length;

  /// Check if delivered (at least one person other than sender read it)
  bool get isDelivered => readBy.isNotEmpty;

  /// Check if read by anyone other than sender
  bool isReadByOthers(String currentUserId) {
    return readBy.keys.any((uid) => uid != currentUserId);
  }

  /// Create from Firestore document
  factory ChatMessage.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    // Parse readBy map from Firestore
    final readByData = data['readBy'] as Map<String, dynamic>? ?? {};
    final readByMap = <String, DateTime>{};
    readByData.forEach((userId, timestamp) {
      readByMap[userId] = _asDate(timestamp);
    });

    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Unknown',
      senderRole: data['senderRole'] != null
          ? UserRole.fromJson(data['senderRole'] as String)
          : UserRole.member,
      messageType: data['messageType'] != null
          ? MessageType.fromJson(data['messageType'] as String)
          : MessageType.text,
      content: data['content'] as String? ?? data['message'] as String? ?? '',
      fileName: data['fileName'] as String?,
      fileType: data['fileType'] as String?,
      timestamp: _asDate(data['createdAt'] ?? data['timestamp']),
      readBy: readByMap,
    );
  }

  /// Convert to Firestore map
  /// Note: readBy is NOT included here - it's updated separately via markAsRead()
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole.toJson(),
      'messageType': messageType.toJson(),
      'content': content,
      if (fileName != null) 'fileName': fileName,
      if (fileType != null) 'fileType': fileType,
      'createdAt': FieldValue.serverTimestamp(),
      // readBy is initialized as empty map on creation
      'readBy': {},
    };
  }

  static DateTime _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
