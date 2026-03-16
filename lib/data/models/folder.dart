import 'package:cloud_firestore/cloud_firestore.dart';

class Folder {
  const Folder({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.icon,
  });

  final String id;
  final String name;

  /// null = root-level folder. Non-null = nested inside another folder.
  final String? parentId;
  final String? icon;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether this folder sits at the root level.
  bool get isRoot => parentId == null;

  factory Folder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Folder(
      id: doc.id,
      name: data['name'] as String,
      parentId: data['parentId'] as String?,
      icon: data['icon'] as String?,
      createdBy: data['createdBy'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'parentId': parentId,
      'icon': icon,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Folder copyWith({
    String? id,
    String? name,
    String? parentId,
    bool clearParentId = false,
    String? icon,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      icon: icon ?? this.icon,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
