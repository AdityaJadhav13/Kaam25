import 'enums.dart';

class KaamUser {
  const KaamUser({
    required this.id,
    required this.email,
    required this.name,
    required this.status,
    required this.role,
    required this.createdAt,
    this.avatar,
  });

  final String id;
  final String email;
  final String name;
  final String? avatar;
  final UserStatus status;
  final UserRole role;
  final DateTime createdAt;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    final first = parts.first.isNotEmpty ? parts.first[0] : 'U';
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }
}
