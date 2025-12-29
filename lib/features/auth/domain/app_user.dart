import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/enums.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.approved,
    required this.blocked,
    required this.devices,
    required this.createdAt,
    this.lastLogin,
    this.photoUrl,
    this.screenshotAttempts = 0,
    this.lastViolation,
    this.blockedAt,
    this.blockedReason,
  });

  final String id;
  final String email;
  final String name;
  final UserRole role;
  final bool approved;
  final bool blocked;
  final List<String> devices;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String? photoUrl;
  final int screenshotAttempts;
  final DateTime? lastViolation;
  final DateTime? blockedAt;
  final String? blockedReason;

  bool get isAdmin => role == UserRole.admin;
  bool get isApproved => approved && !blocked;
  UserStatus get status => blocked
      ? UserStatus.blocked
      : (approved ? UserStatus.approved : UserStatus.pending);

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    final first = parts.first.isNotEmpty ? parts.first[0] : 'U';
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  AppUser copyWith({
    bool? approved,
    bool? blocked,
    List<String>? devices,
    DateTime? lastLogin,
    int? screenshotAttempts,
    DateTime? lastViolation,
    DateTime? blockedAt,
    String? blockedReason,
  }) {
    return AppUser(
      id: id,
      email: email,
      name: name,
      role: role,
      approved: approved ?? this.approved,
      blocked: blocked ?? this.blocked,
      devices: devices ?? this.devices,
      createdAt: createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      photoUrl: photoUrl,
      screenshotAttempts: screenshotAttempts ?? this.screenshotAttempts,
      lastViolation: lastViolation ?? this.lastViolation,
      blockedAt: blockedAt ?? this.blockedAt,
      blockedReason: blockedReason ?? this.blockedReason,
    );
  }

  static AppUser fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    // Parse devices field - handle both List and Map cases
    List<String> devices = [];
    final devicesData = data['devices'];
    if (devicesData is List) {
      // Filter and convert each element to String safely
      devices = devicesData.whereType<String>().toList();
    } else if (devicesData is Map) {
      // If it's a map, extract string values
      devices = devicesData.values.whereType<String>().toList();
    }

    return AppUser(
      id: doc.id,
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? '',
      role: (data['role'] as String?)?.toUserRole() ?? UserRole.member,
      approved: data['approved'] as bool? ?? false,
      blocked: data['blocked'] as bool? ?? false,
      devices: devices,
      createdAt: _asDate(data['createdAt']),
      lastLogin: _asDateOrNull(data['lastLogin']),
      photoUrl: data['photoUrl'] as String?,
      screenshotAttempts: data['screenshotAttempts'] as int? ?? 0,
      lastViolation: _asDateOrNull(data['lastViolation']),
      blockedAt: _asDateOrNull(data['blockedAt']),
      blockedReason: data['blockedReason'] as String?,
    );
  }

  static DateTime _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _asDateOrNull(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role.name,
      'approved': approved,
      'blocked': blocked,
      'devices': devices,
      'createdAt': Timestamp.fromDate(createdAt),
      if (lastLogin != null) 'lastLogin': Timestamp.fromDate(lastLogin!),
      if (photoUrl != null) 'photoUrl': photoUrl,
      'screenshotAttempts': screenshotAttempts,
      if (lastViolation != null)
        'lastViolation': Timestamp.fromDate(lastViolation!),
      if (blockedAt != null) 'blockedAt': Timestamp.fromDate(blockedAt!),
      if (blockedReason != null) 'blockedReason': blockedReason,
    };
  }
}
