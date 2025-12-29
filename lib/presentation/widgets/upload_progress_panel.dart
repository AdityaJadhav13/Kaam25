import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/file_utils.dart';
import '../../core/widgets/kaam_button.dart';
import '../../data/models/enums.dart';
import '../../data/models/upload_progress.dart';

class UploadProgressPanel extends StatelessWidget {
  const UploadProgressPanel({
    required this.uploads,
    required this.onCancel,
    required this.onDismiss,
    super.key,
  });

  final List<UploadProgress> uploads;
  final void Function(String fileId) onCancel;
  final void Function(String fileId) onDismiss;

  @override
  Widget build(BuildContext context) {
    if (uploads.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomRight,
      child: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340, maxHeight: 380),
          child: Material(
            color: AppColors.background,
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Text('File Uploads', style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: uploads.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final upload = uploads[index];
                        final type = FileUtils.fileTypeFromName(upload.fileName);
                        final icon = type == null ? '📎' : FileUtils.iconEmoji(type);

                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(icon, style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          upload.fileName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.labelLarge,
                                        ),
                                        const SizedBox(height: 4),
                                        _StatusLine(upload: upload),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  KaamButton(
                                    onPressed: () => onDismiss(upload.fileId),
                                    variant: KaamButtonVariant.ghost,
                                    size: KaamButtonSize.icon,
                                    child: const Icon(Icons.close, size: 18),
                                  ),
                                ],
                              ),
                              if (upload.status == UploadStatus.uploading) ...[
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: upload.progress / 100.0,
                                    minHeight: 6,
                                    backgroundColor: AppColors.muted,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: KaamButton(
                                    onPressed: () => onCancel(upload.fileId),
                                    variant: KaamButtonVariant.outline,
                                    child: const Text('Cancel'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.upload});

  final UploadProgress upload;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;

    switch (upload.status) {
      case UploadStatus.uploading:
        return Text('Uploading... ${upload.progress}%', style: style);
      case UploadStatus.completed:
        return Text('Upload complete', style: style?.copyWith(color: AppColors.success));
      case UploadStatus.failed:
        return Text(upload.error ?? 'Upload failed', style: style?.copyWith(color: AppColors.danger));
      case UploadStatus.pending:
        return Text('Waiting to upload...', style: style);
    }
  }
}
