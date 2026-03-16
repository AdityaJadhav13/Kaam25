import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/throttled_visibility_detector.dart';
import '../../core/widgets/seen_by_bottom_sheet.dart';
import '../../data/models/chat_message.dart';
import '../../features/auth/domain/app_user.dart';
import '../chat/chat_providers.dart';
import 'document_viewer_page.dart';

/// Team Chat page with real-time messaging and file attachments
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isComposing = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadFileName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    setState(() => _isComposing = false);

    try {
      await ref.read(chatControllerProvider.notifier).sendTextMessage(message);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'jpg',
          'jpeg',
          'png',
          'txt',
        ],
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final fileExtension = fileName.split('.').last.toLowerCase();

      // Validate file size (10MB max)
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('File too large (max 10MB)');
      }

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
        _uploadFileName = fileName;
      });

      final repository = ref.read(chatRepositoryProvider);
      await repository.sendFileMessage(
        file: file,
        fileName: fileName,
        fileType: fileExtension,
        onProgress: (progress) {
          setState(() => _uploadProgress = progress);
        },
      );

      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
        _uploadFileName = '';
      });

      _scrollToBottom();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File uploaded successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
        _uploadFileName = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final onlineCount = ref.watch(onlineUsersCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Team Chat'),
            onlineCount.when(
              data: (count) => Text(
                '$count ${count == 1 ? 'member' : 'members'} online',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
              loading: () => const Text(
                'Loading...',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        elevation: 1,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: AppColors.mutedForeground,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isOwn = message.isOwnMessage(currentUserId ?? '');
                    final showSender =
                        index == 0 ||
                        messages[index - 1].senderId != message.senderId;

                    // Wrap in visibility detector to mark as read when visible
                    // Only for messages from other users
                    if (!isOwn && !message.isReadBy(currentUserId ?? '')) {
                      return ThrottledVisibilityDetector(
                        key: ValueKey('message_${message.id}'),
                        onVisible: () {
                          ref
                              .read(chatRepositoryProvider)
                              .markMessageAsRead(message.id);
                        },
                        child: _MessageBubble(
                          message: message,
                          isOwn: isOwn,
                          showSender: showSender,
                        ),
                      );
                    }

                    return _MessageBubble(
                      message: message,
                      isOwn: isOwn,
                      showSender: showSender,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load messages',
                      style: TextStyle(fontSize: 16, color: AppColors.danger),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Upload progress indicator
          if (_isUploading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.muted.withValues(alpha: 0.3),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uploading $_uploadFileName',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: AppColors.muted,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(_uploadProgress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

          // Privacy notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.muted.withValues(alpha: 0.2),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: const Text(
                    'Messages are private and cannot be forwarded outside',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Message input
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // Attachment button
                    IconButton(
                      onPressed: _isUploading ? null : _pickAndUploadFile,
                      icon: const Icon(Icons.attach_file),
                      tooltip: 'Attach file',
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Text input
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (text) {
                          setState(() => _isComposing = text.trim().isNotEmpty);
                        },
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !_isUploading,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send button
                    IconButton(
                      onPressed: (_isComposing && !_isUploading)
                          ? _sendMessage
                          : null,
                      icon: const Icon(Icons.send),
                      style: IconButton.styleFrom(
                        backgroundColor: (_isComposing && !_isUploading)
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        foregroundColor: (_isComposing && !_isUploading)
                            ? AppColors.primary
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Message bubble widget with read receipts
class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.showSender,
  });

  final ChatMessage message;
  final bool isOwn;
  final bool showSender;

  Future<void> _openFile(
    BuildContext context,
    String url,
    String? fileName,
  ) async {
    // Extract file extension from URL or fileName
    String fileType = 'pdf';
    if (fileName != null && fileName.contains('.')) {
      fileType = fileName.split('.').last.toLowerCase();
    } else if (url.contains('.')) {
      final urlPath = Uri.parse(url).path;
      if (urlPath.contains('.')) {
        fileType = urlPath.split('.').last.toLowerCase();
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DocumentViewerPage(
          documentUrl: url,
          documentName: fileName ?? 'Document',
          fileType: fileType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final currentUserId = ref.watch(currentUserIdProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        // Long press to show "Seen By" for own messages
        onLongPress: isOwn && message.readCount > 0
            ? () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );

                try {
                  final repository = ref.read(chatRepositoryProvider);
                  final readersData = await repository.getMessageReaders(
                    message.id,
                  );

                  if (!context.mounted) return;
                  Navigator.of(context).pop(); // Close loading dialog

                  // Convert to format expected by SeenByBottomSheet
                  final readers = <String, ({AppUser user, DateTime readAt})>{};
                  for (final entry in readersData.entries) {
                    final userId = entry.key;
                    final user = entry.value;
                    final readAt = message.readBy[userId] ?? DateTime.now();
                    readers[userId] = (user: user, readAt: readAt);
                  }

                  showSeenByBottomSheet(
                    context: context,
                    title: 'Message Seen By',
                    readers: readers,
                    sortByNewest: true,
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  Navigator.of(context).pop(); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to load readers: $e')),
                  );
                }
              }
            : null,
        child: Row(
          mainAxisAlignment: isOwn
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isOwn && showSender) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: message.senderRole == UserRole.admin
                    ? colors.danger.withValues(alpha: 0.2)
                    : colors.primary.withValues(alpha: 0.2),
                child: Text(
                  message.senderName[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: message.senderRole == UserRole.admin
                        ? colors.danger
                        : colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ] else if (!isOwn) ...[
              const SizedBox(width: 40),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isOwn
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isOwn && showSender)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.senderName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.mutedForeground,
                            ),
                          ),
                          if (message.senderRole == UserRole.admin) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.danger.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ADMIN',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: colors.danger,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isOwn
                          ? colors.ownMessageBackground
                          : colors.otherMessageBackground.withValues(
                              alpha: 0.5,
                            ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(
                          isOwn || !showSender ? 16 : 4,
                        ),
                        bottomRight: Radius.circular(
                          isOwn && showSender ? 4 : 16,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.isFile)
                          InkWell(
                            onTap: () => _openFile(
                              context,
                              message.content,
                              message.fileName,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isOwn
                                    ? colors.ownMessageForeground.withValues(
                                        alpha: 0.2,
                                      )
                                    : colors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getFileIcon(message.fileType),
                                    color: isOwn
                                        ? colors.ownMessageForeground
                                        : colors.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          message.fileName ?? 'File',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isOwn
                                                ? colors.ownMessageForeground
                                                : colors.foreground,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          message.fileType?.toUpperCase() ??
                                              'FILE',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isOwn
                                                ? colors.ownMessageForeground
                                                      .withValues(alpha: 0.7)
                                                : colors.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.download,
                                    color: isOwn
                                        ? colors.ownMessageForeground
                                        : colors.primary,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          SelectableText(
                            message.content,
                            style: TextStyle(
                              fontSize: 15,
                              color: isOwn
                                  ? colors.ownMessageForeground
                                  : colors.foreground,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(message.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: isOwn
                                    ? colors.ownMessageForeground.withValues(
                                        alpha: 0.7,
                                      )
                                    : colors.mutedForeground,
                              ),
                            ),
                            // Read receipt indicators (only for own messages)
                            if (isOwn) ...[
                              const SizedBox(width: 6),
                              _buildReadReceipt(colors, currentUserId),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build WhatsApp-style read receipt indicator
  Widget _buildReadReceipt(ThemeColorSet colors, String? currentUserId) {
    // Don't show read by self
    final readByOthers = message.readBy.keys
        .where((uid) => uid != currentUserId)
        .length;

    if (readByOthers > 0) {
      // ✓✓ Blue (Read by someone)
      return Icon(Icons.done_all, size: 16, color: Colors.blue[600]);
    } else if (message.readBy.isNotEmpty) {
      // ✓✓ Grey (Delivered, only read by self - shouldn't happen often)
      return Icon(
        Icons.done_all,
        size: 16,
        color: colors.ownMessageForeground.withValues(alpha: 0.5),
      );
    } else {
      // ✓ Grey (Sent, not yet delivered)
      return Icon(
        Icons.done,
        size: 16,
        color: colors.ownMessageForeground.withValues(alpha: 0.5),
      );
    }
  }

  IconData _getFileIcon(String? fileType) {
    switch (fileType?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (difference.inDays < 7) {
      return DateFormat('EEE HH:mm').format(timestamp);
    } else {
      return DateFormat('MMM d, HH:mm').format(timestamp);
    }
  }
}
