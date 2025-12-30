import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/kaam_badge.dart';
import '../../core/widgets/kaam_button.dart';
import '../../core/widgets/kaam_text_field.dart';
import '../../data/models/document.dart';
import '../../data/models/folder.dart';
import '../../features/home/documents_repository.dart';
import '../../features/home/home_providers.dart';
import '../controllers/auth_controller.dart';
import 'document_viewer_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Folder? _selectedFolder;
  final _folderSearch = TextEditingController();
  final _documentSearch = TextEditingController();

  @override
  void dispose() {
    _folderSearch.dispose();
    _documentSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedFolder == null) {
      return _FolderListView(
        folderSearch: _folderSearch,
        onSelectFolder: (f) => setState(() => _selectedFolder = f),
      );
    }

    return _FolderDetailView(
      folder: _selectedFolder!,
      documentSearch: _documentSearch,
      onBack: () => setState(() {
        _selectedFolder = null;
        _documentSearch.clear();
      }),
    );
  }
}

class _FolderListView extends ConsumerWidget {
  const _FolderListView({
    required this.folderSearch,
    required this.onSelectFolder,
  });

  final TextEditingController folderSearch;
  final void Function(Folder folder) onSelectFolder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersStreamProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notes & Documents',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              KaamTextField(
                controller: folderSearch,
                hintText: 'Search folders...',
                leadingIcon: Icons.search,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: foldersAsync.when(
            data: (allFolders) {
              // Filter folders based on search
              final folders = allFolders.where((f) {
                final query = folderSearch.text.trim().toLowerCase();
                if (query.isEmpty) return true;
                return f.name.toLowerCase().contains(query);
              }).toList();

              if (folders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 64,
                        color: AppColors.mutedForeground.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        folderSearch.text.trim().isEmpty
                            ? 'No folders yet'
                            : 'No folders found',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.mutedForeground),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        folderSearch.text.trim().isEmpty
                            ? 'Create your first folder below'
                            : 'Try a different search',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: folders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  return _FolderCard(
                    folder: folder,
                    onTap: () => onSelectFolder(folder),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading folders',
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
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: KaamButton(
            fullWidth: true,
            size: KaamButtonSize.lg,
            onPressed: () => _showCreateFolderDialog(context, ref),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add),
                SizedBox(width: 8),
                Text('Create Folder'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCreateFolderDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Folder'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Folder Name',
                  hintText: 'Enter folder name',
                ),
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a folder name';
                  }
                  if (value.length > 100) {
                    return 'Name too long (max 100 characters)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                await ref
                    .read(folderControllerProvider.notifier)
                    .createFolder(name: nameController.text.trim(), icon: '📁');

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Folder created')),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _FolderCard extends ConsumerWidget {
  const _FolderCard({required this.folder, required this.onTap});

  final Folder folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentCountAsync = ref.watch(
      folderDocumentCountProvider(folder.id),
    );

    // Check if folder was updated in last 24 hours
    final isNew = DateTime.now().difference(folder.updatedAt).inHours < 24;

    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showFolderOptions(context, ref, folder),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(folder.icon ?? '📁', style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (isNew) ...[
                          const SizedBox(width: 8),
                          const KaamBadge(
                            label: 'New',
                            variant: KaamBadgeVariant.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    documentCountAsync.when(
                      data: (count) => Text(
                        '$count ${count == 1 ? 'document' : 'documents'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      loading: () => const Text('...'),
                      error: (_, __) => const Text('0 documents'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }

  void _showFolderOptions(BuildContext context, WidgetRef ref, Folder folder) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename Folder'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showRenameFolderDialog(context, ref, folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions),
              title: const Text('Change Icon'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showChangeIconDialog(context, ref, folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Folder',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDeleteFolder(context, ref, folder);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameFolderDialog(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
  ) {
    final nameController = TextEditingController(text: folder.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Folder'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Folder Name'),
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a folder name';
              }
              if (value.length > 100) {
                return 'Name too long (max 100 characters)';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                await ref
                    .read(folderControllerProvider.notifier)
                    .renameFolder(folder.id, nameController.text.trim());

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Folder renamed')),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showChangeIconDialog(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
  ) {
    final icons = ['📁', '📂', '📄', '📝', '📊', '📈', '🎯', '💼', '🏠', '⚡'];
    final iconController = TextEditingController(text: folder.icon);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Icon'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: icons.map((icon) {
                return InkWell(
                  onTap: () => iconController.text = icon,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(icon, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: iconController,
              decoration: const InputDecoration(
                labelText: 'Or enter custom emoji',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(folderControllerProvider.notifier)
                    .updateFolderIcon(folder.id, iconController.text.trim());

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Icon updated')),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFolder(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text(
          'Are you sure you want to delete "${folder.name}"? This will also delete all documents inside.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(folderControllerProvider.notifier)
                    .deleteFolder(folder.id);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Folder deleted')),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _FolderDetailView extends ConsumerWidget {
  const _FolderDetailView({
    required this.folder,
    required this.documentSearch,
    required this.onBack,
  });

  final Folder folder;
  final TextEditingController documentSearch;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentsStreamProvider(folder.id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  KaamButton(
                    onPressed: onBack,
                    variant: KaamButtonVariant.ghost,
                    size: KaamButtonSize.icon,
                    child: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    folder.icon ?? '📁',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              KaamTextField(
                controller: documentSearch,
                hintText: 'Search documents...',
                leadingIcon: Icons.search,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: documentsAsync.when(
            data: (allDocuments) {
              // Filter documents based on search
              final documents = allDocuments.where((d) {
                final query = documentSearch.text.trim().toLowerCase();
                if (query.isEmpty) return true;
                return d.fileName.toLowerCase().contains(query);
              }).toList();

              if (documents.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.insert_drive_file_outlined,
                        size: 64,
                        color: AppColors.mutedForeground.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        documentSearch.text.trim().isEmpty
                            ? 'No documents yet'
                            : 'No documents found',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.mutedForeground),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        documentSearch.text.trim().isEmpty
                            ? 'Upload your first document below'
                            : 'Try a different search',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: documents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final document = documents[index];
                  return _DocumentCard(document: document);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading documents',
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
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: KaamButton(
            fullWidth: true,
            size: KaamButtonSize.lg,
            onPressed: () => _uploadDocument(context, ref, folder),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file),
                SizedBox(width: 8),
                Text('Upload Document'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _uploadDocument(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
  ) async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: DocumentsRepository.supportedExtensions,
      );

      if (result == null || result.files.isEmpty) return;

      final platformFile = result.files.first;
      final filePath = platformFile.path;

      if (filePath == null) {
        throw Exception('File path is null');
      }

      final file = File(filePath);
      final fileName = platformFile.name;

      // Validate file type
      if (!DocumentsRepository.isFileTypeSupported(fileName)) {
        throw Exception(
          'Unsupported file type. Supported: ${DocumentsRepository.supportedExtensions.join(", ")}',
        );
      }

      // Show uploading dialog
      if (!context.mounted) return;

      double uploadProgress = 0.0;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Uploading...'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: uploadProgress),
                const SizedBox(height: 16),
                Text('${(uploadProgress * 100).toInt()}%'),
              ],
            ),
          ),
        ),
      );

      // Upload document
      await ref
          .read(documentControllerProvider.notifier)
          .uploadDocument(
            folderId: folder.id,
            file: file,
            fileName: fileName,
            onProgress: (progress) {
              uploadProgress = progress;
            },
          );

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close progress dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Document uploaded successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;

      // Try to close progress dialog if open
      try {
        Navigator.of(context).pop();
      } catch (_) {}

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Upload failed: $e')));
    }
  }
}

class _DocumentCard extends ConsumerWidget {
  const _DocumentCard({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final isOwner = auth.user?.id == document.uploadedBy;

    return Card(
      child: InkWell(
        onTap: () => _openDocument(context, ref, document),
        onLongPress: isOwner
            ? () => _showDocumentOptions(context, ref, document)
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DocumentsRepository.getFileIcon(document.fileName),
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.fileName,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${document.fileSizeFormatted} • ${document.fileType.toUpperCase()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, yyyy').format(document.uploadedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }

  void _openDocument(BuildContext context, WidgetRef ref, Document document) {
    // Open document in in-app viewer
    if (document.downloadUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document URL not available')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DocumentViewerPage(
          documentUrl: document.downloadUrl!,
          documentName: document.fileName,
          fileType: document.fileType,
        ),
      ),
    );
  }

  void _showDocumentOptions(
    BuildContext context,
    WidgetRef ref,
    Document document,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Document',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDeleteDocument(context, ref, document);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteDocument(
    BuildContext context,
    WidgetRef ref,
    Document document,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text(
          'Are you sure you want to delete "${document.fileName}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(documentControllerProvider.notifier)
                    .deleteDocument(document.id);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Document deleted')),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
