import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

/// Announcement model with Firestore integration
///
/// ARCHITECTURE:
/// - Announcements are global (visible to all approved users)
/// - readBy array tracks which users have read each announcement
/// - Timestamps use server time for consistency
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.actionRequired,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
    required this.readBy,
    this.attachments,
  });

  final String id;
  final String title;
  final String description;
  final AnnouncementType type;
  final bool actionRequired;
  final String createdBy; // userId
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, DateTime> readBy; // userId -> timestamp when read
  final List<AnnouncementAttachment>? attachments;

  // UI helpers
  bool isReadBy(String userId) => readBy.containsKey(userId);

  /// Get count of users who read this announcement
  int get readCount => readBy.length;

  /// Get list of user IDs who read (for backward compatibility)
  List<String> get readByList => readBy.keys.toList();

  // Backward compatibility with old UI
  String get authorId => createdBy;
  bool get requiresAcknowledgment => actionRequired;
  bool get isRead => false; // Determined by readBy in UI
  bool get isAcknowledged => false; // Determined by readBy in UI

  Announcement copyWith({
    String? title,
    String? description,
    AnnouncementType? type,
    bool? actionRequired,
    DateTime? updatedAt,
    Map<String, DateTime>? readBy,
    List<AnnouncementAttachment>? attachments,
  }) {
    return Announcement(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      actionRequired: actionRequired ?? this.actionRequired,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      readBy: readBy ?? this.readBy,
      attachments: attachments ?? this.attachments,
    );
  }

  Map<String, dynamic> toMap() {
    // Convert readBy map to Firestore-compatible format
    final readByFirestore = <String, dynamic>{};
    readBy.forEach((userId, timestamp) {
      readByFirestore[userId] = Timestamp.fromDate(timestamp);
    });

    return {
      'title': title,
      'description': description,
      'type': type.name,
      'actionRequired': actionRequired,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'readBy': readByFirestore,
      if (attachments != null)
        'attachments': attachments!.map((a) => a.toMap()).toList(),
    };
  }

  factory Announcement.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle timestamps that might be null (pending server timestamp)
    // or already be Timestamp objects
    DateTime parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    // Parse readBy map from Firestore
    final readByData = data['readBy'];
    final readByMap = <String, DateTime>{};

    if (readByData is Map<String, dynamic>) {
      // New format: Map<String, Timestamp>
      readByData.forEach((userId, timestamp) {
        readByMap[userId] = parseTimestamp(timestamp);
      });
    } else if (readByData is List) {
      // Legacy format: List<String> - convert to map with current time
      for (final userId in readByData) {
        readByMap[userId as String] = DateTime.now();
      }
    }

    return Announcement(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      type: AnnouncementType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => AnnouncementType.normal,
      ),
      actionRequired: data['actionRequired'] as bool? ?? false,
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? 'Unknown',
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
      readBy: readByMap,
      attachments: (data['attachments'] as List<dynamic>?)
          ?.map(
            (a) => AnnouncementAttachment.fromMap(a as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// Attachment metadata
class AnnouncementAttachment {
  const AnnouncementAttachment({
    required this.fileName,
    required this.fileType,
    required this.downloadUrl,
    required this.uploadedAt,
  });

  final String fileName;
  final String fileType;
  final String downloadUrl;
  final DateTime uploadedAt;

  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'fileType': fileType,
      'downloadUrl': downloadUrl,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
    };
  }

  factory AnnouncementAttachment.fromMap(Map<String, dynamic> map) {
    return AnnouncementAttachment(
      fileName: map['fileName'] as String,
      fileType: map['fileType'] as String,
      downloadUrl: map['downloadUrl'] as String,
      uploadedAt: (map['uploadedAt'] as Timestamp).toDate(),
    );
  }
}
