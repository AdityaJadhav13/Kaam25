import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/kaam_badge.dart';
import '../../core/widgets/kaam_button.dart';
import '../../core/widgets/kaam_text_field.dart';
import '../../data/models/document.dart';
import '../../data/models/folder.dart';
import '../../features/home/documents_repository.dart';
import '../../features/home/home_providers.dart';
import 'document_viewer_page.dart';

// ─────────────────────────────────────────────────────────────
// HOME PAGE — Google-Drive–like folder & file browser
// ─────────────────────────────────────────────────────────────

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// Navigation stack: null = root, otherwise folderId
  final List<String?> _navStack = [null];
  final _searchController = TextEditingController();

  String? get _currentFolderId => _navStack.last;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateInto(String folderId) {
    setState(() {
      _navStack.add(folderId);
      _searchController.clear();
    });
  }

  void _navigateBack() {
    if (_navStack.length > 1) {
      setState(() {
        _navStack.removeLast();
        _searchController.clear();
      });
    }
  }

  void _navigateTo(int stackIndex) {
    if (stackIndex < _navStack.length) {
      setState(() {
        _navStack.removeRange(stackIndex + 1, _navStack.length);
        _searchController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── HEADER ──
        _buildHeader(context),
        const Divider(height: 1),
        // ── CONTENT ──
        Expanded(child: _buildContent(context)),
        // ── BOTTOM ACTIONS ──
        const Divider(height: 1),
        _buildBottomActions(context),
      ],
    );
  }

  // ────────────── HEADER with breadcrumbs ──────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              if (_navStack.length > 1) ...[
                KaamButton(
                  onPressed: _navigateBack,
                  variant: KaamButtonVariant.ghost,
                  size: KaamButtonSize.icon,
                  child: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: _currentFolderId == null
                    ? Text(
                        'Files & Folders',
                        style: Theme.of(context).textTheme.titleLarge,
                      )
                    : _BreadcrumbBar(
                        folderId: _currentFolderId!,
                        onNavigate: _navigateTo,
                        navStack: _navStack,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search
          KaamTextField(
            controller: _searchController,
            hintText: _currentFolderId == null
                ? 'Search folders...'
                : 'Search files & folders...',
            leadingIcon: Icons.search,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  // ────────────── CONTENT ──────────────

  Widget _buildContent(BuildContext context) {
    final folderId = _currentFolderId;
    final query = _searchController.text.trim().toLowerCase();

    if (folderId == null) {
      // ROOT VIEW — show only root folders
      return _RootFolderList(searchQuery: query, onOpenFolder: _navigateInto);
    }

    // INSIDE A FOLDER — show sub-folders + files
    return _FolderContentView(
      folderId: folderId,
      searchQuery: query,
      onOpenFolder: _navigateInto,
    );
  }

  // ────────────── BOTTOM ACTIONS ──────────────

  Widget _buildBottomActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: KaamButton(
              fullWidth: true,
              size: KaamButtonSize.lg,
              onPressed: () =>
                  _showCreateFolderDialog(context, ref, _currentFolderId),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.create_new_folder_outlined),
                  SizedBox(width: 8),
                  Text('New Folder'),
                ],
              ),
            ),
          ),
          if (_currentFolderId != null) ...[
            const SizedBox(width: 12),
            Expanded(
              child: KaamButton(
                fullWidth: true,
                size: KaamButtonSize.lg,
                variant: KaamButtonVariant.outline,
                onPressed: () =>
                    _uploadDocument(context, ref, _currentFolderId!),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_file),
                    SizedBox(width: 8),
                    Text('Upload'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ────────────── DIALOGS ──────────────

  void _showCreateFolderDialog(
    BuildContext context,
    WidgetRef ref,
    String? parentId,
  ) {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => _CreateFolderDialog(
        parentId: parentId,
        nameController: nameController,
        formKey: formKey,
        ref: ref,
      ),
    );
  }

  Future<void> _uploadDocument(
    BuildContext context,
    WidgetRef ref,
    String folderId,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: DocumentsRepository.supportedExtensions,
      );
      if (result == null || result.files.isEmpty) return;

      final platformFile = result.files.first;
      final filePath = platformFile.path;
      if (filePath == null) throw Exception('File path is null');

      final file = File(filePath);
      final fileName = platformFile.name;

      if (!DocumentsRepository.isFileTypeSupported(fileName)) {
        throw Exception(
          'Unsupported file type. Supported: '
          '${DocumentsRepository.supportedExtensions.join(", ")}',
        );
      }

      if (!context.mounted) return;

      // Show upload progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _UploadProgressDialog(
          ref: ref,
          folderId: folderId,
          file: file,
          fileName: fileName,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Upload failed: $e')));
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// BREADCRUMB BAR
// ═══════════════════════════════════════════════════════════════

class _BreadcrumbBar extends ConsumerWidget {
  const _BreadcrumbBar({
    required this.folderId,
    required this.onNavigate,
    required this.navStack,
  });

  final String folderId;
  final void Function(int stackIndex) onNavigate;
  final List<String?> navStack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trailAsync = ref.watch(breadcrumbTrailProvider(folderId));

    return trailAsync.when(
      data: (trail) {
        if (trail.isEmpty) {
          return Text(
            'Files & Folders',
            style: Theme.of(context).textTheme.titleLarge,
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Root tap
              GestureDetector(
                onTap: () => onNavigate(0),
                child: Text(
                  'Home',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.mutedForeground,
                  ),
                ),
              ),
              for (int i = 0; i < trail.length; i++) ...[
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: context.colors.mutedForeground,
                ),
                GestureDetector(
                  onTap: i < trail.length - 1
                      ? () {
                          // Find the stack index for this folder
                          final idx = navStack.indexOf(trail[i].id);
                          if (idx >= 0) onNavigate(idx);
                        }
                      : null,
                  child: Text(
                    trail[i].name,
                    style: i == trail.length - 1
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.colors.mutedForeground,
                          ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => Text(
        'Files & Folders',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ROOT FOLDER LIST
// ═══════════════════════════════════════════════════════════════

class _RootFolderList extends ConsumerWidget {
  const _RootFolderList({
    required this.searchQuery,
    required this.onOpenFolder,
  });

  final String searchQuery;
  final void Function(String folderId) onOpenFolder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(rootFoldersStreamProvider);

    return foldersAsync.when(
      data: (allFolders) {
        final folders = allFolders.where((f) {
          if (searchQuery.isEmpty) return true;
          return f.name.toLowerCase().contains(searchQuery);
        }).toList();

        if (folders.isEmpty) {
          return _EmptyState(
            icon: Icons.folder_outlined,
            title: searchQuery.isEmpty ? 'No folders yet' : 'No folders found',
            subtitle: searchQuery.isEmpty
                ? 'Create your first folder below'
                : 'Try a different search',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: folders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            return _FolderCard(
              folder: folders[index],
              onTap: () => onOpenFolder(folders[index].id),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(message: error.toString()),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FOLDER CONTENT VIEW — sub-folders + files
// ═══════════════════════════════════════════════════════════════

class _FolderContentView extends ConsumerWidget {
  const _FolderContentView({
    required this.folderId,
    required this.searchQuery,
    required this.onOpenFolder,
  });

  final String folderId;
  final String searchQuery;
  final void Function(String folderId) onOpenFolder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subFoldersAsync = ref.watch(subFoldersStreamProvider(folderId));
    final documentsAsync = ref.watch(documentsStreamProvider(folderId));

    return subFoldersAsync.when(
      data: (allSubFolders) {
        return documentsAsync.when(
          data: (allDocuments) {
            final subFolders = allSubFolders.where((f) {
              if (searchQuery.isEmpty) return true;
              return f.name.toLowerCase().contains(searchQuery);
            }).toList();

            final documents = allDocuments.where((d) {
              if (searchQuery.isEmpty) return true;
              return d.fileName.toLowerCase().contains(searchQuery);
            }).toList();

            if (subFolders.isEmpty && documents.isEmpty) {
              return _EmptyState(
                icon: Icons.folder_open_outlined,
                title: searchQuery.isEmpty
                    ? 'This folder is empty'
                    : 'Nothing found',
                subtitle: searchQuery.isEmpty
                    ? 'Create a sub-folder or upload files'
                    : 'Try a different search',
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Sub-folders section ──
                if (subFolders.isNotEmpty) ...[
                  _SectionHeader(title: 'Folders', count: subFolders.length),
                  const SizedBox(height: 8),
                  ...subFolders.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FolderCard(
                        folder: f,
                        onTap: () => onOpenFolder(f.id),
                      ),
                    ),
                  ),
                  if (documents.isNotEmpty) const SizedBox(height: 16),
                ],
                // ── Files section ──
                if (documents.isNotEmpty) ...[
                  _SectionHeader(title: 'Files', count: documents.length),
                  const SizedBox(height: 8),
                  ...documents.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DocumentCard(document: d),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(message: error.toString()),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(message: error.toString()),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FOLDER CARD
// ═══════════════════════════════════════════════════════════════

class _FolderCard extends ConsumerWidget {
  const _FolderCard({required this.folder, required this.onTap});

  final Folder folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docCountAsync = ref.watch(folderDocumentCountProvider(folder.id));
    final subFolderCountAsync = ref.watch(
      folderSubFolderCountProvider(folder.id),
    );

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
                    Row(
                      children: [
                        subFolderCountAsync.when(
                          data: (count) => count > 0
                              ? Text(
                                  '$count ${count == 1 ? 'folder' : 'folders'}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: context.colors.mutedForeground,
                                      ),
                                )
                              : const SizedBox.shrink(),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        subFolderCountAsync.when(
                          data: (sc) => docCountAsync.when(
                            data: (dc) => sc > 0 && dc > 0
                                ? Text(
                                    ' · ',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: context.colors.mutedForeground,
                                        ),
                                  )
                                : const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        docCountAsync.when(
                          data: (count) => Text(
                            '$count ${count == 1 ? 'file' : 'files'}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: context.colors.mutedForeground,
                                ),
                          ),
                          loading: () => const Text('...'),
                          error: (_, __) => const Text('0 files'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: context.colors.mutedForeground),
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
              subtitle: const Text(
                'Only if empty (no files or sub-folders)',
                style: TextStyle(fontSize: 12),
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
    final messenger = ScaffoldMessenger.of(context);

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
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('✅ Folder renamed')),
                );
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                messenger.showSnackBar(SnackBar(content: Text('❌ Error: $e')));
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
    final messenger = ScaffoldMessenger.of(context);

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
                      border: Border.all(color: context.colors.border),
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
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('✅ Icon updated')),
                );
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                messenger.showSnackBar(SnackBar(content: Text('❌ Error: $e')));
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
    // Capture ScaffoldMessenger before async gap — the _FolderCard context
    // may become unmounted after deletion (Firestore stream removes the card).
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text(
          'Delete "${folder.name}"?\n\n'
          'This is only allowed if the folder is empty '
          '(no files and no sub-folders).',
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
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('✅ Folder deleted')),
                );
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                messenger.showSnackBar(SnackBar(content: Text('❌ $e')));
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

// ═══════════════════════════════════════════════════════════════
// DOCUMENT CARD
// ═══════════════════════════════════════════════════════════════

class _DocumentCard extends ConsumerWidget {
  const _DocumentCard({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        onTap: () => _openDocument(context, ref, document),
        onLongPress: () => _showDocumentOptions(context, ref, document),
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
                      '${document.fileSizeFormatted} · '
                      '${document.fileType.toUpperCase()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, yyyy').format(document.uploadedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: context.colors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }

  void _openDocument(BuildContext context, WidgetRef ref, Document document) {
    if (document.downloadUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document URL not available')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentViewerPage(
          documentUrl: document.downloadUrl!,
          documentName: document.fileName,
          fileType: document.fileType,
        ),
      ),
    );
  }

  /// All approved users can rename and view. No share/export options.
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
              leading: const Icon(Icons.edit),
              title: const Text('Rename File'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showRenameDocumentDialog(context, ref, document);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Open File'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openDocument(context, ref, document);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete File',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDeleteDocument(context, ref, document);
              },
            ),
            // ❌ No "Share" / "Export" / "Copy Link" option
          ],
        ),
      ),
    );
  }

  void _showRenameDocumentDialog(
    BuildContext context,
    WidgetRef ref,
    Document document,
  ) {
    final nameController = TextEditingController(text: document.fileName);
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename File'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'File Name'),
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a file name';
              }
              if (value.length > 200) {
                return 'Name too long (max 200 characters)';
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
                    .read(documentControllerProvider.notifier)
                    .renameDocument(document.id, nameController.text.trim());
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('✅ File renamed')),
                );
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                messenger.showSnackBar(SnackBar(content: Text('❌ Error: $e')));
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDocument(
    BuildContext context,
    WidgetRef ref,
    Document document,
  ) {
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text(
          'Are you sure you want to delete "${document.fileName}"? '
          'This action cannot be undone.',
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
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('✅ File deleted')),
                );
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                messenger.showSnackBar(SnackBar(content: Text('❌ Error: $e')));
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

// ═══════════════════════════════════════════════════════════════
// UPLOAD PROGRESS DIALOG
// ═══════════════════════════════════════════════════════════════

class _UploadProgressDialog extends ConsumerStatefulWidget {
  const _UploadProgressDialog({
    required this.ref,
    required this.folderId,
    required this.file,
    required this.fileName,
  });

  final WidgetRef ref;
  final String folderId;
  final File file;
  final String fileName;

  @override
  ConsumerState<_UploadProgressDialog> createState() =>
      _UploadProgressDialogState();
}

class _UploadProgressDialogState extends ConsumerState<_UploadProgressDialog> {
  double _progress = 0.0;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startUpload();
  }

  Future<void> _startUpload() async {
    try {
      await ref
          .read(documentControllerProvider.notifier)
          .uploadDocument(
            folderId: widget.folderId,
            file: widget.file,
            fileName: widget.fileName,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      if (mounted) {
        setState(() => _done = true);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ File uploaded successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _error != null
            ? 'Upload Failed'
            : _done
            ? 'Upload Complete'
            : 'Uploading...',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else ...[
            LinearProgressIndicator(value: _done ? 1.0 : _progress),
            const SizedBox(height: 16),
            Text(_done ? '100%' : '${(_progress * 100).toInt()}%'),
          ],
        ],
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: context.colors.mutedForeground,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.colors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: context.colors.mutedForeground.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CREATE FOLDER DIALOG WITH LOADING ANIMATION
// ═══════════════════════════════════════════════════════════════

class _CreateFolderDialog extends StatefulWidget {
  const _CreateFolderDialog({
    required this.parentId,
    required this.nameController,
    required this.formKey,
    required this.ref,
  });

  final String? parentId;
  final TextEditingController nameController;
  final GlobalKey<FormState> formKey;
  final WidgetRef ref;

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  bool _isCreating = false;

  Future<void> _handleCreate() async {
    if (!widget.formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      await widget.ref
          .read(folderControllerProvider.notifier)
          .createFolder(
            name: widget.nameController.text.trim(),
            parentId: widget.parentId,
            icon: '📁',
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Folder created'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.parentId == null ? 'Create Folder' : 'Create Sub-Folder',
      ),
      content: Form(
        key: widget.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: widget.nameController,
              enabled: !_isCreating,
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
            if (_isCreating) ...[
              const SizedBox(height: 20),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Creating folder...'),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isCreating ? null : _handleCreate,
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
