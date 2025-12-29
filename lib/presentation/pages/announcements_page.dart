import 'dart:io';

import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/kaam_badge.dart';
import '../../core/widgets/kaam_button.dart';
import '../../data/models/announcement.dart';
import '../../data/models/enums.dart';
import '../controllers/announcements_controller.dart';
import '../controllers/auth_controller.dart';

class AnnouncementsPage extends ConsumerStatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  ConsumerState<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends ConsumerState<AnnouncementsPage> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final announcementsAsync = ref.watch(announcementsStreamProvider);

    return announcementsAsync.when(
      data: (announcements) {
        final selected = _selectedId == null
            ? null
            : announcements.where((a) => a.id == _selectedId).firstOrNull;

        if (selected != null) {
          return _AnnouncementDetail(
            announcement: selected,
            onBack: () {
              setState(() => _selectedId = null);
            },
          );
        }

        return _AnnouncementsList(
          announcements: announcements,
          onTap: (id) async {
            // Mark as read when opened
            await ref
                .read(announcementsControllerProvider.notifier)
                .markAsRead(id);
            setState(() => _selectedId = id);
          },
          onCreateNew: () => _showCreateDialog(context),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.danger,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load announcements',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateAnnouncementDialog(),
    );
  }
}

class _AnnouncementsList extends ConsumerWidget {
  const _AnnouncementsList({
    required this.announcements,
    required this.onTap,
    required this.onCreateNew,
  });

  final List<Announcement> announcements;
  final Function(String) onTap;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final userId = auth.user?.id;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Announcements',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Official communication from the team',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: announcements.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: AppColors.mutedForeground.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No announcements yet',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create the first announcement',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: announcements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final a = announcements[index];
                    final isRead = userId != null && a.isReadBy(userId);

