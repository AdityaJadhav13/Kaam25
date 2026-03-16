import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../features/auth/domain/app_user.dart';
import '../theme/app_colors.dart';

/// Reusable bottom sheet to show who has seen a message or announcement
///
/// Usage:
/// ```dart
/// showSeenByBottomSheet(
///   context: context,
///   title: 'Message Seen By',
///   readers: {
///     'user1': (user: appUser1, readAt: timestamp1),
///     'user2': (user: appUser2, readAt: timestamp2),
///   },
/// );
/// ```
void showSeenByBottomSheet({
  required BuildContext context,
  required String title,
  required Map<String, ({AppUser user, DateTime readAt})> readers,
  bool sortByNewest = true,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SeenByBottomSheet(
      title: title,
      readers: readers,
      sortByNewest: sortByNewest,
    ),
  );
}

class _SeenByBottomSheet extends StatelessWidget {
  const _SeenByBottomSheet({
    required this.title,
    required this.readers,
    required this.sortByNewest,
  });

  final String title;
  final Map<String, ({AppUser user, DateTime readAt})> readers;
  final bool sortByNewest;

  @override
  Widget build(BuildContext context) {
    // Sort readers by timestamp
    final sortedEntries = readers.entries.toList();
    sortedEntries.sort((a, b) {
      final comparison = a.value.readAt.compareTo(b.value.readAt);
      return sortByNewest ? -comparison : comparison;
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${readers.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // List of readers
              if (readers.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.visibility_off,
                          size: 48,
                          color: AppColors.muted,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No one has seen this yet',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: sortedEntries.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final entry = sortedEntries[index];
                      final reader = entry.value.user;
                      final readAt = entry.value.readAt;

                      return _ReaderListTile(reader: reader, readAt: readAt);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReaderListTile extends StatelessWidget {
  const _ReaderListTile({required this.reader, required this.readAt});

  final AppUser reader;
  final DateTime readAt;

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTimeAgo(readAt);
    final fullDateTime = DateFormat('MMM d, y \'at\' h:mm a').format(readAt);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: Text(
          reader.name.isNotEmpty ? reader.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            reader.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (reader.isAdmin) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Admin',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        timeAgo,
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      ),
      trailing: Tooltip(
        message: fullDateTime,
        child: const Icon(
          Icons.check_circle,
          color: AppColors.success,
          size: 20,
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }
}