                    return Card(
                      child: InkWell(
                        onTap: () => onTap(a.id),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Stack(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _typeBg(a.type),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _typeBorder(a.type),
                                      ),
                                    ),
                                    child: Icon(
                                      _typeIcon(a.type),
                                      size: 18,
                                      color: _typeFg(a.type),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          a.title,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          a.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color:
                                                    AppColors.mutedForeground,
                                              ),
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          spacing: 6,
                                          children: [
                                            Text(
                                              a.createdByName,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                            const Text(
                                              '•',
                                              style: TextStyle(
                                                color:
                                                    AppColors.mutedForeground,
                                              ),
                                            ),
                                            Text(
                                              MaterialLocalizations.of(
                                                context,
                                              ).formatCompactDate(a.createdAt),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: AppColors
                                                        .mutedForeground,
                                                  ),
                                            ),
                                            if (a.actionRequired &&
                                                !isRead) ...[
                                              const Text(
                                                '•',
                                                style: TextStyle(
                                                  color:
                                                      AppColors.mutedForeground,
                                                ),
                                              ),
                                              const KaamBadge(
                                                label: 'Action Required',
                                                variant:
                                                    KaamBadgeVariant.outline,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (!isRead)
                                const Positioned(
                                  right: 8,
                                  top: 8,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: SizedBox(width: 8, height: 8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: KaamButton(
            fullWidth: true,
            size: KaamButtonSize.lg,
            onPressed: onCreateNew,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add),
                SizedBox(width: 8),
                Text('Create Announcement'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnnouncementDetail extends ConsumerWidget {
  const _AnnouncementDetail({required this.announcement, required this.onBack});

  final Announcement announcement;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final userId = auth.user?.id;
    final isRead = userId != null && announcement.isReadBy(userId);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              KaamButton(
                onPressed: onBack,
                variant: KaamButtonVariant.ghost,
                size: KaamButtonSize.icon,
                child: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Announcement',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (auth.user != null)
                KaamButton(
                  onPressed: () => _showEditDialog(context, announcement),
                  variant: KaamButtonVariant.ghost,
                  size: KaamButtonSize.icon,
                  child: const Icon(Icons.edit),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _typeBg(announcement.type),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _typeBorder(announcement.type)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _typeIcon(announcement.type),
                        size: 18,
                        color: _typeFg(announcement.type),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        announcement.type.name.toUpperCase(),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: _typeFg(announcement.type)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                announcement.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                announcement.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              if (announcement.attachments != null &&
                  announcement.attachments!.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Attachments',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                for (final attachment in announcement.attachments!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AttachmentCard(
                      attachment: attachment,
                      onTap: () => _openAttachment(attachment.downloadUrl),
                    ),
                  ),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    _MetaRow(
                      label: 'Posted by',
                      value: announcement.createdByName,
                    ),
                    const SizedBox(height: 8),
                    _MetaRow(
                      label: 'Date',
                      value: MaterialLocalizations.of(
                        context,
                      ).formatCompactDate(announcement.createdAt),
                    ),
                    if (announcement.updatedAt != announcement.createdAt) ...[
                      const SizedBox(height: 8),
                      _MetaRow(
                        label: 'Last updated',
                        value: MaterialLocalizations.of(
                          context,
                        ).formatCompactDate(announcement.updatedAt),
                      ),
                    ],
                  ],
                ),
              ),
              if (announcement.actionRequired && !isRead) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warningBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This announcement requires your acknowledgment to confirm you have read and understood it.',
                      ),
                      const SizedBox(height: 12),
                      KaamButton(
                        fullWidth: true,
                        onPressed: () async {
                          await ref
                              .read(announcementsControllerProvider.notifier)
                              .markAsRead(announcement.id);
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline),
                            SizedBox(width: 8),
                            Text('Acknowledge'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isRead) ...[
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: AppColors.success),
                    SizedBox(width: 8),
                    Text(
                      'You have acknowledged this announcement',
                      style: TextStyle(color: AppColors.success),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, Announcement announcement) {
    showDialog(
      context: context,
      builder: (context) => _EditAnnouncementDialog(announcement: announcement),
    );
  }

  void _openAttachment(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({required this.attachment, required this.onTap});

  final AnnouncementAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getFileIcon(attachment.fileType),
                  size: 20,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      attachment.fileType.toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.open_in_new,
                size: 18,
                color: AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    final lower = fileType.toLowerCase();
    if (lower == 'pdf') return Icons.picture_as_pdf;
    if (lower == 'doc' || lower == 'docx') return Icons.description;
    if (lower == 'xls' || lower == 'xlsx') return Icons.table_chart;
    if (lower == 'jpg' || lower == 'jpeg' || lower == 'png') {
      return Icons.image;
    }
    return Icons.insert_drive_file;
  }
}

class _CreateAnnouncementDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateAnnouncementDialog> createState() =>
      _CreateAnnouncementDialogState();
}

class _CreateAnnouncementDialogState
    extends ConsumerState<_CreateAnnouncementDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  AnnouncementType _type = AnnouncementType.normal;
  bool _actionRequired = false;
  List<File> _attachments = [];
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Announcement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter announcement title',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter detailed description',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AnnouncementType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: AnnouncementType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Action Required'),
              subtitle: const Text('Users must acknowledge this announcement'),
              value: _actionRequired,
              onChanged: (value) {
                setState(() => _actionRequired = value ?? false);
              },
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.attach_file),
              label: Text(
                _attachments.isEmpty
                    ? 'Attach Files'
                    : '${_attachments.length} file(s) attached',
              ),
            ),
            if (_isUploading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _uploadProgress),
              const SizedBox(height: 8),
              Text(
                'Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isUploading ? null : _create,
          child: const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _pickFiles() async {
    final result = await file_picker.FilePicker.platform.pickFiles(
      type: file_picker.FileType.custom,
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
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _attachments = result.paths.map((path) => File(path!)).toList();
      });
    }
  }

  Future<void> _create() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Description is required')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      await ref
          .read(announcementsControllerProvider.notifier)
          .createAnnouncement(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            type: _type,
            actionRequired: _actionRequired,
            attachmentFiles: _attachments.isNotEmpty ? _attachments : null,
            onUploadProgress: (progress) {
              setState(() => _uploadProgress = progress);
            },
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement created successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create announcement: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}

class _EditAnnouncementDialog extends ConsumerStatefulWidget {
  const _EditAnnouncementDialog({required this.announcement});

  final Announcement announcement;

  @override
  ConsumerState<_EditAnnouncementDialog> createState() =>
      _EditAnnouncementDialogState();
}

class _EditAnnouncementDialogState
    extends ConsumerState<_EditAnnouncementDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late AnnouncementType _type;
  late bool _actionRequired;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.announcement.title);
    _descriptionController = TextEditingController(
      text: widget.announcement.description,
    );
    _type = widget.announcement.type;
    _actionRequired = widget.announcement.actionRequired;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Announcement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AnnouncementType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: AnnouncementType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Action Required'),
              value: _actionRequired,
              onChanged: (value) {
                setState(() => _actionRequired = value ?? false);
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      await ref
          .read(announcementsControllerProvider.notifier)
          .editAnnouncement(
            announcementId: widget.announcement.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            type: _type,
            actionRequired: _actionRequired,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update announcement: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
        ),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

IconData _typeIcon(AnnouncementType type) {
  return switch (type) {
    AnnouncementType.urgent => Icons.error_outline,
    AnnouncementType.important => Icons.notifications_none,
    AnnouncementType.normal => Icons.notifications_none,
  };
}

Color _typeBg(AnnouncementType type) {
  return switch (type) {
    AnnouncementType.urgent => AppColors.dangerBackground,
    AnnouncementType.important => AppColors.warningBackground,
    AnnouncementType.normal => const Color(0x1A3B82F6),
  };
}

Color _typeBorder(AnnouncementType type) {
  return switch (type) {
    AnnouncementType.urgent => AppColors.danger.withValues(alpha: 0.35),
    AnnouncementType.important => AppColors.warning.withValues(alpha: 0.35),
    AnnouncementType.normal => const Color(0x333B82F6),
  };
}

Color _typeFg(AnnouncementType type) {
  return switch (type) {
    AnnouncementType.urgent => AppColors.danger,
    AnnouncementType.important => AppColors.warning,
    AnnouncementType.normal => const Color(0xFF2563EB),
  };
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
